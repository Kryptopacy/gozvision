import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// A live Supabase row stream for one clinic-scoped table: the row list
/// arrives directly (no snapshot unwrapping).
typedef ClinicRows = List<Map<String, dynamic>>;

/// The signed-in clinic member's tenancy: which clinic they belong to and
/// what role they hold. Everything in the suite queries through this scope.
class ClinicScope extends ChangeNotifier {
  String? clinicId;
  String role = '';
  String displayName = '';
  bool resolved = false;
  String? error;

  /// Resolves the profiles row (id = uid) into the tenancy scope.
  Future<void> resolve(String uid) async {
    try {
      final rows = await Supabase.instance.client
          .from('profiles')
          .select('clinic_id, role, name, assigned_patients')
          .eq('id', uid)
          .limit(1);
      final data = rows.isEmpty ? const {} : rows.first;
      clinicId = data['clinic_id'] as String?;
      role = (data['role'] as String?) ?? 'Staff';
      displayName = (data['name'] as String?) ?? '';
      resolved = true;
    } catch (e) {
      error = e.toString();
      resolved = true;
    }
    notifyListeners();
  }

  /// Streams a clinic-scoped table. Null clinicId → no query yet.
  ///
  /// RLS scopes every row to the caller's clinic; the explicit
  /// `eq('clinic_id', ...)` keeps the filter visible at the call site.
  /// Tables whose primary key is not `id` (e.g. sos_alerts on
  /// ['patient_id']) pass a different [primaryKey].
  Stream<ClinicRows>? stream(
    String collection, {
    List<String> primaryKey = const ['id'],
  }) {
    final id = clinicId;
    if (id == null) return null;
    return Supabase.instance.client
        .from(collection)
        .stream(primaryKey: primaryKey)
        .eq('clinic_id', id);
  }
}
