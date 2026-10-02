// Web-only screen capture bridge using navigator.mediaDevices.getDisplayMedia
// Imported by screen_capture_service.dart on web via conditional import.
// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:async';
import 'dart:js_interop';

import 'package:flutter/foundation.dart'; // For debugPrint
import 'package:web/web.dart' as web;

/// Bridges the browser Screen Capture API to Dart for the UI Navigator.
class WebScreenCaptureBridge {
  static web.MediaStream? _mediaStream;
  static web.HTMLVideoElement? _videoElement;
  static web.HTMLCanvasElement? _canvasElement;
  static web.CanvasRenderingContext2D? _canvasContext;
  
  static Timer? _captureTimer;
  static void Function(Uint8List)? _onFrame;
  static final double _fps = 1.0; // 1 FPS is sufficient for UI navigation analysis

  /// Request screen share permission and start capturing frames.
  static Future<bool> startScreenCapture({
    required void Function(Uint8List chunk) onFrame,
  }) async {
    try {
      _onFrame = onFrame;

      // 1. Request screen share from the user
      _mediaStream = await web.window.navigator.mediaDevices
          .getDisplayMedia(web.DisplayMediaStreamOptions(
            video: true.jsify() as JSAny,
            audio: false.jsify() as JSAny,
          ))
          .toDart;

      // 2. Create a hidden video element to play the stream
      _videoElement = web.HTMLVideoElement()
        ..autoplay = true
        ..muted = true
        ..srcObject = _mediaStream;

      // Wait for video to be ready to get dimensions
      await _videoElement!.onLoadedMetadata.first;
      _videoElement!.play();

      // 3. Create a canvas element to extract frames
      _canvasElement = web.HTMLCanvasElement()
        ..width = _videoElement!.videoWidth
        ..height = _videoElement!.videoHeight;
        
      _canvasContext = _canvasElement!.getContext('2d') as web.CanvasRenderingContext2D;

      // 4. Start the capture loop
      _startCaptureLoop();

      debugPrint('WebScreenCaptureBridge: Screen capture started at ${_videoElement!.videoWidth}x${_videoElement!.videoHeight}');
      
      // Listen for the user clicking "Stop Sharing" on the browser UI
      final tracks = _mediaStream!.getTracks().toDart;
      if (tracks.isNotEmpty) {
        final track = tracks.first;
        track.addEventListener('ended', (web.Event _) {
          debugPrint('WebScreenCaptureBridge: User stopped sharing via browser UI.');
          stopScreenCapture();
        }.toJS);
      }

      return true;
    } catch (e) {
      debugPrint('WebScreenCaptureBridge permission or setup error: $e');
      return false;
    }
  }

  static void _startCaptureLoop() {
    _captureTimer?.cancel();
    final interval = Duration(milliseconds: (1000 / _fps).round());
    
    _captureTimer = Timer.periodic(interval, (_) {
      _captureFrame();
    });
  }

  static Future<void> _captureFrame() async {
    if (_videoElement == null || _canvasContext == null || _onFrame == null) return;

    try {
      // Draw the current video frame to the canvas
      _canvasContext!.drawImage(
        _videoElement!, 
        0, 0, 
        _videoElement!.videoWidth.toDouble(), 
        _videoElement!.videoHeight.toDouble()
      );

      // Extract the frame as a Base64 JPEG data URL
      // We use 0.7 quality to keep payload small for the WebSocket
      final dataUrl = _canvasElement!.toDataURL('image/jpeg', 0.7.jsify() as JSAny);
      
      // Decode Base64 to bytes
      // Note: we're using a simple approach here, in a real app you'd use base64Decode
      // But for JS interop, sometimes getting raw bytes is tricky.
      // Easiest is to send the base64 string directly if Gemini accepts it,
      // or decode it in Dart.
      
      // Convert JS string to Dart Uri to parse base64
      final bytes = UriData.parse(dataUrl).contentAsBytes();
      
      _onFrame!(bytes);
    } catch (e) {
      debugPrint('WebScreenCaptureBridge: Frame extract error: $e');
    }
  }

  /// Stop capturing and clean up video/canvas elements.
  static void stopScreenCapture() {
    _captureTimer?.cancel();
    _captureTimer = null;
    
    if (_mediaStream != null) {
      final tracks = _mediaStream!.getTracks().toDart;
      for (final track in tracks.whereType<web.MediaStreamTrack>()) {
        track.stop();
      }
    }
    
    _videoElement?.pause();
    _videoElement?.srcObject = null;
    
    _videoElement = null;
    _canvasElement = null;
    _canvasContext = null;
    _mediaStream = null;
    _onFrame = null;
    
    debugPrint('WebScreenCaptureBridge: Screen capture stopped.');
  }
}
