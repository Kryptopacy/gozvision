import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// The signed-in clinic member's tenancy: which clinic they belong to and
/// what role they hold. Everything in the suite queries through this scope.
class ClinicScope extends ChangeNotifier {
  String? clinicId;
  String role = '';
  String displayName = '';
  bool resolved = false;
  String? error;

  /// Resolves the user document (users/{uid}) into the tenancy scope.
  Future<void> resolve(String uid) async {
    try {
      final doc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final data = doc.data() ?? const {};
      clinicId = data['clinicId'] as String?;
      role = (data['role'] as String?) ?? 'Staff';
      displayName = (data['name'] as String?) ?? '';
      resolved = true;
    } catch (e) {
      error = e.toString();
      resolved = true;
    }
    notifyListeners();
  }

  /// Queries a clinic-scoped collection. Null clinicId → no query yet.
  Stream<QuerySnapshot<Map<String, dynamic>>>? stream(String collection) {
    final id = clinicId;
    if (id == null) return null;
    return FirebaseFirestore.instance
        .collection(collection)
        .where('clinicId', isEqualTo: id)
        .snapshots();
  }
}
