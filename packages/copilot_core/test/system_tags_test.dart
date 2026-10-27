import 'package:flutter_test/flutter_test.dart';
import 'package:copilot_core/copilot_core.dart';

void main() {
  group('SystemTags (the context-pulse contract)', () {
    test('every pulse starts with its canonical tag', () {
      expect(SystemTags.lowLight(), startsWith('[${SystemTags.lowLightTag}]'));
      expect(SystemTags.idleCheckIn(),
          startsWith('[${SystemTags.idleCheckInTag}]'));
      expect(SystemTags.connectivityLost(),
          startsWith('[${SystemTags.connectivityLostTag}]'));
      expect(SystemTags.connectivityRestored(),
          startsWith('[${SystemTags.connectivityRestoredTag}]'));
      expect(SystemTags.lowBattery(15),
          startsWith('[${SystemTags.lowBatteryTag}]'));
      expect(
          SystemTags.onboarding(), startsWith('[${SystemTags.onboardingTag}]'));
      expect(SystemTags.welcomeBack('Maria'),
          startsWith('[${SystemTags.autoLaunchTag}]'));
    });

    test('hardware pulses report the true state', () {
      final on = SystemTags.hardwareStatus(micOn: true, cameraOn: false);
      expect(on, contains('- Microphone: ON'));
      expect(on, contains('- Camera: OFF/FAILED'));
      expect(SystemTags.micToggled(false), contains('OFF'));
    });

    test('tags are stable, non-empty identifiers', () {
      for (final tag in [
        SystemTags.lowLightTag,
        SystemTags.hardwareCapabilitiesTag,
        SystemTags.idleCheckInTag,
        SystemTags.onboardingTag,
      ]) {
        expect(tag, isNotEmpty);
      }
    });
  });

  group('SessionConfig', () {
    test('carries the identity and backend addressing the loop needs', () {
      final config = SessionConfig(
        resolveGeminiLiveWsUrl: () async => 'wss://example.invalid',
        geminiModel: 'models/test-model',
        demoPatientId: 'demo_patient_001',
        adkBackendUrl: 'http://localhost:8080',
      );
      expect(config.audioInputSampleRate, 16000);
      expect(config.adkAgentName, 'gozvision_agent');
    });
  });
}
