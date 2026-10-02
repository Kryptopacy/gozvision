import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';

import 'copilot_delegate.dart';
import 'gemini_live_service.dart';
import 'service_contracts.dart';
import 'system_tags.dart';

/// The Copilot Loop's brain — the deep module that wires the loop together.
///
/// Owns every wiring HomeScreen used to do inline:
/// - SENSES → SESSION: camera frames (with OCR/barcode grounding in Read
///   mode), screen capture (UI Navigator mode), audio in/out, light meter.
/// - CONTEXT → SESSION: launch context (personalization from companion
///   memory), hardware truth state, idle check-ins, connectivity/battery
///   pulses, low-light warnings.
/// - INTENTS → ACTUATORS: implements [CopilotDelegate] so the Gemini session
///   can drive haptics, flashlight, Ghost Touch, SOS, and memory without
///   knowing a single device detail.
///
/// UI-shaped intents (debug camera window, transcripts route) are forwarded
/// through [CopilotUiHooks] so this module stays widget-free and testable.
class SessionCoordinator implements CopilotDelegate {
  SessionCoordinator({
    required this.gemini,
    required this.camera,
    required this.audio,
    required this.ocr,
    required this.screenCapture,
    required this.lightMeter,
    required this.telemetry,
    required this.memory,
    required this.sos,
    required this.barcode,
    required this.productLookup,
    required this.identity,
    required this.haptics,
    required CopilotPlatformMonitor platformMonitor,
  }) : _platformMonitor = platformMonitor; // ignore: prefer_initializing_formals — named params cannot be private

  final GeminiLiveService gemini;
  final CopilotCamera camera;
  final CopilotAudioIO audio;
  final CopilotOcr ocr;
  final CopilotScreenCapture screenCapture;
  final CopilotLightMeter lightMeter;
  final CopilotTelemetry telemetry;
  final CopilotMemory memory;
  final CopilotAlertSink sos;
  final CopilotBarcodeScanner barcode;
  final CopilotProductLookup productLookup;
  final CopilotIdentity identity;
  final CopilotHaptics haptics;
  final CopilotPlatformMonitor _platformMonitor;

  CopilotUiHooks? _uiHooks;
  bool _attached = false;

  // Stream subscriptions (senses → session)
  StreamSubscription<Uint8List>? _cameraFrameSubscription;
  StreamSubscription<Uint8List>? _lightMeterFrameSubscription;
  StreamSubscription<Uint8List>? _screenCaptureSubscription;
  StreamSubscription<Uint8List>? _audioSendSubscription;
  StreamSubscription<Uint8List>? _audioIdleSubscription;
  StreamSubscription<Uint8List>? _audioOutputSubscription;

  // OCR grounding: run offline OCR every N frames in Read mode
  int _ocrFrameCounter = 0;
  static const int _ocrFrameInterval = 3;

  // Barcode pipeline: one scan at a time
  bool _isScanningBarcode = false;

  // Clinical telemetry: track how long patients can read before fatigue
  DateTime? _readingModeStartTime;

  // Idle check-in: if the user is silent for too long, Goz gently checks in
  Timer? _idleCheckInTimer;
  static const Duration _idleCheckInDuration = Duration(seconds: 90);

  // Edge cases: offline detection + battery monitoring
  bool _wasOffline = false;
  bool _lowBatteryWarned = false;

