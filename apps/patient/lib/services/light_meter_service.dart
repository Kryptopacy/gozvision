import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:copilot_core/copilot_core.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:image/image.dart' as img;

/// Offline light meter and orientation aid.
///
/// Uses the device's ambient light sensor (via accelerometer proxy)
/// and camera exposure to help low-vision users:
/// 1. Orient toward windows/light sources via rising audio tone
/// 2. Assess room lighting conditions
/// 3. Navigate from bright-to-dark transitions (e.g., entering a building)
///
/// This service works ENTIRELY OFFLINE — no internet required.
class LightMeterService extends ChangeNotifier implements CopilotLightMeter {
  StreamSubscription? _sensorSubscription;
  bool _isActive = false;
  double _currentLux = 0;
  double _currentTilt = 0; // Cached tilt for combined feedback
  LightLevel _lightLevel = LightLevel.unknown;
  Timer? _toneTimer;
  bool _isProcessingFrame = false;
  bool _hasPromptedLowLight = false;

  // Callbacks for audio feedback & proactive AI warnings
  Function(double frequency)? onToneUpdate;
  Function()? onProactiveDarknessWarning;

  @override
  bool get isActive => _isActive;
  @override
  double get currentLux => _currentLux;
  LightLevel get lightLevel => _lightLevel;

  /// Human-readable description of current light level.
  String get lightDescription {
    switch (_lightLevel) {
      case LightLevel.dark:
        return 'Very dark — use caution';
      case LightLevel.dim:
        return 'Dim lighting';
      case LightLevel.moderate:
        return 'Moderate lighting';
      case LightLevel.bright:
        return 'Well lit';
      case LightLevel.veryBright:
        return 'Very bright — likely outdoors';
      case LightLevel.unknown:
        return 'Measuring...';
    }
  }

  /// Start the light meter sensor monitoring.
  @override
  void start() {
    if (_isActive) return;
    _isActive = true;
    _currentTilt = 0;
    notifyListeners();

    // Accelerometer sensor is not available on web
    if (!kIsWeb) {
      _sensorSubscription = accelerometerEventStream().listen((event) {
        // Calculate device tilt angle (used for orientation feedback)
        // atan2 returns radians, we convert to degrees
        _currentTilt = atan2(event.y, event.z) * (180 / pi);
      });
    }

    // Periodically pulse the audio feedback
    _toneTimer = Timer.periodic(
      const Duration(milliseconds: 150),
      (_) => _emitCombinedFeedback(),
    );

    debugPrint('LightMeter: Started');
  }

  /// Stop the light meter.
  @override
  void stop() {
    _sensorSubscription?.cancel();
    _sensorSubscription = null;
    _toneTimer?.cancel();
    _toneTimer = null;
    _isActive = false;
    notifyListeners();
    debugPrint('LightMeter: Stopped');
  }

  /// Update the lux reading (called externally from camera exposure data).
  void updateLux(double lux) {
    _currentLux = lux;
    _lightLevel = _classifyLight(lux);
    notifyListeners();
  }

  /// Estimate lux from camera frame brightness.
  void estimateFromFrameBrightness(double averageBrightness) {
    // Map 0-255 brightness to approximate lux range (0-10,000)
    final estimatedLux = (averageBrightness / 255.0) * 10000;
    updateLux(estimatedLux);
  }

  /// Process raw JPEG bytes to calculate luminance on a background thread.
  @override
  void processFrameBrightness(Uint8List jpegBytes) async {
    // Throttle: process one frame every 5 seconds
    if (_isProcessingFrame || !_isActive) return;
    _isProcessingFrame = true;

    try {
      // Decode image in a background isolate
      final image = await compute(img.decodeJpg, jpegBytes);
      if (image == null) return;

      double totalLuminance = 0;
      int count = 0;

      // Sample every 10th pixel to be blazing fast
      for (int y = 0; y < image.height; y += 10) {
        for (int x = 0; x < image.width; x += 10) {
          final pixel = image.getPixel(x, y);
          final num r = pixel.r;
          final num g = pixel.g;
          final num b = pixel.b;
          final lum = 0.299 * r + 0.587 * g + 0.114 * b;
          totalLuminance += lum;
          count++;
        }
      }

      final avgLum = count > 0 ? (totalLuminance / count) : 0.0;
      estimateFromFrameBrightness(avgLum);

      // Trigger proactive warning if it's incredibly dark and we haven't warned recently
      if (_lightLevel == LightLevel.dark && !_hasPromptedLowLight) {
        _hasPromptedLowLight = true;
        onProactiveDarknessWarning?.call();
        // Reset warning state after 2 minutes
        Future.delayed(const Duration(minutes: 2), () {
          _hasPromptedLowLight = false;
        });
      }
    } catch (e) {
      debugPrint('LightMeter frame processing failed: $e');
    } finally {
      Future.delayed(const Duration(seconds: 5), () {
        _isProcessingFrame = false;
      });
    }
  }

  /// Classify the light level from a lux reading.
  LightLevel _classifyLight(double lux) {
    if (lux < 10) return LightLevel.dark;
    if (lux < 50) return LightLevel.dim;
    if (lux < 500) return LightLevel.moderate;
    if (lux < 5000) return LightLevel.bright;
    return LightLevel.veryBright;
  }

  /// Emits a single, combined tone representing both light level AND orientation.
  /// Base Frequency: Derived from Lux (Brighter = Higher)
  /// Pitch Shift: Derived from Tilt (Level with horizon = Pure tone, Tilted = Offset)
  void _emitCombinedFeedback() {
    if (!_isActive || onToneUpdate == null) return;

    // 1. Base Frequency from Lux (200Hz - 800Hz)
    final normalizedLux = (_currentLux / 10000).clamp(0.0, 1.0);
    double frequency = 200 + (normalizedLux * 600);

    // 2. Add Orientation Shift (+/- 100Hz based on tilt)
    // A low-vision user can find the horizon or ceiling by listening for the pitch peak.
    final normalizedTilt = (_currentTilt.clamp(-90, 90) + 90) / 180; // 0.0 to 1.0
    frequency += (normalizedTilt * 150) - 75; 

    onToneUpdate!.call(frequency.clamp(100, 1200));
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }
}

/// Categorized light levels for accessibility descriptions.
enum LightLevel {
  dark,
  dim,
  moderate,
  bright,
  veryBright,
  unknown,
}
