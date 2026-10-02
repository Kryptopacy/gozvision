// This is the NATIVE stub for the WebAudioBridge.
// Used on iOS/Android — web audio is not needed on native platforms.
import 'dart:typed_data';

/// Stub implementation for native platforms.
/// On native, AudioService uses the `record` package directly.
class WebAudioBridge {
  static Future<bool> startRecording({
    required void Function(Uint8List chunk) onChunk,
  }) async {
    return false; // Not used on native
  }

  static void stopRecording() {
    // Not used on native
  }

  static void playAudioChunk(Uint8List chunk, int sampleRate) {
    // Not used on native
  }

  static void stopPlayback() {
    // Not used on native
  }

  static void playPing() {
    // Not used on native
  }
}