  /// Wire the whole Copilot Loop. Call once after the first frame.
  Future<void> attach({CopilotUiHooks? uiHooks}) async {
    if (_attached) return;
    _attached = true;
    _uiHooks = uiHooks;

    await camera.initialize();

    // Hardware state changes from the OS (connectivity, battery)
    _setupPlatformMonitoring();

    // The session dispatches intents to this coordinator
    gemini.delegate = this;

    // Light meter audio tone feedback.
    // On web: plays a continuous oscillator that shifts frequency with light level.
    // On native: the tone is described aloud by Gemini when the user asks.
    lightMeter.onToneUpdate = (frequency) {
      if (!kIsWeb) return; // Native: Gemini speech handles descriptions
      _platformMonitor.playTone(frequency, 0.18);
    };
    lightMeter.onProactiveDarknessWarning = () {
      debugPrint('GozAI: Proactive darkness warning triggered.');
      gemini.sendText(SystemTags.lowLight());
    };

    // Feed camera frames to the light meter for offline luminance analysis
    _lightMeterFrameSubscription = camera.frameStream.listen((frameBytes) {
      if (lightMeter.isActive) {
        lightMeter.processFrameBrightness(frameBytes);
      }
    });

    // Camera frames → Gemini (with OCR/barcode grounding in Read mode)
    _cameraFrameSubscription = camera.frameStream.listen(_onCameraFrame);

    // Reset idle timer whenever the user is talking
    _audioIdleSubscription = audio.audioChunkStream.listen((_) {
      _resetIdleTimer();
    });

    // Audio input → Gemini
    _audioSendSubscription = audio.audioChunkStream.listen((chunk) {
      gemini.sendAudio(chunk);
    });

    // Gemini audio output → speaker
    _audioOutputSubscription = gemini.audioOutputStream.listen((audioData) {
      audio.queueAudioResponse(audioData);
    });

    // Internal UI frames → Gemini (UI Navigator mode)
    _screenCaptureSubscription = screenCapture.frameStream.listen((frame) {
      if (gemini.currentMode != GozAIMode.uiNav) return;
      gemini.sendVideoFrame(frame); // Gemini sees the UI as the camera
    });

    // Zero-UI Launch: Automatically start the session and open the mic upon app open
    if (!gemini.isConnected && !audio.isRecording) {
      debugPrint('GozAI: Auto-starting session for Zero-UI launch.');
      await toggleSession();
    }
  }

  /// Unwire everything. Safe to call multiple times.
  void detach() {
    _attached = false;
    _uiHooks = null;
    gemini.delegate = null;
    _cameraFrameSubscription?.cancel();
    _lightMeterFrameSubscription?.cancel();
    _screenCaptureSubscription?.cancel();
    _audioSendSubscription?.cancel();
    _audioIdleSubscription?.cancel();
    _audioOutputSubscription?.cancel();
    _idleCheckInTimer?.cancel();
    _platformMonitor.dispose();
  }

  // --- Session lifecycle ---

  /// Start or stop the full session: hardware, streams, and Gemini.
  Future<void> toggleSession() async {
    if (gemini.isConnected && audio.isRecording) {
      // Stop session
      await audio.stopRecording();
      camera.stopStreaming();
      screenCapture.stopStreaming();
      // Stop light meter if active
      lightMeter.stop();
      await gemini.disconnect();
      haptics.tap();
    } else {
      // Light meter mode is offline-only
      if (gemini.currentMode == GozAIMode.lightMeter) {
        lightMeter.start();
        haptics.connected();
        return;
      }

      // Start hardware first to verify permissions/state
      await audio.startRecording();

      if (gemini.currentMode == GozAIMode.uiNav) {
        camera.stopStreaming();
        screenCapture.startStreaming();
      } else {
        screenCapture.stopStreaming();
        camera.startStreaming();
      }

      // Build definitive hardware truth state
      String hardwareContext = '';
      final bool micMissing = !audio.isRecording;
      final bool cameraMissing = !camera.isInitialized || camera.initFailed;

      if (micMissing || cameraMissing) {
        hardwareContext = SystemTags.missingHardware(
          micMissing: micMissing,
          cameraMissing: cameraMissing,
        );
      }

      // Check for personalization: Do we know the user's name?
      await memory.loadMemory(identity.userId);

      String? userName;
      try {
        final nameFact = memory.facts.firstWhere(
          (f) => f['category'] == 'person' && (f['fact'] as String).toLowerCase().contains('name is'),
        );
        final factText = nameFact['fact'] as String;
        // Extract name if pattern is "User's name is X" or similar
        final parts = factText.split(' is ');
        if (parts.length > 1) userName = parts.last.replaceAll('.', '').trim();
      } catch (_) {
        userName = null;
      }

      final String launchContext = userName == null
          ? SystemTags.onboarding()
          : SystemTags.welcomeBack(userName);

      // Build final context
      final memoryContext = memory.buildMemoryContext();
      String finalContext = launchContext;
      if (hardwareContext.isNotEmpty) {
        finalContext += '\n\n$hardwareContext';
      }
      if (memoryContext != null) {
        finalContext += '\n$memoryContext';
      }

      // Start Gemini streaming session
      await gemini.connect(hardwareContext: finalContext);

      // Start the idle check-in timer
      _resetIdleTimer();

      haptics.connected();
    }
  }

