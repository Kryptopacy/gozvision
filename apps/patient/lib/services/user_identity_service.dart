import 'package:copilot_core/copilot_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../core/app_config.dart';

/// The identity of the patient this copilot session serves.
///
/// One definition point for "who is the patient" (see CONTEXT.md — Patient):
/// - When a patient account is logged in on this device, that account's uid
///   is the identity — SOS alerts, companion memory, and telemetry are all
///   written under it.
/// - Otherwise (the zero-UI flow, where the copilot starts with no login
///   wall) the identity falls back to [AppConfig.patientId] so the demo
///   wiring on the caregiver dashboard keeps working unchanged.
class UserIdentityService extends ChangeNotifier implements CopilotIdentity {
  UserIdentityService() {
    FirebaseAuth.instance.authStateChanges().listen((user) {
      if (_uid != user?.uid) {
        _uid = user?.uid;
        notifyListeners();
      }
    });
  }

  String? _uid;

  /// True when a real authenticated account backs this identity.
  bool get isAuthenticated => _uid != null;

  /// The patient id that alerts, memory and telemetry belong to.
  @override
  String get userId => _uid ?? AppConfig.patientId;

  /// Resolves the current identity without needing the service instance —
  /// for request-scoped code outside the provider graph (e.g. the ADK
  /// bridge, which must stamp every backend call with the patient id).
  static String resolveCurrentUserId() =>
      FirebaseAuth.instance.currentUser?.uid ?? AppConfig.patientId;
}
