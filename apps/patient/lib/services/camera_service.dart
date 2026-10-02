import 'dart:async';

import 'dart:math';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../core/app_config.dart';
import 'package:copilot_core/copilot_core.dart';

/// Service for managing camera capture and frame streaming.
///
/// Captures frames from the rear camera at configurable FPS and converts
/// them to JPEG format for streaming to Gemini Live API.
/// On web, camera initialization may require user permission via browser prompt.
class CameraService extends ChangeNotifier implements CopilotCamera {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  bool _isStreaming = false;
  bool _initFailed = false;
  bool _isCapturing = false;
  Timer? _frameTimer;
  double _fps = AppConfig.cameraFps;

  // Battery Saver / Motion Tracking
  StreamSubscription<AccelerometerEvent>? _accelSub;
  DateTime _lastMotionTime = DateTime.now();
  bool _isBatterySaverActive = false;

  // Stream controller for JPEG frames
  final StreamController<Uint8List> _frameController =
      StreamController<Uint8List>.broadcast();

  // Public getters
  @override
  bool get isInitialized => _controller?.value.isInitialized ?? false;
  @override
  bool get isStreaming => _isStreaming;
  @override
  bool get initFailed => _initFailed;
  CameraController? get controller => _controller;
  @override
  Stream<Uint8List> get frameStream => _frameController.stream;
  CameraLensDirection? get currentLensDirection => _controller?.description.lensDirection;

