import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

void webTactileClick({
  double frequency = 200.0,
  int durationMs = 20,
}) {
  try {
    // 1. Trigger iOS silent switch haptic hack
    final label = web.document.getElementById('haptic-label');
    if (label != null) {
      (label as web.HTMLElement).click();
    }
  } catch (e) {
    debugPrint('HapticService: iOS Web switch click failed: $e');
  }

  try {
    // 2. Play audible fallback click
    final ctx = web.AudioContext();
    final oscillator = ctx.createOscillator();
    final gainNode = ctx.createGain();

    oscillator.type = 'sine';
    oscillator.frequency.value = frequency;

    // Fast attack, immediate decay — sounds + feels like a tap
    gainNode.gain.setValueAtTime(0.001, ctx.currentTime);
    gainNode.gain.exponentialRampToValueAtTime(0.5, ctx.currentTime + 0.005);
    gainNode.gain.exponentialRampToValueAtTime(
      0.001,
      ctx.currentTime + durationMs / 1000.0,
    );

    oscillator.connect(gainNode);
    gainNode.connect(ctx.destination);
    oscillator.start();
    oscillator.stop(ctx.currentTime + durationMs / 1000.0);
  } catch (e) {
    debugPrint('HapticService: Web Audio fallback failed: $e');
  }
}
