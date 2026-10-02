import 'package:flutter/foundation.dart';
import 'package:copilot_core/copilot_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/app_config.dart';

/// Clinical Telemetry Service logs actionable medical and safety data
/// designed specifically for Optometrists (O&M, ADL tracking) and Caregivers.
///
/// Events land in the `clinical_events` table (Supabase) as
/// {kind, payload jsonb} rows — the caregiver dashboard and the Low Vision
/// Hub read them live.
class ClinicalTelemetryService extends ChangeNotifier
    implements CopilotTelemetry {
  ClinicalTelemetryService({SupabaseClient? client}) : _injectedClient = client;

  final SupabaseClient? _injectedClient;
  SupabaseClient get _client => _injectedClient ?? Supabase.instance.client;

  String get _patientId =>
      Supabase.instance.client.auth.currentUser?.id ?? AppConfig.patientId;

  /// Generic event insert — every metric funnels through here.
  Future<void> _log(String kind, Map<String, dynamic> payload) async {
    if (!AppConfig.isConfigured) return;
    try {
      await _client.from('clinical_events').insert({
        'patient_id': _patientId,
        'kind': kind,
        'payload': payload,
      });
    } catch (e) {
      debugPrint('Telemetry: Failed to log $kind: $e');
    }
  }

  // --- Optometrist Metrics (Functional Vision) ---

  /// Logs when the user rapidly turns away from high lighting (Photophobia / Glare marker).
  Future<void> logPhotophobiaEvent(double peakLux) => _log('glare_aversion', {
        'lux': peakLux,
        'severity': peakLux > 10000 ? 'High' : 'Medium',
        'note': 'Rapid camera movement detected in a high-lux environment.',
      });

  /// Logs the ambient light required to successfully read text (Contrast Sensitivity marker).
  @override
  Future<void> logOcrAssist(double ambientLux, int characterCount) =>
      _log('ocr_assist', {
        'ambientLux': ambientLux,
        'characterCount': characterCount,
      });

  /// Logs reading stamina (time spent in Reading mode).
  @override
  Future<void> logReadingStamina(Duration duration) async {
    if (duration.inSeconds < 10) return;
    return _log('reading_session', {
      'durationSeconds': duration.inSeconds,
    });
  }

  // --- Caregiver Metrics (Safety & Independence) ---

  /// Logs physical hazards detected by Gemini.
  @override
  Future<void> logHazardDetected(String pattern) async {
    if (pattern != 'hazard') return;
    return _log('hazard', {
      'severity': 'High',
      'note': 'Agent detected and triggered a hazard proximity warning.',
    });
  }

  /// Logs evidence of spatial disorientation (Wandering).
  @override
  Future<void> logSpatialDisorientation() => _log('wandering', {
        'severity': 'Medium',
        'note':
            'Repeated rapid mode-switching indicating potential spatial disorientation.',
      });

  /// Logs cognitive map accuracy (frequency of environment re-description requests).
  Future<void> logCognitiveMapAccuracy(bool requiredRedescription) =>
      _log('cognitive_mapping', {
        'requiredRedescription': requiredRedescription,
        'note': 'Tracks user spatial awareness and reliance on AI re-orientation.',
      });

  /// Logs emotional state proxy (session length without SOS triggers).
  Future<void> logEmotionalStateProxy(Duration sessionLength, int sosCount) =>
      _log('emotional_state_proxy', {
        'durationSeconds': sessionLength.inSeconds,
        'sosCount': sosCount,
        'estimatedState': sosCount == 0 ? 'Confident' : 'Anxious',
      });

  /// Logs detection of allergen keywords on food labels.
  Future<void> logAllergenDetection(String detectedAllergens) =>
      _log('allergen_detection', {
        'severity': 'High',
        'detectedAllergens': detectedAllergens,
        'note': 'Agent proactively identified critical allergens.',
      });

  /// Logs successful independent navigation session.
  Future<void> logNavigationIndependence(bool successfulSession) =>
      _log('navigation_independence', {
        'successfulSession': successfulSession,
      });
}
