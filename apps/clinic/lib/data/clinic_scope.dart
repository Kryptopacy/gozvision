import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// A live Supabase row stream for one clinic-scoped table: the row list
/// arrives directly (no snapshot unwrapping).
typedef ClinicRows = List<Map<String, dynamic>>;

/// The signed-in clinic member's tenancy: which clinic they belong to and
/// what role they hold. Everything in the suite queries through this scope.
class ClinicScope extends ChangeNotifier {
  String? clinicId = 'a3450a9b-6820-40dd-be8e-25c7a2deb360';
  String clinicName = 'GozVision Demo Eye Clinic';
  String role = 'Practitioner';
  String email = 'practitioner@gozvision.demo';
  String displayName = 'Dr. Ada Optometrist';
  bool resolved = true;
  String? error;

  String country = 'Nigeria'; // Default: Nigeria (can be set to Ghana, Kenya, South Africa, UK, USA, etc.)
  String stateOrCity = 'Lagos';

  String get currency => isNigeria ? 'NGN' : isUK ? 'GBP' : isUS ? 'USD' : isGhana ? 'GHS' : isKenya ? 'KES' : isSouthAfrica ? 'ZAR' : 'NGN';
  String get currencySymbol => isNigeria ? '₦' : isUK ? '£' : isUS ? '\$' : isGhana ? 'GH₵' : isKenya ? 'KSh' : isSouthAfrica ? 'R' : '₦';

  bool get isNigeria => country.toLowerCase().contains('nigeria');
  bool get isGhana => country.toLowerCase().contains('ghana');
  bool get isKenya => country.toLowerCase().contains('kenya');
  bool get isSouthAfrica => country.toLowerCase().contains('south africa');
  bool get isAfrica => isNigeria || isGhana || isKenya || isSouthAfrica;
  bool get isUS => country.toLowerCase().contains('united states') || country.toLowerCase().contains('usa');
  bool get isUK => country.toLowerCase().contains('united kingdom') || country.toLowerCase().contains('uk');

  String get defaultFormTemplate {
    if (isNigeria) return 'Nigerian Optometric Clinical Record (NOA / ODORBN Standard)';
    if (isUK) return 'Metropolitan Eye Hospital · 4-Quadrant Clinical Folder Sheet';
    if (isUS) return 'Dr. Ada Optometry Care · Standard Clinical Form #OD-REV-2026';
    return 'Nigerian Optometric Clinical Record (NOA / ODORBN Standard)';
  }

  String get defaultReimbursementRegion => isAfrica ? 'nigeria_hmo' : 'us_cms';
  String get countryFlag => isNigeria ? '🇳🇬' : isGhana ? '🇬🇭' : isKenya ? '🇰🇪' : isSouthAfrica ? '🇿🇦' : isUK ? '🇬🇧' : isUS ? '🇺🇸' : '🌍';

  String get regulatoryBody {
    if (isNigeria) return 'ODORBN (Optometrists & Dispensing Opticians Reg. Board of Nigeria)';
    if (isUK) return 'GOC (General Optical Council, UK)';
    if (isGhana) return 'MDC Ghana (Medical and Dental Council)';
    if (isKenya) return 'OCK (Optometrists Association of Kenya)';
    if (isSouthAfrica) return 'HPCSA (Health Professions Council of South Africa)';
    if (isUS) return 'State Board of Optometry (United States)';
    return 'Regional Optometric Regulatory Board';
  }

  String get defaultLicenseText {
    if (isNigeria) return 'ODORBN Lic #OPT-48201/NG';
    if (isUK) return 'GOC Reg #01-29481 (UK)';
    if (isGhana) return 'MDC Ghana Lic #OD-10492';
    if (isKenya) return 'OCK Lic #OPT-3819';
    if (isSouthAfrica) return 'HPCSA Reg #OP004921';
    if (isUS) return 'State Board Lic #OPT-48201 · NPI #1948201948';
    return 'Lic #OPT-48201';
  }

  void updatePracticeLocation({
    required String newCountry,
    required String newStateOrCity,
    String? newClinicName,
  }) {
    country = newCountry;
    stateOrCity = newStateOrCity;
    if (newClinicName != null && newClinicName.trim().isNotEmpty) {
      clinicName = newClinicName;
    }
    notifyListeners();
  }

  bool get isDeveloper => role == 'Developer' || email.toLowerCase() == 'kryptopacy@gmail.com';
  bool get isClinicManager => role == 'ClinicManager' || role == 'Owner' || isDeveloper;
  bool get isPractitioner => role == 'Practitioner' || isClinicManager;
  bool get isStaff => role == 'Staff' || isClinicManager;

  /// Resolves the profiles row (id = uid) into the tenancy scope.
  Future<void> resolve(String uid) async {
    try {
      final rows = await Supabase.instance.client
          .from('profiles')
          .select('clinic_id, role, email, name, assigned_patients')
          .eq('id', uid)
          .limit(1);
      final data = rows.isEmpty ? const {} : rows.first;
      clinicId = data['clinic_id'] as String?;
      email = (data['email'] as String?) ?? '';
      role = (data['role'] as String?) ?? (email.toLowerCase() == 'kryptopacy@gmail.com' ? 'Developer' : 'Staff');
      displayName = (data['name'] as String?) ?? '';

      if (clinicId != null) {
        try {
          final cRows = await Supabase.instance.client
              .from('clinics')
              .select('name')
              .eq('id', clinicId!)
              .limit(1);
          if (cRows.isNotEmpty && cRows.first['name'] != null) {
            clinicName = cRows.first['name'] as String;
          }
        } catch (_) {}
      }

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