  /// Capture a high-res snapshot and ask the model to describe it.
  Future<void> captureSnapshot() async {
    if (!gemini.isConnected) return;
    final snapshot = await camera.captureSnapshot();
    if (snapshot != null) {
      gemini.sendVideoFrame(snapshot);
      gemini.sendText('Describe what you see in detail.');
      haptics.tap();
    }
  }

  /// Switch modes with the full telemetry treatment. Called by both the
  /// on-screen mode selector ([fromUserTap] = true) and the model's
  /// switchMode intent.
  Future<void> selectMode(GozAIMode mode, {bool fromUserTap = false}) async {
    if (fromUserTap) {
      // Log spatial wandering if modes are cycled too fast
      telemetry.logSpatialDisorientation();
    }

    // Telemetry: Log reading stamina if we are leaving reading mode
    if (gemini.currentMode == GozAIMode.reading && mode != GozAIMode.reading) {
      if (_readingModeStartTime != null) {
        final duration = DateTime.now().difference(_readingModeStartTime!);
        telemetry.logReadingStamina(duration);
        _readingModeStartTime = null;
      }
    } else if (mode == GozAIMode.reading &&
        gemini.currentMode != GozAIMode.reading) {
      _readingModeStartTime = DateTime.now();
    }

    await gemini.switchMode(mode);
    haptics.modeSwitch();
  }

  /// Toggle the microphone from the on-screen status chip.
  Future<void> setMicEnabled(bool enabled) async {
    if (enabled) {
      await audio.startRecording();
    } else {
      await audio.stopRecording();
    }
    haptics.tap();
    gemini.sendText(SystemTags.micToggled(audio.isRecording));
  }

  /// Toggle the camera from the on-screen status chip.
  Future<void> setCameraEnabled(bool enabled) async {
    if (enabled) {
      if (!camera.isInitialized || camera.initFailed) {
        await camera.initialize();
      }
      if (camera.isInitialized && !camera.initFailed) {
        camera.startStreaming();
      }
    } else {
      camera.stopStreaming();
    }
    haptics.tap();
    final nowOn = camera.isInitialized && !camera.initFailed && camera.isStreaming;
    gemini.sendText(SystemTags.cameraToggled(nowOn));
  }

  // --- Senses → Session pipelines ---

  void _onCameraFrame(Uint8List frame) {
    if (gemini.currentMode == GozAIMode.uiNav) return; // UI nav uses screen frames

    gemini.sendVideoFrame(frame);

    // In Read mode, run offline OCR every N frames and send extracted text
    // as grounding context so Gemini is anchored to actual on-screen characters.
    if (gemini.currentMode == GozAIMode.reading) {
      // 1. Try barcode scan first for Universal Product Scanner pipeline
      if (!_isScanningBarcode) {
        _isScanningBarcode = true;
        barcode.scanFromBytes(frame).then((code) async {
          if (code != null) {
            final product = await productLookup.lookup(code);
            if (product != null) {
              gemini.sendText(product.toGroundingString());
              haptics.tap();
            }
          }
          _isScanningBarcode = false;
        });
      }

      // 2. Run OCR Grounding every N frames
      _ocrFrameCounter++;
      if (_ocrFrameCounter >= _ocrFrameInterval) {
        _ocrFrameCounter = 0;
        _runOcrGrounding(frame);
      }
    } else {
      _ocrFrameCounter = 0; // Reset when not in reading mode
    }
  }

