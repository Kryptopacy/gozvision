// ignore_for_file: experimental_api, deprecated_member_use, deprecated_member_use_from_same_package
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'audio_service_imports.dart' if (dart.library.js_interop) 'audio_service_stubs.dart';

import '../core/app_config.dart';
import 'package:copilot_core/copilot_core.dart';

// Web-specific imports — only used on web platform
import 'audio_service_stub.dart'
    if (dart.library.js_util) 'audio_service_web.dart'
    as web_audio;

/// Service for bidirectional audio: mic capture → Gemini, Gemini → speaker.
///
/// On web: uses a JS-interop MediaRecorder bridge for mic capture.
/// On mobile: uses the `record` package with PCM 16-bit.
class AudioService extends ChangeNotifier implements CopilotAudioIO {
  AudioRecorder? _recorder;
  AudioPlayer? _player;

  bool _isRecording = false;
  bool _isPlaying = false;
  StreamSubscription? _recordSubscription;

  // Stream controller for outbound audio chunks
  final StreamController<Uint8List> _audioChunkController =
      StreamController<Uint8List>.broadcast();

  // Audio output buffer for playback
  final List<Uint8List> _playbackBuffer = [];
  bool _isProcessingBuffer = false;

  // Latency Confidence Ping (Sonar)
  Timer? _latencyTimer;
  Timer? _pingLoopTimer;

  // Public getters
  @override
  bool get isRecording => _isRecording;
  bool get isPlaying => _isPlaying;
  @override
  Stream<Uint8List> get audioChunkStream => _audioChunkController.stream;

  /// Start recording audio from the microphone.
  @override
  Future<void> startRecording() async {
    if (_isRecording) return;

    try {
      if (kIsWeb) {
        await _startWebRecording();
      } else {
        await _startNativeRecording();
      }
    } catch (e) {
      debugPrint('AudioService: Failed to start recording: $e');
      _isRecording = false;
      notifyListeners();
    }
  }

