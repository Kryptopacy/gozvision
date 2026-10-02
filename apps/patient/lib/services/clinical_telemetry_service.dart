import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../core/app_config.dart';
import 'package:copilot_core/copilot_core.dart';

/// Clinical Telemetry Service logs actionable medical and safety data
/// designed specifically for Optometrists (O&M, ADL tracking) and Caregivers.
class ClinicalTelemetryService extends ChangeNotifier implements CopilotTelemetry {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // The patient ID for demo purposes
  final String patientId = AppConfig.patientId;

  // --- Optometrist Metrics (Functional Vision) ---
  
  /// Logs when the user rapidly turns away from high lighting (Photophobia / Glare marker).
  Future<void> logPhotophobiaEvent(double peakLux) async {
    if (!AppConfig.isConfigured) return;
    try {
      await _firestore.collection('patients').doc(patientId).collection('clinical_events').add({
        'type': 'glare_aversion',
        'timestamp': FieldValue.serverTimestamp(),
        'lux': peakLux,
        'severity': peakLux > 10000 ? 'High' : 'Medium',
        'note': 'Rapid camera movement detected in a high-lux environment.',
      });
    } catch (e) {
      debugPrint('Telemetry: Failed to log photophobia event: $e');
    }
  }

  /// Logs the ambient light required to successfully read text (Contrast Sensitivity marker).
  @override
  Future<void> logOcrAssist(double ambientLux, int characterCount) async {
    if (!AppConfig.isConfigured) return;
    try {
      await _firestore.collection('patients').doc(patientId).collection('functional_metrics').add({
        'type': 'ocr_assist',
        'timestamp': FieldValue.serverTimestamp(),
        'ambientLux': ambientLux,
        'characterCount': characterCount,
      });
    } catch (e) {
      debugPrint('Telemetry: Failed to log OCR assist: $e');
    }
  }

  /// Logs reading stamina (time spent in Reading mode).
  @override
  Future<void> logReadingStamina(Duration duration) async {
    if (!AppConfig.isConfigured || duration.inSeconds < 10) return;
    try {
      await _firestore.collection('patients').doc(patientId).collection('functional_metrics').add({
        'type': 'reading_session',
        'timestamp': FieldValue.serverTimestamp(),
        'durationSeconds': duration.inSeconds,
      });
    } catch (e) {
      debugPrint('Telemetry: Failed to log reading stamina: $e');
    }
  }

  // --- Caregiver Metrics (Safety & Independence) ---

  /// Logs physical hazards detected by Gemini.
  @override
  Future<void> logHazardDetected(String pattern) async {
    if (!AppConfig.isConfigured || pattern != 'hazard') return;
    try {
      await _firestore.collection('patients').doc(patientId).collection('clinical_events').add({
        'type': 'hazard',
        'timestamp': FieldValue.serverTimestamp(),
        'severity': 'High',
        'note': 'Agent detected and triggered a hazard proximity warning.',
      });
    } catch (e) {
      debugPrint('Telemetry: Failed to log hazard: $e');
    }
  }

  /// Logs evidence of spatial disorientation (Wandering).
  @override
  Future<void> logSpatialDisorientation() async {
    if (!AppConfig.isConfigured) return;
    try {
      await _firestore.collection('patients').doc(patientId).collection('clinical_events').add({
        'type': 'wandering',
        'timestamp': FieldValue.serverTimestamp(),
        'severity': 'Medium',
        'note': 'Repeated rapid mode-switching indicating potential spatial disorientation.',
      });
    } catch (e) {
      debugPrint('Telemetry: Failed to log wandering: $e');
    }
  }

  /// Logs cognitive map accuracy (tracked via frequency of environment re-description requests)
  Future<void> logCognitiveMapAccuracy(bool requiredRedescription) async {
    if (!AppConfig.isConfigured) return;
    try {
      await _firestore.collection('patients').doc(patientId).collection('functional_metrics').add({
        'type': 'cognitive_mapping',
        'timestamp': FieldValue.serverTimestamp(),
        'requiredRedescription': requiredRedescription,
        'note': 'Tracks user spatial awareness and reliance on AI re-orientation.',
      });
    } catch (e) {
      debugPrint('Telemetry: Failed to log cognitive mapping: $e');
    }
  }

  /// Logs emotional state proxy (session length without SOS triggers)
  Future<void> logEmotionalStateProxy(Duration sessionLength, int sosCount) async {
    if (!AppConfig.isConfigured) return;
    try {
      await _firestore.collection('patients').doc(patientId).collection('functional_metrics').add({
        'type': 'emotional_state_proxy',
        'timestamp': FieldValue.serverTimestamp(),
        'durationSeconds': sessionLength.inSeconds,
        'sosCount': sosCount,
        'estimatedState': sosCount == 0 ? 'Confident' : 'Anxious',
      });
    } catch (e) {
      debugPrint('Telemetry: Failed to log emotional state: $e');
    }
  }

  /// Logs detection of allergen keywords on food labels
  Future<void> logAllergenDetection(String detectedAllergens) async {
    if (!AppConfig.isConfigured) return;
    try {
      await _firestore.collection('patients').doc(patientId).collection('clinical_events').add({
        'type': 'allergen_detection',
        'timestamp': FieldValue.serverTimestamp(),
        'severity': 'High',
        'detectedAllergens': detectedAllergens,
        'note': 'Agent proactively identified critical allergens.',
      });
    } catch (e) {
      debugPrint('Telemetry: Failed to log allergen detection: $e');
    }
  }

  /// Logs successful independent navigation session
  Future<void> logNavigationIndependence(bool successfulSession) async {
    if (!AppConfig.isConfigured) return;
    try {
      await _firestore.collection('patients').doc(patientId).collection('functional_metrics').add({
        'type': 'navigation_independence',
        'timestamp': FieldValue.serverTimestamp(),
        'successfulSession': successfulSession,
      });
    } catch (e) {
      debugPrint('Telemetry: Failed to log navigation independence: $e');
    }
  }
}
