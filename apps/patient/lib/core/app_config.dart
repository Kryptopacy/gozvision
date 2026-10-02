import 'package:flutter_dotenv/flutter_dotenv.dart';

/// App-wide configuration loaded from environment variables.
class AppConfig {
  /// The patient this installation serves. Single definition point for the
  /// demo identity — every Firestore read/write for patient data references
  /// [patientId] instead of a hand-typed id. See CONTEXT.md ("Patient").
  static const String patientId = 'demo_patient_001';

  /// The ADK agent module name running on Cloud Run (backend/agents/).
  /// Used to address the agent in ADK API server routes (/apps/{app}/..., /run).
  static const String adkAgentName = 'gozvision_agent';

  static String get geminiApiKey => dotenv.env['GEMINI_API_KEY'] ?? '';
  static String get firebaseProjectId =>
      dotenv.env['FIREBASE_PROJECT_ID'] ?? 'gozai-app';
  static String get adkBackendUrl =>
      dotenv.env['ADK_BACKEND_URL'] ?? 'http://localhost:8080';

  /// Gemini Multimodal Live API WebSocket endpoint.
  /// BidiGenerateContent WebSocket utilizes v1alpha for the native audio preview model.
  static String get geminiLiveWsUrl =>
      'wss://generativelanguage.googleapis.com/ws/google.ai.generativelanguage.v1alpha.GenerativeService.BidiGenerateContent?key=$geminiApiKey';

  /// Gemini model for multimodal live.
  /// bidiGenerateContent endpoint on v1alpha.
  static const String geminiModel = 'models/gemini-2.5-flash-native-audio-preview-12-2025';

  /// Camera frame rate for continuous monitoring (frames per second)
  static const double cameraFps = 1.0;

  /// Audio recording sample rate (Hz) — Gemini expects 16kHz
  static const int audioInputSampleRate = 16000;

  /// Audio playback sample rate (Hz) — Gemini outputs 24kHz
  static const int audioOutputSampleRate = 24000;

  /// Validate that required config is present
  static bool get isConfigured => geminiApiKey.isNotEmpty;
}
