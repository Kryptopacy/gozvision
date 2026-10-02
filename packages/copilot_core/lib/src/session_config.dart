/// Session configuration the host app injects (GozAI kept this in a
/// global AppConfig; the package takes it as a value so hosts own their
/// environment loading).
class SessionConfig {
  /// WebSocket endpoint for the Gemini Multimodal Live API
  /// (BidiGenerateContent, v1alpha).
  final String geminiLiveWsUrl;

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

  const SessionConfig({
    required this.geminiLiveWsUrl,
    required this.geminiModel,
    this.audioInputSampleRate = 16000,
    required this.demoPatientId,
    required this.adkBackendUrl,
    this.adkAgentName = 'gozvision_agent',
  });
}
