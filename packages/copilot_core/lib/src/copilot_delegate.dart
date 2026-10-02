import 'gozai_session_types.dart';

/// The single seam between the Gemini session and the app.
///
/// The session (`GeminiLiveService`) declares this interface and calls it when
/// the model emits a tool call (an **Intent**). The `SessionCoordinator`
/// implements it by driving actuators (haptics, flashlight, Ghost Touch, SOS,
/// memory) and by updating session state.
///
/// This replaces the former 15 individual `on*` callback fields: one named
/// interface means tool dispatch is testable with a fake delegate and the
/// intent contract is greppable in one file.
abstract class CopilotDelegate {
  // --- Camera & vision ---
  void onSwitchCamera();
  void onSwitchMode(GozAIMode mode);
  void onCaptureSnapshot();
  void onAnalyzeDocument();        // High-res OCR request for micro text
  void onToggleDebugCamera(bool visible); // Voice-activated video feed

  // --- Hardware & safety ---
  void onToggleFlashlight(bool on);
  void onRequestHardwareAccess(String hardwareType, String action);
  void onSendSosAlert(String message, String severity, String target);

  // --- Haptics & spatial awareness ---
  void onTriggerHaptic(String pattern);
  void onSpatialUpdate(String context);   // Cognitive mapping
  void onInterrupted();                   // Barge-in: user spoke over the model

  // --- Digital accessibility (UI Navigator) ---
  void onClickUiElement(double x, double y); // AI-synthesized tap

  // --- Session & memory ---
  void onDisconnect();
  void onOpenTranscripts();        // Voice-activated transcripts
  void onRememberFact(String category, String fact); // Companion memory
}

/// The slice of intents that must touch the widget tree.
///
/// `SessionCoordinator` owns everything device-shaped; these intents flip
/// UI state (the floating debug camera window and the transcripts route), so
/// they are forwarded to the screen through this hook.
abstract class CopilotUiHooks {
  void setShowDebugCamera(bool visible);
  void openTranscripts();

  /// Metrics used to scale the model's 1080x1920 tap coordinates onto the
  /// actual device. Read from the screen's MediaQuery.
  ({double width, double height, double pixelRatio}) uiMetrics();
}
