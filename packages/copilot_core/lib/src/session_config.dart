/// Session configuration the host app injects (GozAI kept this in a
/// global AppConfig; the package takes it as a value so hosts own their
/// environment loading).
class SessionConfig {
  /// Resolves a fresh authenticated WebSocket endpoint for each Live session.
  /// Browser hosts should mint a one-use ephemeral token through their backend;
  /// native and test hosts may return a fixed endpoint.
  final Future<String> Function() resolveGeminiLiveWsUrl;

  /// Gemini model for multimodal live.
  final String geminiModel;

  /// Audio recording sample rate (Hz) — the Live API expects 16kHz input.
  final int audioInputSampleRate;

  /// The demo patient id used only when no real identity exists
  /// (CONTEXT.md — "Patient identity"). Keep in sync with the backend's
  /// `_DEMO_PATIENT_ID`.
  final String demoPatientId;

  /// Base URL of the ADK API server on Cloud Run (no trailing slash).
  final String adkBackendUrl;

  /// The ADK agent module name (backend/agents/).
  final String adkAgentName;

  SessionConfig({
    required this.resolveGeminiLiveWsUrl,
    required this.geminiModel,
    this.audioInputSampleRate = 16000,
    required this.demoPatientId,
    required this.adkBackendUrl,
    this.adkAgentName = 'gozvision_agent',
  });
}
