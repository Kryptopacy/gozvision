
library;


import 'package:flutter/foundation.dart';

/// The device-facing service contracts of the Copilot Loop.
///
/// `SessionCoordinator` wires the loop through these interfaces — never
/// through concrete implementations. The host app provides the real adapters
/// (Flutter camera, Firestore memory, ML Kit OCR, ...); tests provide fakes.
/// This is the second deepening seam of the loop: one contract set, N hosts
/// (patient app today, clinic embeds tomorrow).

// --- Senses ---

/// Camera sense: frames out, stills, flashlight.
abstract class CopilotCamera {
  Future<void> initialize();
  Future<void> switchCamera();
  void startStreaming();
  void stopStreaming();
  Future<Uint8List?> captureSnapshot();
  Future<void> toggleFlashlight(bool on);
  bool get isInitialized;
  bool get initFailed;
  bool get isStreaming;
  Stream<Uint8List> get frameStream;
}

/// Microphone + speaker: audio in to the session, model audio out.
abstract class CopilotAudioIO {
  Future<void> startRecording();
  Future<void> stopRecording();
  Future<void> stopPlayback();
  void queueAudioResponse(Uint8List pcmData);
  bool get isRecording;
  Stream<Uint8List> get audioChunkStream;
}

/// Screen capture for UI Navigator mode.
abstract class CopilotScreenCapture {
  void startStreaming();
  void stopStreaming();
  Stream<Uint8List> get frameStream;
}

/// The result of one offline OCR pass — character-accurate grounding.
abstract class CopilotOcrRead {
  String get fullText;
  bool get isEmpty;
  bool get isNotEmpty;
  String buildGroundingString({bool isMedication = false, bool isNutrition = false});
}

/// Offline text recognition.
abstract class CopilotOcr {
  Future<CopilotOcrRead> recognizeFromBytes(Uint8List bytes);
  bool isMedicationLabel(CopilotOcrRead result);
  bool isPrescriptionLabel(CopilotOcrRead result);
  bool isNutritionLabel(CopilotOcrRead result);
}

/// Offline light meter (lux + orientation tone).
abstract class CopilotLightMeter {
  bool get isActive;
  double get currentLux;
  void start();
  void stop();
  void processFrameBrightness(Uint8List jpegBytes);
  set onToneUpdate(Function(double frequency)? callback);
  set onProactiveDarknessWarning(Function()? callback);
}

// --- Actuators & stores ---

/// Semantic vibro-acoustic feedback (the non-visual channel).
abstract class CopilotHaptics {
  Future<void> tap();
  Future<void> alert();
  Future<void> hazardWarning();
  Future<void> personDetected();
  Future<void> navigationCue();
  Future<void> safePathConfirm();
  Future<void> environmentKnown();
  Future<void> modeSwitch();
  Future<void> connected();
}

/// Clinical telemetry sink (reading stamina, hazards, contrast demand).
abstract class CopilotTelemetry {
  void logHazardDetected(String pattern);
  void logReadingStamina(Duration duration);
  void logSpatialDisorientation();
  void logOcrAssist(double lux, int characters);
}

/// Companion memory store (cross-session facts).
abstract class CopilotMemory {
  Future<void> loadMemory(String userId);
  Future<void> storeFact({
    required String userId,
    required String category,
    required String fact,
  });
  List<Map<String, dynamic>> get facts;
  String? buildMemoryContext();
}

/// The SOS alert sink — owns the alert document contract.
abstract class CopilotAlertSink {
  Future<void> sendAlert({
    required String userId,
    required String message,
    required String severity,
    String target = 'caregiver',
  });
}

abstract class CopilotBarcodeScanner {
  Future<String?> scanFromBytes(Uint8List bytes);
}

/// A looked-up product, grounded for injection into the session.
class ScannedProduct {
  final String grounding;
  const ScannedProduct(this.grounding);
  String toGroundingString() => grounding;
}

abstract class CopilotProductLookup {
  Future<ScannedProduct?> lookup(String barcode);
}

// --- Identity & platform ---

/// Who the copilot serves 
abstract class CopilotIdentity {
  String get userId;
}

/// Platform facts: connectivity, battery, tones. Host apps provide real
/// implementations per platform; tests provide no-ops.
abstract class CopilotPlatformMonitor {
  void setupConnectivityMonitoring({
    required VoidCallback onOffline,
    required VoidCallback onOnline,
  });

  void setupBatteryMonitoring({
    required Function(double level, bool charging) onLowBattery,
  });

  /// Play a pitched tone (e.g. the light meter's orientation tone).
  void playTone(double frequency, double durationSeconds);

  void dispose();
}