  Future<void> _startNativeRecording() async {
    _recorder ??= AudioRecorder();
    final hasPermission = await _recorder!.hasPermission();
    if (!hasPermission) {
      debugPrint('AudioService: Microphone permission denied');
      _isRecording = false;
      notifyListeners();
      return;
    }

    try {
      final stream = await _recorder!.startStream(
        const RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          numChannels: 1,
          sampleRate: AppConfig.audioInputSampleRate,
        ),
      );

      _recordSubscription = stream.listen((data) {
        _audioChunkController.add(Uint8List.fromList(data));
      });

      _isRecording = true;
      _resetLatencyTimer();
      notifyListeners();
      debugPrint('AudioService: Recording started (16kHz PCM mono)');
    } catch (e) {
      debugPrint('AudioService: Native stream start failed: $e');
      _isRecording = false;
      notifyListeners();
    }
  }

  Future<void> _startWebRecording() async {
    // Use the web audio bridge (MediaRecorder API)
    try {
      final started = await web_audio.WebAudioBridge.startRecording(
        onChunk: (chunk) => _audioChunkController.add(chunk),
      );

      if (!started) {
        debugPrint('AudioService: Web mic not available (permission denied?)');
        _isRecording = false;
        notifyListeners();
        return;
      }

      _isRecording = true;
      _resetLatencyTimer();
      notifyListeners();
      debugPrint('AudioService: Recording started (web MediaRecorder)');
    } catch (e) {
      debugPrint('AudioService: Web recording failed: $e');
      _isRecording = false;
      notifyListeners();
    }
  }

  /// Stop recording audio.
  @override
  Future<void> stopRecording() async {
    if (!_isRecording) return;

    try {
      if (kIsWeb) {
        web_audio.WebAudioBridge.stopRecording();
      } else {
        await _recordSubscription?.cancel();
        _recordSubscription = null;
        await _recorder?.stop();
      }
    } catch (e) {
      debugPrint('AudioService: Error stopping recording: $e');
    }

    _isRecording = false;
    _cancelLatencyPing();
    notifyListeners();
    debugPrint('AudioService: Recording stopped');
  }

  /// Queue PCM audio data from Gemini for playback.
  @override
  void queueAudioResponse(Uint8List pcmData) {
    _cancelLatencyPing();
    
    if (kIsWeb) {
      _isPlaying = true;
      notifyListeners();
      web_audio.WebAudioBridge.playAudioChunk(pcmData, AppConfig.audioOutputSampleRate);
      
      // We don't have a reliable end-callback from web audio nodes easily, so we just set false after a timeout
      // or rely on Gemini's `turnComplete` message.
      Future.delayed(const Duration(milliseconds: 500), () {
        if (_playbackBuffer.isEmpty) {
          _isPlaying = false;
          notifyListeners();
        }
      });
      return;
    }
    
    _playbackBuffer.add(pcmData);
    _processPlaybackBuffer();
  }

  /// Stop any currently playing audio (for barge-in).
  @override
  Future<void> stopPlayback() async {
    _playbackBuffer.clear();
    
    if (kIsWeb) {
      web_audio.WebAudioBridge.stopPlayback();
    } else {
      try {
        await _player?.stop();
      } catch (_) {}
    }
    
    _isPlaying = false;
    _resetLatencyTimer(); // Agent stopped, we are listening again
    notifyListeners();
  }

  /// Process the playback buffer sequentially (used for Native targets).
  Future<void> _processPlaybackBuffer() async {
    if (_isProcessingBuffer || _playbackBuffer.isEmpty) return;
    _isProcessingBuffer = true;
    _isPlaying = true;
    notifyListeners();

    while (_playbackBuffer.isNotEmpty) {
      final chunk = _playbackBuffer.removeAt(0);
      try {
        _player ??= AudioPlayer();
        final wavData = _createWavBytes(
          chunk,
          sampleRate: AppConfig.audioOutputSampleRate,
          numChannels: 1,
          bitsPerSample: 16,
        );
        final source = _PcmAudioSource(wavData);
        await _player!.setAudioSource(source);
        await _player!.play();
        await _player!.playerStateStream.firstWhere(
          (state) => state.processingState == ProcessingState.completed,
        );
      } catch (e) {
        debugPrint('AudioService: Playback error: $e');
      }
    }

    _isPlaying = false;
    _isProcessingBuffer = false;
    _resetLatencyTimer(); // Agent finished processing buffer
    notifyListeners();
  }

  // --- Latency Confidence "Sonar Ping" ---
  
  void _resetLatencyTimer() {
    _cancelLatencyPing();
    if (!_isRecording) return;
    
    // If agent is silent for 4 seconds while active, start pinging
    _latencyTimer = Timer(const Duration(seconds: 4), () {
      _startPinging();
    });
  }

  void _startPinging() {
    if (!_isRecording || _isPlaying) return;
    
    debugPrint('AudioService: High latency detected, starting confidence ping');
    
    if (kIsWeb) {
      _pingLoopTimer = Timer.periodic(const Duration(seconds: 2), (_) {
        if (!_isPlaying) _playWebSonarPing();
      });
      _playWebSonarPing();
    }
  }

  void _cancelLatencyPing() {
    _latencyTimer?.cancel();
    _latencyTimer = null;
    _pingLoopTimer?.cancel();
    _pingLoopTimer = null;
  }
  
  void _playWebSonarPing() {
    // Generate a subtle ping using WebAudioBridge if needed.
    // In our implementation, we'll try to invoke playPing if it exists, or just log.
    try {
      web_audio.WebAudioBridge.playPing();
    } catch (_) {
      // Fallback if not specifically implemented
    }
  }

  /// Synthesizes local audio guidance for low-vision safety when the network drops.
  void speakOfflineGuidance(String prompt) {
    if (kIsWeb) {
      try {
        web_audio.WebAudioBridge.speakOfflinePrompt(prompt);
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    stopRecording();
    stopPlayback();
    _recorder?.dispose();
    _player?.dispose();
    _audioChunkController.close();
    super.dispose();
  }

  Uint8List _createWavBytes(
    Uint8List pcmData, {
    required int sampleRate,
    required int numChannels,
    required int bitsPerSample,
  }) {
    final byteRate = sampleRate * numChannels * (bitsPerSample ~/ 8);
    final blockAlign = numChannels * (bitsPerSample ~/ 8);
    final dataSize = pcmData.length;
    final fileSize = 36 + dataSize;

    final header = ByteData(44);
    header.setUint8(0, 0x52); header.setUint8(1, 0x49);
    header.setUint8(2, 0x46); header.setUint8(3, 0x46);
    header.setUint32(4, fileSize, Endian.little);
    header.setUint8(8, 0x57); header.setUint8(9, 0x41);
    header.setUint8(10, 0x56); header.setUint8(11, 0x45);
    header.setUint8(12, 0x66); header.setUint8(13, 0x6D);
    header.setUint8(14, 0x74); header.setUint8(15, 0x20);
    header.setUint32(16, 16, Endian.little);
    header.setUint16(20, 1, Endian.little);
    header.setUint16(22, numChannels, Endian.little);
    header.setUint32(24, sampleRate, Endian.little);
    header.setUint32(28, byteRate, Endian.little);
    header.setUint16(32, blockAlign, Endian.little);
    header.setUint16(34, bitsPerSample, Endian.little);
    header.setUint8(36, 0x64); header.setUint8(37, 0x61);
    header.setUint8(38, 0x74); header.setUint8(39, 0x61);
    header.setUint32(40, dataSize, Endian.little);

    final result = Uint8List(44 + dataSize);
    result.setAll(0, Uint8List.sublistView(header));
    result.setAll(44, pcmData);
    return result;
  }
}

// ignore: avoid_classes_with_only_static_members, directives_ordering
class _PcmAudioSource extends StreamAudioSource {
  final Uint8List _wavData;
  _PcmAudioSource(this._wavData);

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    final s = start ?? 0;
    final e = end ?? _wavData.length;
    return StreamAudioResponse(
      sourceLength: _wavData.length,
      contentLength: e - s,
      offset: s,
      stream: Stream.value(_wavData.sublist(s, e)),
      contentType: 'audio/wav',
    );
  }
}
