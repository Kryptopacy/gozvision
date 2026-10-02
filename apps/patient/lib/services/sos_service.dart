import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:copilot_core/copilot_core.dart';

/// SOS Caregiver Alert Service.
///
/// When Gemini detects a crisis (the user uses distress words or requests help),
/// it calls the `sendSosAlert` tool. This service:
/// 1. Writes a real-time alert document to Firestore (visible on CaregiverDashboard)
/// 2. Fallback: opens the phone dialer with the caregiver's saved number
class SosService implements CopilotAlertSink {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _alertsCollection = 'sos_alerts';
  static const String _prefsCollection = 'user_preferences';

  /// Sends an SOS alert for [userId] with the given [message] and [severity].
  ///
  /// [severity] is either "mild" (user is confused/lost) or "critical" (danger).
  @override
  Future<void> sendAlert({
    required String userId,
    required String message,
    required String severity,
    required String target,
  }) async {
    try {
      final alertData = {
        'userId': userId,
        'message': message,
        'severity': severity,
        'target': target,
        'timestamp': FieldValue.serverTimestamp(),
        'resolved': false,
      };

      // Write to Firestore — triggers real-time listener on CaregiverDashboard
      await _firestore
          .collection(_alertsCollection)
          .doc(userId)
          .set(alertData, SetOptions(merge: false));

      debugPrint('SosService: Alert written to Firestore for user $userId');

      // For critical alerts, also try to open the phone dialer as a hard fallback
      if (severity == 'critical') {
        await _dialCargiver(userId);
      }
    } catch (e) {
      debugPrint('SosService: Failed to send alert: $e');
    }
  }

  /// Resolves (clears) the outstanding SOS alert for [userId].
  Future<void> resolveAlert({required String userId}) async {
    try {
      await _firestore
          .collection(_alertsCollection)
          .doc(userId)
          .update({'resolved': true});
    } catch (e) {
      debugPrint('SosService: Failed to resolve alert: $e');
    }
  }

  /// Returns a real-time stream of the alert document for [userId].
  /// The CaregiverDashboard subscribes to this to show live alerts.
  Stream<DocumentSnapshot<Map<String, dynamic>>> alertStream(String userId) {
    return _firestore
        .collection(_alertsCollection)
        .doc(userId)
        .snapshots();
  }

  /// Attempts to open the phone app dialer with the caregiver's saved number.
  Future<void> _dialCargiver(String userId) async {
    try {
      final prefs = await _firestore
          .collection(_prefsCollection)
          .doc(userId)
          .get();
      final caregiverPhone = prefs.data()?['caregiverPhone'] as String?;
      if (caregiverPhone != null && caregiverPhone.isNotEmpty) {
        final uri = Uri(scheme: 'tel', path: caregiverPhone);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri);
          debugPrint('SosService: Dialing caregiver at $caregiverPhone');
        }
      }
    } catch (e) {
      debugPrint('SosService: Dialer fallback failed: $e');
    }
  }
}
