/// Utility to cleanly format patient IDs into human clinical names
class PatientUtils {
  PatientUtils._();

  static String formatName(dynamic idOrName) {
    if (idOrName == null) return 'Patient';
    final str = idOrName.toString().trim();
    if (str.isEmpty) return 'Patient';

    final lower = str.toLowerCase();
    if (lower.contains('1cb317f9') || lower.contains('demo_patient_001') || lower.contains('demo-patient')) {
      return 'Maria Santos';
    }
    if (lower.contains('demo_patient_002') || lower.contains('chen')) {
      return 'Robert Chen';
    }
    if (lower.contains('demo_patient_003') || lower.contains('vance')) {
      return 'Eleanor Vance';
    }
    if (lower.contains('demo_patient_004') || lower.contains('pendelton')) {
      return 'Arthur Pendelton';
    }

    // If already looks like a real name
    if (!str.contains('-') && !str.contains('_') && str.contains(' ')) {
      return str;
    }

    // If UUID, return clean formatted patient tag
    if (str.length > 8 && str.contains('-')) {
      return 'Patient #${str.substring(0, 6).toUpperCase()}';
    }

    return 'Patient $str';
  }
}
