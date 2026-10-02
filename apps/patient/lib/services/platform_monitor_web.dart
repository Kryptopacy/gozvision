import 'dart:async';
import 'dart:js_interop';
import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;
import 'platform_monitor.dart';

class PlatformMonitorWeb implements PlatformMonitor {
  Timer? _batteryCheckTimer;

  @override
  void setupConnectivityMonitoring({
    required VoidCallback onOffline,
    required VoidCallback onOnline,
  }) {
    web.window.addEventListener('offline', (web.Event event) {
      onOffline();
    }.toJS);

    web.window.addEventListener('online', (web.Event event) {
      onOnline();
    }.toJS);
  }

  @override
  void setupBatteryMonitoring({
    required Function(double level, bool charging) onLowBattery,
  }) {
    _batteryCheckTimer = Timer.periodic(const Duration(seconds: 60), (_) async {
      try {
        final navigator = web.window.navigator;
        // Access navigator.getBattery() via raw JS interop to be safe
        final batteryPromise = (navigator as dynamic).getBattery();
        if (batteryPromise == null) return;
        
        final battery = await (batteryPromise as Future);
        final level = (battery as dynamic).level as double; // 0.0 to 1.0
        final charging = (battery as dynamic).charging as bool;

        onLowBattery(level, charging);
      } catch (e) {
        debugPrint('PlatformMonitorWeb: Battery API error: $e');
        _batteryCheckTimer?.cancel();
      }
    });
  }

  @override
  void playTone(double frequency, double durationSeconds) {
    try {
      final ctx = web.AudioContext();
      final oscillator = ctx.createOscillator();
      final gain = ctx.createGain();

      oscillator.type = 'sine';
      oscillator.frequency.value = frequency.clamp(200.0, 800.0);

      // Gentle envelope: fade in over 10ms, sustain, fade out over 20% of duration
      gain.gain.setValueAtTime(0.001, ctx.currentTime);
      gain.gain.exponentialRampToValueAtTime(0.15, ctx.currentTime + 0.01);
      gain.gain.setValueAtTime(0.15, ctx.currentTime + durationSeconds * 0.8);
      gain.gain.exponentialRampToValueAtTime(0.001, ctx.currentTime + durationSeconds);

      oscillator.connect(gain);
      gain.connect(ctx.destination);
      oscillator.start();
      oscillator.stop(ctx.currentTime + durationSeconds);
    } catch (e) {
      // Chrome/modern browsers block audio if no user interaction occurred yet.
      // We catch this to prevent the "minified:OB" or similar crashes during late initialization.
      if (e.toString().contains('NotAllowedError')) {
        debugPrint('PlatformMonitorWeb: playTone blocked by auto-play policy.');
      } else {
        debugPrint('PlatformMonitorWeb: playTone error: $e');
      }
      _batteryCheckTimer?.cancel();
    }
  }

  @override
  void dispose() {
    _batteryCheckTimer?.cancel();
  }
}

PlatformMonitor getPlatformMonitor() => PlatformMonitorWeb();
