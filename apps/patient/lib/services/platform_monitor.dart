import 'package:flutter/foundation.dart';
import 'package:copilot_core/copilot_core.dart';
import 'platform_monitor_stub.dart' if (dart.library.js_interop) 'platform_monitor_web.dart';

abstract class PlatformMonitor implements CopilotPlatformMonitor {
  factory PlatformMonitor() => getPlatformMonitor();

  @override
  void setupConnectivityMonitoring({
    required VoidCallback onOffline,
    required VoidCallback onOnline,
  });

  @override
  void setupBatteryMonitoring({
    required Function(double level, bool charging) onLowBattery,
  });

  /// Play a pitched tone (e.g. for light meter).
  @override
  void playTone(double frequency, double durationSeconds);

  @override
  void dispose();
}
