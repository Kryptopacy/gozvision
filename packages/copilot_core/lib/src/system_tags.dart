/// The Tag vocabulary — the contract between the system prompt and the
/// producers of context pulses.
///
/// Every silent message injected into the session starts with a bracketed
/// tag. The model is told (in `system_prompt.dart`, which interpolates these
/// same constants) how to react to each tag. Producers — the session
/// coordinator, the OCR service, the memory service — build pulses with the
/// builders below, never with hand-typed strings.
///
/// Renaming a tag here propagates everywhere at once: a rename breaks the
/// build instead of silently disconnecting the prompt from its producers.
class SystemTags {
  SystemTags._();

  // --- Canonical tag names (system_prompt.dart references these) ---
  static const String lowLightTag = 'SYSTEM - LOW LIGHT DETECTED';
  static const String hardwareCapabilitiesTag =
      'SYSTEM - HARDWARE CAPABILITIES UPDATE';
  static const String hardwareUpdateTag = 'SYSTEM - HARDWARE UPDATE';
  static const String idleCheckInTag = 'SYSTEM - IDLE CHECK-IN';
  static const String connectivityLostTag = 'SYSTEM - CONNECTIVITY LOST';
  static const String connectivityRestoredTag =
      'SYSTEM - CONNECTIVITY RESTORED';
  static const String lowBatteryTag = 'SYSTEM - LOW BATTERY';
  static const String onboardingTag = 'SYSTEM - ONBOARDING';
  static const String autoLaunchTag = 'SYSTEM - AUTO-LAUNCH';
  static const String userMemoryTag =
      'SYSTEM - USER MEMORY (from previous sessions)';
  static const String ocrContextTag =
      'OCR Context — do not read this aloud unless the user asks';
  static const String medicationLabelTag = 'MEDICATION LABEL';
  static const String nutritionLabelTag = 'NUTRITION LABEL';
  static const String profileSwitchedTag = 'SYSTEM - VISION PROFILE SWITCHED';

  // Internal pipeline tags (session machinery, not model behavior rules)
  static const String _internalTag = 'SYSTEM - INTERNAL';
  static const String _errorTag = 'SYSTEM - ERROR';
  static const String _ocrResultTag = 'SYSTEM - OCR RESULT';
  static const String _ocrCaptureTag = 'SYSTEM - OCR CAPTURE SUCCESSFUL';

  // --- Context pulse builders ---

  /// Ambient light dropped below the readable threshold (LightMeterService).
  static String lowLight() =>
      '[$lowLightTag] The ambient light level is near zero. The camera feed '
      'is likely too dark to see obstacles clearly. Proactively notify the '
      'user and ask if they would like you to turn on the flashlight.';

  /// High-res OCR snapshot about to be taken (analyzeDocument intent).
  static String ocrSnapshotStarted() =>
      '[$_internalTag] Taking high-resolution snapshot for OCR... please '
      'ask the user to hold the document steady for a moment.';

  static String ocrSnapshotFailed() =>
      '[$_errorTag] Failed to capture snapshot. Inform the user.';

  static String ocrNoTextDetected() =>
      '[$_ocrResultTag] No text detected in the frame. Ask the user to '
      'adjust the document and try again.';

  /// Offline OCR text from a high-res snapshot, ready to be read aloud.
  static String ocrCaptureSuccessful(String grounding) =>
      '[$_ocrCaptureTag]\n$grounding\n'
      'Please read this precisely to the user based on their question.';

  /// Silent grounding prefix for periodic OCR frames in Read mode.
  static String ocrGrounding(String grounding) =>
      '[$ocrContextTag]: The following structured text was detected on '
      'camera with offline OCR. Use the bounding boxes to infer layout like '
      'columns or tables:\n$grounding';

  /// Microphone/camera truth state, injected after hardware changes.
  static String hardwareStatus({required bool micOn, required bool cameraOn}) {
    final buffer = StringBuffer('[$hardwareCapabilitiesTag]\n');
    buffer.writeln(micOn ? '- Microphone: ON' : '- Microphone: OFF (Disabled or failed)');
    buffer.writeln(cameraOn ? '- Camera: ON' : '- Camera: OFF/FAILED');
    return buffer.toString();
  }

  /// Missing-hardware warnings injected at session launch.
  static String missingHardware({required bool micMissing, required bool cameraMissing}) {
    final buffer = StringBuffer('[$hardwareCapabilitiesTag]\n');
    if (micMissing) {
      buffer.writeln('- Microphone: OFF (Permission denied or hardware busy. Remind user supportively.)');
    }
    if (cameraMissing) {
      buffer.writeln('- Camera: OFF (I am blind. Remind user that enabling camera helps with safety.)');
    }
    return buffer.toString().trimRight();
  }

  /// The user manually toggled a hardware chip on screen.
  static String micToggled(bool on) =>
      '[$hardwareUpdateTag] User manually toggled microphone. '
      'Microphone is now: ${on ? "ON" : "OFF"}.';

  static String cameraToggled(bool on) =>
      '[$hardwareUpdateTag] User manually toggled camera. '
      'Camera is now: ${on ? "ON" : "OFF"}.';

  /// Gentle check-in after a long silence.
  static String idleCheckIn() =>
      '[$idleCheckInTag]: The user has been silent for a while. '
      'Gently check in with a single short sentence. Do NOT be annoying — '
      'just a brief "Still here if you need me" or similar. '
      'If they do not respond after this, stay completely silent.';

  static String connectivityLost() =>
      '[$connectivityLostTag]: The device has lost internet connection. '
      'Inform the user briefly that you may disconnect, but will reconnect '
      'when internet is back.';

  static String connectivityRestored() =>
      '[$connectivityRestoredTag]: Internet connection is back. '
      'Briefly reassure the user that you are back online.';

  static String lowBattery(int percent) =>
      '[$lowBatteryTag]: Device battery is at $percent%. '
      'Briefly warn the user that their battery is low and suggest charging '
      'to keep GozAI available for their safety.';

  /// First-run welcome vs. returning-user welcome, injected at launch.
  static String onboarding() =>
      '[$onboardingTag]\nThis is a new user. Welcome them and ask for '
      'their name gracefully.';

  static String welcomeBack(String userName) =>
      '[$autoLaunchTag]\nWelcome $userName back to GozAI.';

  /// User switched between low-vision assist and clinic companion modes.
  static String profileSwitched(String profile) =>
      '[$profileSwitchedTag]: Vision profile switched to "$profile". '
      'If "clinicCompanion", transition to visual-first, quiet companion behavior (no continuous scene narrations). '
      'If "lowVisionAssist", transition to voice-first, proactive obstacle warning, high-accessibility behavior.';
}