  /// Initialize the camera (prefer rear camera).
  @override
  Future<void> initialize() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        debugPrint('CameraService: No cameras available');
        _initFailed = true;
        notifyListeners();
        return;
      }

      // On mobile we prefer the rear camera for scene analysis.
      // On web/PC, webcams often report as external, front, or unknown.
      // But for mobile web (PWA), we still want to prefer the back camera.
      CameraDescription camera = _cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => _cameras.first,
      );

      // Web browsers are extremely strict about formats and resolutions.
      // If we request ImageFormatGroup.jpeg or a strict ResolutionPreset,
      // it throws a CameraException(cameraNotReadable) hardware error.
      // We start with max and fallback to handle Chrome's rigidity.
      try {
        _controller = CameraController(
          camera,
          ResolutionPreset.max,
          enableAudio: false,
          imageFormatGroup: kIsWeb ? ImageFormatGroup.unknown : ImageFormatGroup.jpeg,
        );
        await _controller!.initialize();
      } catch (e) {
        debugPrint('CameraService: Falling back to lower preset due to: $e');
        _controller = CameraController(
          camera,
          ResolutionPreset.low,
          enableAudio: false,
          imageFormatGroup: kIsWeb ? ImageFormatGroup.unknown : ImageFormatGroup.jpeg,
        );
        await _controller!.initialize();
      }

      _initFailed = false;
      notifyListeners();
      debugPrint('CameraService: Initialized with ${camera.name}');
    } catch (e) {
      debugPrint('CameraService: Initialization failed completely: $e');
      _initFailed = true;
      _controller = null;
      notifyListeners();
    }
  }

  /// Start continuous frame streaming at configured FPS.
  @override
  void startStreaming() {
    if (!isInitialized || _isStreaming) return;

    _isStreaming = true;
    _startMotionTracker();
    notifyListeners();

    _scheduleNextFrame();

    debugPrint('CameraService: Streaming starting');
  }

  void _scheduleNextFrame() {
    if (!_isStreaming) return;
    
    // Check battery saver state: 0.2 FPS (every 5 seconds) if resting, otherwise 1 FPS
    final targetFps = _isBatterySaverActive ? 0.2 : _fps;
    final interval = Duration(milliseconds: (1000 / targetFps).round());
    
    _frameTimer?.cancel();
    _frameTimer = Timer(interval, () async {
      await _captureFrame();
      _scheduleNextFrame();
    });
  }

  /// Stop continuous frame streaming.
  @override
  void stopStreaming() {
    _frameTimer?.cancel();
    _frameTimer = null;
    _accelSub?.cancel();
    _isStreaming = false;
    notifyListeners();
    debugPrint('CameraService: Streaming stopped');
  }

  /// Capture a single snapshot (for Volume Up trigger or on-demand).
  @override
  Future<Uint8List?> captureSnapshot() async {
    if (!isInitialized) return null;

    try {
      final xFile = await _controller!.takePicture();
      final bytes = await xFile.readAsBytes();
      debugPrint('CameraService: Snapshot captured (${bytes.length} bytes)');
      return bytes;
    } catch (e) {
      debugPrint('CameraService: Snapshot failed: $e');
      return null;
    }
  }

  /// Capture a frame and emit it to the stream.
  Future<void> _captureFrame() async {
    if (!isInitialized || !_isStreaming || _isCapturing) return;

    _isCapturing = true;
    try {
      final xFile = await _controller!.takePicture();
      final bytes = await xFile.readAsBytes();
      _frameController.add(bytes);
    } catch (e) {
      // Frame capture can fail intermittently, don't crash
      debugPrint('CameraService: Frame capture error: $e');
    } finally {
      _isCapturing = false;
    }
  }

  /// Update the streaming FPS.
  void setFps(double fps) {
    _fps = fps;
    if (_isStreaming) {
      _scheduleNextFrame();
    }
  }

  // --- Sensary Integrations for Master Polish ---

  void _startMotionTracker() {
    if (kIsWeb) return; // Sensors unsupported on web usually
    
    _accelSub?.cancel();
    _accelSub = accelerometerEventStream().listen((event) {
      // Calculate magnitude of acceleration vector
      final magnitude = sqrt(event.x * event.x + event.y * event.y + event.z * event.z);
      
      // Calculate delta from exactly 1g (9.8 m/s^2)
      final delta = (magnitude - 9.8).abs();
      
      // If there is significant motion (jitter / walking)
      if (delta > 0.5) {
        _lastMotionTime = DateTime.now();
        if (_isBatterySaverActive) {
          _isBatterySaverActive = false;
          _scheduleNextFrame(); // Instantly ramp back up to 1 FPS
          debugPrint('CameraService: Motion detected -> 1 FPS');
        }
      } else {
        // If still for more than 5 seconds, engage battery saver
        if (!_isBatterySaverActive && DateTime.now().difference(_lastMotionTime).inSeconds >= 5) {
          _isBatterySaverActive = true;
          debugPrint('CameraService: Resting -> 0.2 FPS (Battery Saver On)');
        }
      }
    });
  }

  /// Switch between front and rear cameras.
  @override
  Future<void> switchCamera() async {
    if (_cameras.length < 2) return;

    // Switch to the next available camera in the list
    final currentIndex = _cameras.indexWhere((c) => c.name == _controller?.description.name);
    final nextIndex = (currentIndex + 1) % _cameras.length;
    final newCamera = _cameras[nextIndex];

    final wasStreaming = _isStreaming;
    if (wasStreaming) stopStreaming();

    await _controller?.dispose();
    try {
      _controller = CameraController(
        newCamera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: kIsWeb ? ImageFormatGroup.unknown : ImageFormatGroup.jpeg,
      );
      await _controller!.initialize();
      _initFailed = false;
    } catch (e) {
      debugPrint('CameraService: switchCamera failed: $e');
      _initFailed = true;
      _controller = null;
    }
    notifyListeners();

    if (wasStreaming && !_initFailed) startStreaming();
  }

  /// Toggle the camera LED flashlight on or off.
  @override
  Future<void> toggleFlashlight(bool on) async {
    if (!isInitialized || kIsWeb) return;
    try {
      await _controller!.setFlashMode(on ? FlashMode.torch : FlashMode.off);
      debugPrint('CameraService: Flashlight toggled ${on ? 'ON' : 'OFF'}');
    } catch (e) {
      debugPrint('CameraService: Flashlight toggle failed: $e');
    }
  }

  @override
  void dispose() {
    stopStreaming();
    _controller?.dispose();
    _frameController.close();
    super.dispose();
  }
}
