import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../core/app_config.dart';
import 'package:copilot_core/copilot_core.dart';

// Web-specific imports for getDisplayMedia
import 'screen_capture_web.dart' if (dart.library.io) 'screen_capture_stub.dart'
    as web_screen;

/// Service for natively capturing the screen and streaming it to Gemini.
///
/// On Web (PWA): Uses navigator.mediaDevices.getDisplayMedia to capture the 
/// entire OS screen, enabling true UI Navigator functionality outside the app.
/// On Native: Falls back to capturing the RepaintBoundary of the Flutter app.
class ScreenCaptureService extends ChangeNotifier implements CopilotScreenCapture {
  // The key attached to the root RepaintBoundary in main.dart (fallback)
  final GlobalKey globalKey = GlobalKey();

  bool _isStreaming = false;
  Timer? _frameTimer;
  final double _fps = AppConfig.cameraFps;

  // Stream controller for JPEG UI frames
  final StreamController<Uint8List> _frameController =
      StreamController<Uint8List>.broadcast();

  bool get isStreaming => _isStreaming;
  @override
  Stream<Uint8List> get frameStream => _frameController.stream;

  /// Start capturing the UI at the configured FPS.
  @override
  Future<void> startStreaming() async {
    if (_isStreaming) return;

    // WEB PWA FLOW: Use the native browser Screen Capture API
    if (kIsWeb) {
      final success = await web_screen.WebScreenCaptureBridge.startScreenCapture(
        onFrame: (bytes) {
          _frameController.add(bytes);
        },
      );
      
      if (success) {
        _isStreaming = true;
        notifyListeners();
        debugPrint('ScreenCaptureService: Web OS Screen Streaming started');
      } else {
        debugPrint('ScreenCaptureService: Web Screen Capture failed/denied');
      }
      return;
    }

    // NATIVE FALLBACK: Capture the Flutter RepaintBoundary
    _isStreaming = true;
    notifyListeners();

    final interval = Duration(milliseconds: (1000 / _fps).round());
    _frameTimer = Timer.periodic(interval, (_) => _captureFrame());

    debugPrint('ScreenCaptureService: UI Streaming started at $_fps FPS');
  }

  /// Stop capturing the UI.
  @override
  void stopStreaming() {
    if (kIsWeb) {
      web_screen.WebScreenCaptureBridge.stopScreenCapture();
    }
    
    _frameTimer?.cancel();
    _frameTimer = null;
    _isStreaming = false;
    notifyListeners();
    debugPrint('ScreenCaptureService: UI Streaming stopped');
  }

  /// (Fallback) Captures the RepaintBoundary as a JPEG image.
  Future<void> _captureFrame() async {
    if (globalKey.currentContext == null) return;

    try {
      RenderRepaintBoundary boundary = globalKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 0.8); // Slightly lower pixel ratio for speed
      ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      
      if (byteData != null) {
        _frameController.add(byteData.buffer.asUint8List());
      }
    } catch (e) {
      debugPrint('ScreenCaptureService: Error capturing UI frame: $e');
    }
  }

  @override
  void dispose() {
    stopStreaming();
    _frameController.close();
    super.dispose();
  }
}
