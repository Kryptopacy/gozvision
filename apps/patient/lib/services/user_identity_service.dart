import 'package:copilot_core/copilot_core.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/app_config.dart';

/// The identity of the patient this copilot session serves.
///
/// One definition point for "who is the patient" (see CONTEXT.md — Patient
/// identity): a Supabase session — either a real patient account or the
/// seeded demo account used by the zero-UI flow (credentials from
/// [AppConfig.demoPatientEmail]). Every SOS alert, memory fact, and
/// telemetry event is written under [userId], satisfying RLS as a real
/// authenticated row.
class UserIdentityService extends ChangeNotifier implements CopilotIdentity {
  UserIdentityService() {
    Supabase.instance.client.auth.onAuthStateChange.listen((state) {
      final uid = state.session?.user.id;
      if (_uid != uid) {
        _uid = uid;
        notifyListeners();
      }
    });
  }

  String? _uid;

  /// True when a real authenticated session backs this identity.
  bool get isAuthenticated => _uid != null;

  /// The patient id that alerts, memory and telemetry belong to.
  @override
  String get userId => _uid ?? AppConfig.patientId;

  /// Resolves the current identity without needing the service instance —
  /// for request-scoped code outside the provider graph (e.g. the ADK
  /// bridge, which must stamp every backend call with the patient id).
  static String resolveCurrentUserId() =>
      Supabase.instance.client.auth.currentUser?.id ?? AppConfig.patientId;

  /// Zero-UI demo flow: sign in as the seeded demo patient when the app
  /// opens with no session. Harmless no-op when demo credentials are absent.
  Future<void> ensureSignedIn() async {
    final client = Supabase.instance.client;
    final existing = client.auth.currentUser;
    if (existing != null) {
      _uid = existing.id;
      notifyListeners();
      return;
    }
    final email = AppConfig.demoPatientEmail;
    final password = AppConfig.demoPatientPassword;
    if (email.isEmpty || password.isEmpty) return;
    try {
      final res = await client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      _uid = res.session?.user.id;
      debugPrint('UserIdentity: demo session established.');
      notifyListeners();
    } catch (e) {
      debugPrint('UserIdentity: demo sign-in failed: $e');
    }
  }
}
