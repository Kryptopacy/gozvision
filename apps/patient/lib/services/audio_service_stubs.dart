// ignore_for_file: avoid_classes_with_only_static_members
import 'dart:async';

// Dummy classes to keep Dart compiler happy for web platform 
// where `record` and `just_audio` native packages are entirely pruned.
class AudioRecorder {
  Future<bool> hasPermission() async => false;
  Future<dynamic> startStream(dynamic config) async => const Stream.empty();
  Future<void> stop() async {}
  void dispose() {}
}

class RecordConfig {
  final dynamic encoder;
  final dynamic numChannels;
  final dynamic sampleRate;
  const RecordConfig({this.encoder, this.numChannels, this.sampleRate});
}

class AudioEncoder {
  static const pcm16bits = 'pcm16bits';
}

class AudioPlayer {
  Future<void> stop() async {}
  Future<void> setAudioSource(dynamic source) async {}
  Future<void> play() async {}
  Stream<dynamic> get playerStateStream => const Stream.empty();
  void dispose() {}
}

class StreamAudioSource {
  const StreamAudioSource();
}

class StreamAudioResponse {
  final int sourceLength;
  final int contentLength;
  final int offset;
  final Stream<List<int>> stream;
  final String contentType;

  StreamAudioResponse({
    required this.sourceLength,
    required this.contentLength,
    required this.offset,
    required this.stream,
    required this.contentType,
  });
}

class ProcessingState {
  static const completed = 'completed';
}
