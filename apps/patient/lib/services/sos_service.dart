import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:copilot_core/copilot_core.dart';

/// SOS Caregiver Alert Service.
///
/// When Gemini detects a crisis (the user uses distress words or requests
/// help), it calls the `sendSosAlert` intent. This service:
/// 1. Upserts a real-time alert row in the `sos_alerts` table (visible on
///    the CaregiverDashboard through its live stream)
/// 2. Fallback: opens the phone dialer with the linked caregiver's number
///    (profiles.caregiver_phone for caregivers whose assigned_patients
///    include this patient).
class SosService implements CopilotAlertSink {
  SosService({SupabaseClient? client}) : _injectedClient = client;

  // Lazily resolved so construction stays offline-safe.
  final SupabaseClient? _injectedClient;
  SupabaseClient get _client => _injectedClient ?? Supabase.instance.client;

  /// Sends an SOS alert for [userId] with the given [message] and [severity].
  ///
  /// [severity] is "mild" (user is confused/lost), "critical" (danger) or
  /// "info" (hardware intentionally disabled via voice).
  @override
  Future<void> sendAlert({
    required String userId,
    required String message,
    required String severity,
    required String target,
  }) async {
    try {
      // One current alert per patient (unique patient_id — upsert keeps the
      // GozAI document contract on Postgres).
      await _client.from('sos_alerts').upsert({
        'patient_id': userId,
        'type': 'sos',
        'note': message,
        'severity': severity,
        'target': target,
        'user_id': userId,
        'resolved': false,
        'alert_status': 'unacknowledged',
        'source': 'gemini_live_agent',
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });

      debugPrint('SosService: Alert written to sos_alerts for user $userId');

      // For critical alerts, also try to open the phone dialer as a hard fallback
      if (severity == 'critical') {
        await _dialCaregiver(userId);
      }
    } catch (e) {
      debugPrint('SosService: Failed to send alert: $e');
    }
  }

  /// Resolves (clears) the outstanding SOS alert for [userId].
  Future<void> resolveAlert({required String userId}) async {
    try {
      await _client
          .from('sos_alerts')
          .update({'resolved': true}).eq('patient_id', userId);
    } catch (e) {
      debugPrint('SosService: Failed to resolve alert: $e');
    }
  }

  /// Returns a real-time stream of the alert rows for [userId].
  /// The CaregiverDashboard subscribes to this to show live alerts.
  Stream<List<Map<String, dynamic>>> alertStream(String userId) {
    return _client
        .from('sos_alerts')
        .stream(primaryKey: ['patient_id']).eq('patient_id', userId);
  }

  /// Attempts to open the phone app dialer with the linked caregiver's number.
  Future<void> _dialCaregiver(String userId) async {
    try {
      final rows = await _client
          .from('profiles')
          .select('caregiver_phone')
          .contains('assigned_patients', [userId])
          .limit(1);
      final caregiverPhone = rows.isNotEmpty
          ? rows.first['caregiver_phone'] as String?
          : null;
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
