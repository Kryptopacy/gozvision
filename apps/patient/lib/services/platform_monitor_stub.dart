import 'package:flutter/foundation.dart';
import 'platform_monitor.dart';

class PlatformMonitorStub implements PlatformMonitor {
  @override
  void setupConnectivityMonitoring({
    required VoidCallback onOffline,
    required VoidCallback onOnline,
  }) {
    // No-op on mobile/native
  }

  @override
  void setupBatteryMonitoring({
    required Function(double level, bool charging) onLowBattery,
  }) {
    // No-op on mobile/native (can be implemented later via battery_plus)
  }

  @override
  void playTone(double frequency, double durationSeconds) {
    // No-op on mobile/native
  }

  @override
  void dispose() {
    // No-op
  }
}

PlatformMonitor getPlatformMonitor() => PlatformMonitorStub();
