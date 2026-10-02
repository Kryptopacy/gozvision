import 'package:flutter_dotenv/flutter_dotenv.dart';

/// App-wide configuration loaded from environment variables.
class AppConfig {
  /// Fallback patient identity for the demo flow when no session exists.
  /// The zero-UI flow signs in as the seeded demo patient (see
  /// [demoPatientEmail]) so every write satisfies RLS as a real identity.
  /// See CONTEXT.md ("Patient identity").
  static const String patientId = 'demo_patient_001';

  /// The ADK agent module running on Cloud Run (backend/gozvision_agent/).
  /// Used to address the agent in ADK API server routes (/apps/{app}/..., /run).
  static const String adkAgentName = 'gozvision_agent';

  static String get geminiApiKey => dotenv.env['GEMINI_API_KEY'] ?? '';

  /// Supabase backend (auth + Postgres). See supabase/migrations/ and ADR-0003.
  static String get supabaseUrl =>
      dotenv.env['SUPABASE_URL'] ?? 'http://127.0.0.1:54321';
  static String get supabasePublishableKey =>
      dotenv.env['SUPABASE_ANON_KEY'] ?? '';

  /// Zero-UI demo credentials: when present, the copilot signs in as the
  /// seeded demo patient so every write happens under a real identity.
  static String get demoPatientEmail => dotenv.env['DEMO_PATIENT_EMAIL'] ?? '';
  static String get demoPatientPassword =>
      dotenv.env['DEMO_PATIENT_PASSWORD'] ?? '';

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