  /// OCR Grounding for Read mode.
  ///
  /// Runs ML Kit offline OCR on a camera frame and sends the extracted
  /// text to Gemini as grounding context. This gives the Live API model a
  /// character-accurate anchor — preventing hallucination on text like
  /// medication dosages, expiry dates, and nutrition labels.
  Future<void> _runOcrGrounding(Uint8List frame) async {
    if (!gemini.isConnected) return;

    try {
      final result = await ocr.recognizeFromBytes(frame);
      if (result.isNotEmpty) {
        // Clinical Telemetry: Track contrast demand (how much light they needed)
        telemetry.logOcrAssist(lightMeter.currentLux, result.fullText.length);

        // Send OCR text as a silent system grounding prefix
        final isMed = ocr.isMedicationLabel(result);
        final isNutr = ocr.isNutritionLabel(result);
        final groundingString = result.buildGroundingString(
          isMedication: isMed,
          isNutrition: isNutr,
        );

        gemini.sendText(SystemTags.ocrGrounding(groundingString));
        debugPrint('OCR grounding sent: ${result.fullText.length} chars, isMed: $isMed, isNutr: $isNutr');
      }
    } catch (e) {
      debugPrint('OCR grounding error: $e');
    }
  }

  // --- Platform monitoring (connectivity, battery) ---

  void _setupPlatformMonitoring() {
    _platformMonitor.setupConnectivityMonitoring(
      onOffline: () {
        _wasOffline = true;
        if (gemini.isConnected) {
          gemini.sendText(SystemTags.connectivityLost());
        }
      },
      onOnline: () {
        if (!_wasOffline) return;
        _wasOffline = false;
        if (gemini.isConnected) {
          gemini.sendText(SystemTags.connectivityRestored());
        }
      },
    );

    _platformMonitor.setupBatteryMonitoring(
      onLowBattery: (level, charging) {
        if (level <= 0.15 && !charging && !_lowBatteryWarned) {
          _lowBatteryWarned = true;
          if (gemini.isConnected) {
            final percent = (level * 100).round();
            gemini.sendText(SystemTags.lowBattery(percent));
          }
        } else if (level > 0.20) {
          _lowBatteryWarned = false; // Reset if battery recovers
        }
      },
    );
  }

  // --- Idle check-in ---

  void _resetIdleTimer() {
    _idleCheckInTimer?.cancel();
    _idleCheckInTimer = Timer(_idleCheckInDuration, _onIdleCheckIn);
  }

  /// Fired when the user has been silent for [_idleCheckInDuration].
  void _onIdleCheckIn() {
    if (!gemini.isConnected) return;
    gemini.sendText(SystemTags.idleCheckIn());
    debugPrint('GozAI: Idle check-in triggered after ${_idleCheckInDuration.inSeconds}s of silence.');
  }

  // --- CopilotDelegate: intents from the model → actuators ---

  @override
  void onSwitchCamera() {
    camera.switchCamera();
    haptics.tap();
  }

  @override
  void onSwitchMode(GozAIMode mode) {
    selectMode(mode);
  }

  @override
  void onCaptureSnapshot() {
    captureSnapshot();
  }

  @override
  void onDisconnect() {
    toggleSession(); // Safely turns off everything
  }

  @override
  void onTriggerHaptic(String pattern) {
    switch (pattern) {
      case 'hazard':
        telemetry.logHazardDetected(pattern);
        haptics.hazardWarning();
        break;
      case 'person':
        haptics.personDetected();
        break;
      case 'navigate':
        haptics.navigationCue();
        break;
      case 'safe':
        haptics.safePathConfirm();
        break;
      case 'environment_mapped':
        haptics.environmentKnown();
        break;
      case 'tap':
        haptics.tap();
        break;
    }
  }

  @override
  void onSpatialUpdate(String context) {
    debugPrint('GozAI: Spatial context updated: $context');
  }

  @override
  void onInterrupted() {
    // True Interruption (Barge-in): instantly flush audio if Gemini detects user speech
    audio.stopPlayback();
  }

  @override
  void onToggleFlashlight(bool on) {
    camera.toggleFlashlight(on);
  }

