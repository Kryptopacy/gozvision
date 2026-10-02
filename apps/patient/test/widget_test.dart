import 'package:copilot_core/copilot_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patient_app/core/app_config.dart';
import 'package:patient_app/core/system_prompt.dart';

/// The tag contract connects the system prompt to the producers of context
/// pulses. These tests lock it: if a tag is renamed in [SystemTags], the
/// prompt must follow — otherwise the model is briefed about tags that never
/// arrive (this drifted once in GozAI: the prompt said "[LOW LIGHT]" while
/// the producer sent "[SYSTEM - LOW LIGHT DETECTED]").
void main() {
  group('Prompt ↔ producer tag contract', () {
    test('persona documents the low-light tag the coordinator sends', () {
      expect(
        GozAISystemPrompt.persona,
        contains('[${SystemTags.lowLightTag}]'),
      );
      expect(
        SystemTags.lowLight(),
        startsWith('[${SystemTags.lowLightTag}]'),
      );
    });

    test('persona documents the hardware capabilities tag', () {
      expect(
        GozAISystemPrompt.persona,
        contains('[${SystemTags.hardwareCapabilitiesTag}]'),
      );
      expect(
        SystemTags.hardwareStatus(micOn: true, cameraOn: true),
        startsWith('[${SystemTags.hardwareCapabilitiesTag}]'),
      );
    });

    test('persona documents the idle check-in tag', () {
      expect(
        GozAISystemPrompt.persona,
        contains('[${SystemTags.idleCheckInTag}]'),
      );
      expect(
        SystemTags.idleCheckIn(),
        startsWith('[${SystemTags.idleCheckInTag}]'),
      );
    });

    test('persona documents memory, launch, and medication tags', () {
      expect(
        GozAISystemPrompt.persona,
        contains('[${SystemTags.userMemoryTag}]'),
      );
      expect(
        GozAISystemPrompt.persona,
        contains('[${SystemTags.autoLaunchTag}]'),
      );
      expect(
        GozAISystemPrompt.persona,
        contains('[${SystemTags.onboardingTag}]'),
      );
      expect(
        GozAISystemPrompt.persona,
        contains('[${SystemTags.medicationLabelTag}]'),
      );
      // [NUTRITION LABEL] is documented in the reading-mode addendum only —
      // it is asserted there (see below), not in the persona.
    });

    test('reading mode addendum documents the OCR label tags', () {
      expect(
        GozAISystemPrompt.readingModeAddendum,
        contains('[${SystemTags.medicationLabelTag}]'),
      );
      expect(
        GozAISystemPrompt.readingModeAddendum,
        contains('[${SystemTags.nutritionLabelTag}]'),
      );
    });

    test('launch context pulses carry the tags the prompt documents', () {
      expect(
        SystemTags.onboarding(),
        startsWith('[${SystemTags.onboardingTag}]'),
      );
      expect(
        SystemTags.welcomeBack('Maria'),
        startsWith('[${SystemTags.autoLaunchTag}]'),
      );
    });

    test('the prompt builder composes persona plus the mode addendum', () {
      final reading = GozAISystemPrompt.build(GozAIMode.reading);
      expect(reading, contains(GozAISystemPrompt.persona));
      expect(reading, contains('READING mode'));
    });
  });

  group('Session types', () {
    test('the copilot has the four interaction modes', () {
      expect(
        GozAIMode.values.map((m) => m.name),
        unorderedEquals(['scene', 'reading', 'uiNav', 'lightMeter']),
      );
    });

    test('a fresh session service starts disconnected in scene mode', () {
      final service = GeminiLiveService(
        config: SessionConfig(
          geminiLiveWsUrl: 'wss://example.invalid',
          geminiModel: 'models/test-model',
          demoPatientId: 'demo_patient_001',
          adkBackendUrl: 'http://localhost:8080',
        ),
        identity: _StaticIdentity('demo_patient_001'),
        buildSystemPrompt: GozAISystemPrompt.build,
      );
      expect(service.connectionState, GeminiConnectionState.disconnected);
      expect(service.currentMode, GozAIMode.scene);
      expect(service.isConnected, isFalse);
    });
  });

  group('AppConfig', () {
    test('patient identity has a single definition point', () {
      expect(AppConfig.patientId, isNotEmpty);
    });
  });
}

class _StaticIdentity implements CopilotIdentity {
  @override
  final String userId;
  _StaticIdentity(this.userId);
}
