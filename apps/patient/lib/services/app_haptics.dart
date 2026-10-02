import 'package:copilot_core/copilot_core.dart';

import 'haptic_service.dart';

/// Bridges the app's static haptics utility into the [CopilotHaptics]
/// contract the [SessionCoordinator] drives.
class AppHaptics implements CopilotHaptics {
  const AppHaptics();

  @override
  Future<void> tap() => HapticService.tap();

  @override
  Future<void> alert() => HapticService.alert();

  @override
  Future<void> hazardWarning() => HapticService.hazardWarning();

  @override
  Future<void> personDetected() => HapticService.personDetected();

  @override
  Future<void> navigationCue() => HapticService.navigationCue();

  @override
  Future<void> safePathConfirm() => HapticService.safePathConfirm();

  @override
  Future<void> environmentKnown() => HapticService.environmentKnown();

  @override
  Future<void> modeSwitch() => HapticService.modeSwitch();

  @override
  Future<void> connected() => HapticService.connected();
}
