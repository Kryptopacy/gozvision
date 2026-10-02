/// Shared types for the Copilot Loop.
///
/// These enums describe the session's mode and connection state. They live in
/// `core/` (not in the service layer) so both the Gemini session transport and
/// the session coordinator can reference them without a layering violation.
/// `gemini_live_service.dart` re-exports this file for compatibility.
library;

/// The current interaction mode of the copilot.
enum GozAIMode {
  scene,      // Continuous scene monitoring
  reading,    // OCR / text reading
  uiNav,      // UI Navigator / digital accessibility
  lightMeter, // Offline light meter
}

/// Connection state for the Gemini Live session.
enum GeminiConnectionState {
  disconnected,
  connecting,
  connected,
  error,
}