  @override
  void onRequestHardwareAccess(String hardwareType, String action) async {
    debugPrint('GozAI: Model requested hardware access for: $hardwareType action: $action');
    if (action == 'on') {
      if (hardwareType == 'camera') {
        await camera.initialize();
        if (camera.isInitialized && !camera.initFailed) {
          camera.startStreaming();
        }
      } else if (hardwareType == 'mic') {
        await audio.startRecording();
      }
    } else if (action == 'off') {
      if (hardwareType == 'camera') {
        camera.stopStreaming();
      } else if (hardwareType == 'mic') {
        audio.stopRecording();
      }
      sos.sendAlert(
        userId: identity.userId,
        message: 'User intentionally disabled their $hardwareType feed via voice command.',
        severity: 'info',
        target: 'caregiver',
      );
    }

    // Inject the current state back so the model knows whether it succeeded
    gemini.sendText(SystemTags.hardwareStatus(
      micOn: audio.isRecording,
      cameraOn: camera.isInitialized && !camera.initFailed && camera.isStreaming,
    ));
  }

  @override
  void onClickUiElement(double x, double y) async {
    // AI-synthesized tap: inject a pointer event at the given coordinates.
    debugPrint('GozAI: AI synthesizing tap at ($x, $y)');

    final metrics = _uiHooks?.uiMetrics();
    if (metrics == null) return;
    final width = metrics.width;
    final height = metrics.height;

    final dx = (x / 1080) * width;
    final dy = (y / 1920) * height;
    final position = Offset(dx.clamp(0.0, width), dy.clamp(0.0, height));
    debugPrint('GozAI: Scaled tap to device logical pixels: $position');

    try {
      // Send absolute physical pixels to native Android AccessibilityService
      await const MethodChannel('com.gozai/accessibility').invokeMethod('dispatchClick', {
        'x': position.dx * metrics.pixelRatio,
        'y': position.dy * metrics.pixelRatio,
      });
      debugPrint('GozAI: MethodChannel executed Global OS click successfully.');
    } catch (e) {
      debugPrint('GozAI: OS-level click failed ($e). Falling back to internal GestureBinding.');
      GestureBinding.instance.handlePointerEvent(
        PointerDownEvent(
          pointer: 999,
          position: position,
          kind: PointerDeviceKind.touch,
        ),
      );
      Future.delayed(const Duration(milliseconds: 50), () {
        GestureBinding.instance.handlePointerEvent(
          PointerUpEvent(
            pointer: 999,
            position: position,
            kind: PointerDeviceKind.touch,
          ),
        );
      });
    }
  }

  @override
  void onSendSosAlert(String message, String severity, String target) {
    sos.sendAlert(
      userId: identity.userId,
      message: message,
      severity: severity,
      target: target,
    );
  }

  @override
  void onRememberFact(String category, String fact) {
    memory.storeFact(
      userId: identity.userId,
      category: category,
      fact: fact,
    );
  }

  @override
  void onToggleDebugCamera(bool visible) {
    debugPrint('GozAI: AI requested to toggle Debug Camera to: $visible');
    _uiHooks?.setShowDebugCamera(visible);
    haptics.alert();
  }

  @override
  void onOpenTranscripts() {
    debugPrint('GozAI: AI requested to open transcripts.');
    haptics.tap();
    _uiHooks?.openTranscripts();
  }

  @override
  void onAnalyzeDocument() async {
    debugPrint('GozAI: AI requested High-Res OCR scan.');
    haptics.alert();

    gemini.sendText(SystemTags.ocrSnapshotStarted());

    final snapshotData = await camera.captureSnapshot();
    if (snapshotData == null) {
      gemini.sendText(SystemTags.ocrSnapshotFailed());
      return;
    }

    final result = await ocr.recognizeFromBytes(snapshotData);

    if (result.isEmpty) {
      gemini.sendText(SystemTags.ocrNoTextDetected());
      return;
    }

    final isMed = ocr.isMedicationLabel(result) || ocr.isPrescriptionLabel(result);
    final isNut = ocr.isNutritionLabel(result);

    final groundingString = result.buildGroundingString(isMedication: isMed, isNutrition: isNut);

    // Inject to Gemini
    gemini.sendText(SystemTags.ocrCaptureSuccessful(groundingString));
    haptics.safePathConfirm();
  }
}
