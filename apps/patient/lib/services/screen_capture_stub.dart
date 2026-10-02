// This is the NATIVE stub for the WebScreenCaptureBridge.
// Used on iOS/Android — the PWA Screen Capture API is web-only.
import 'dart:typed_data';

/// Stub implementation for native platforms.
/// On native, ScreenCaptureService uses Android MediaProjection or iOS ReplayKit.
class WebScreenCaptureBridge {
  static Future<bool> startScreenCapture({
    required void Function(Uint8List chunk) onFrame,
  }) async {
    return false; // Not implemented for native in this stub
  }

  static void stopScreenCapture() {
    // Not used on native
  }
}
