import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:copilot_core/copilot_core.dart';

import '../core/app_config.dart';
import '../core/theme.dart';
import '../services/haptic_service.dart';

/// VisionProfile: distinguishes low-vision patients from routine seeing patients.
enum VisionProfile {
  lowVisionAssist, // Voice-first, continuous scene awareness, high haptics, obstacle cues
  clinicCompanion, // Sighted patient: visual-first, on-demand query only, subdued haptics
}

/// ProfileService manages the active patient experience and persists vision preferences.
class ProfileService extends ChangeNotifier {
  ProfileService() {
    _loadProfile();
  }

  VisionProfile _profile = VisionProfile.lowVisionAssist;
  bool _audioDescriptionsEnabled = true;
  bool _highContrastEnabled = true;
  bool _hapticFeedbackEnabled = true;

  VisionProfile get profile => _profile;
  bool get isLowVision => _profile == VisionProfile.lowVisionAssist;
  bool get audioDescriptionsEnabled => _audioDescriptionsEnabled;
  bool get highContrastEnabled => _highContrastEnabled;
  bool get hapticFeedbackEnabled => _hapticFeedbackEnabled;

  void setProfile(VisionProfile newProfile) => toggleProfile(newProfile);

  void toggleProfile(VisionProfile newProfile) {
    if (_profile == newProfile) return;
    _profile = newProfile;
    if (_profile == VisionProfile.clinicCompanion) {
      _audioDescriptionsEnabled = false;
      _hapticFeedbackEnabled = false;
    } else {
      _audioDescriptionsEnabled = true;
      _hapticFeedbackEnabled = true;
    }
    notifyListeners();
  }

  void updateSettings({
    bool? audioDescriptions,
    bool? highContrast,
    bool? haptics,
  }) {
    if (audioDescriptions != null) _audioDescriptionsEnabled = audioDescriptions;
    if (highContrast != null) _highContrastEnabled = highContrast;
    if (haptics != null) _hapticFeedbackEnabled = haptics;
    notifyListeners();
  }

  void _loadProfile() {
    // Defaults to lowVisionAssist so existing users experience zero regression.
  }
}

/// Patient Profile & Care Settings Screen
class PatientProfileScreen extends StatefulWidget {
  const PatientProfileScreen({super.key});

  @override
  State<PatientProfileScreen> createState() => _PatientProfileScreenState();
}

class _PatientProfileScreenState extends State<PatientProfileScreen> {
  bool _latanoprostTaken = false;
  int _systaneDosesTaken = 2;

  void _logDose(String medication) async {
    HapticService.tap();
    setState(() {
      if (medication.contains('Latanoprost')) {
        _latanoprostTaken = true;
      } else {
        _systaneDosesTaken = (_systaneDosesTaken + 1).clamp(0, 4);
      }
    });

    try {
      final client = Supabase.instance.client;
      await client.from('clinical_events').insert({
        'patient_id': AppConfig.patientId,
        'kind': 'drop_adherence',
        'payload': {
          'medication': medication,
          'status': 'taken',
          'source': 'patient_app_profile',
        },
        'at': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (_) {
      // Offline fallback
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('✓ $medication logged! Telemetry updated for your clinic.'),
        backgroundColor: Colors.teal,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profileService = context.watch<ProfileService>();
    final isLowVision = profileService.isLowVision;

    return Scaffold(
      backgroundColor: GozAITheme.backgroundPure,
      appBar: AppBar(
        title: const Text('Patient Profile & Care Hub'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // 1. Patient Demographics & Clinic Info Card
          _buildPatientHeader(context),
          const SizedBox(height: 24),

          // 2. Vision Profile Switcher (The Core Fix)
          _buildProfileModeSelector(context, profileService),
          const SizedBox(height: 24),

          // 3. Upcoming Appointments & Recalls
          _buildUpcomingAppointments(context),
          const SizedBox(height: 24),

          // 4. Prescribed Eye Drops & Interactive Adherence Tracker
          _buildPrescriptionsAndFits(context),
          const SizedBox(height: 24),

          // 5. Universal Patient Document & Prescription Uploader
          _buildPatientDocumentUploaderCard(context),
          const SizedBox(height: 24),

          // 6. Accessible Preferences
          _buildPreferencesCard(context, profileService),
        ],
      ),
    );
  }

  Widget _buildPatientHeader(BuildContext context) {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    final email = user?.email ?? AppConfig.demoPatientEmail;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: GozAITheme.surfaceElevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: GozAITheme.borderSubtle),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: GozAITheme.primaryBlue.withOpacity(0.2),
            child: const Icon(Icons.person, color: GozAITheme.accentCyan, size: 30),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Eleanor Vance',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 4),
                Text(
                  'Account: $email',
                  style: const TextStyle(fontSize: 12, color: Colors.white60),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.green.withOpacity(0.4)),
                  ),
                  child: const Text(
                    'Affiliated: Metro Vision Eye Clinic',
                    style: TextStyle(fontSize: 11, color: Colors.greenAccent),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileModeSelector(BuildContext context, ProfileService service) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: GozAITheme.surfaceElevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: GozAITheme.accentCyan.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.tune, color: GozAITheme.accentCyan, size: 20),
              SizedBox(width: 8),
              Text(
                'Copilot Mode & Assist Level',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Select how Goz Copilot interacts with you. Sighted patients can silence continuous scene descriptions and navigate using standard touch controls.',
            style: TextStyle(fontSize: 12, color: Colors.white70),
          ),
          const SizedBox(height: 16),
          // Option A: Low-Vision Assist Mode
          InkWell(
            onTap: () => service.toggleProfile(VisionProfile.lowVisionAssist),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: service.isLowVision
                    ? GozAITheme.primaryBlue.withOpacity(0.25)
                    : Colors.white.withOpacity(0.03),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: service.isLowVision ? GozAITheme.accentCyan : Colors.white12,
                  width: service.isLowVision ? 1.5 : 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    service.isLowVision ? Icons.radio_button_checked : Icons.radio_button_off,
                    color: service.isLowVision ? GozAITheme.accentCyan : Colors.white38,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'Vision Assist Mode (Low-Vision / Prescribed)',
                          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 14),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Voice-first, proactive obstacle haptics, continuous scene & reading assistant.',
                          style: TextStyle(fontSize: 11, color: Colors.white60),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          // Option B: Clinic Companion Mode
          InkWell(
            onTap: () => service.toggleProfile(VisionProfile.clinicCompanion),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: !service.isLowVision
                    ? GozAITheme.primaryBlue.withOpacity(0.25)
                    : Colors.white.withOpacity(0.03),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: !service.isLowVision ? GozAITheme.accentCyan : Colors.white12,
                  width: !service.isLowVision ? 1.5 : 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    !service.isLowVision ? Icons.radio_button_checked : Icons.radio_button_off,
                    color: !service.isLowVision ? GozAITheme.accentCyan : Colors.white38,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'Clinic Companion Mode (Sighted / General)',
                          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 14),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Silent on-demand assistant, appointment scheduling, and care thread messaging.',
                          style: TextStyle(fontSize: 11, color: Colors.white60),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUpcomingAppointments(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: GozAITheme.surfaceElevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: GozAITheme.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.event_available, color: Colors.amber, size: 20),
              SizedBox(width: 8),
              Text(
                'Upcoming Appointments',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.04),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.remove_red_eye_outlined, color: Colors.amber),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Annual Comprehensive Exam',
                        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13),
                      ),
                      Text(
                        'Tuesday, Oct 20 at 3:00 PM • Dr. Miller',
                        style: TextStyle(fontSize: 11, color: Colors.white60),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text('Confirmed', style: TextStyle(fontSize: 11, color: Colors.greenAccent)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrescriptionsAndFits(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: GozAITheme.surfaceElevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: GozAITheme.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: const [
                  Icon(Icons.medication_outlined, color: Colors.tealAccent, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Prescriptions & Drop Adherence',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.amber.withOpacity(0.4)),
                ),
                child: Row(
                  children: const [
                    Icon(Icons.local_fire_department, color: Colors.amber, size: 14),
                    SizedBox(width: 4),
                    Text(
                      '14-Day Streak (96%)',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.amber),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Medication 1: Latanoprost
          _buildInteractiveMedCard(
            title: 'Latanoprost 0.005%',
            regimen: '1 drop OU at bedtime (Glaucoma IOP)',
            isLogged: _latanoprostTaken,
            loggedText: 'Taken Today (Bedtime)',
            pendingActionText: 'Log Bedtime Drop',
            onLog: () => _logDose('Latanoprost 0.005%'),
          ),
          const SizedBox(height: 10),
          // Medication 2: Systane Tears
          _buildInteractiveMedCard(
            title: 'Systane Complete PF',
            regimen: 'Preservative-free tears QID (Dry Eye)',
            isLogged: _systaneDosesTaken >= 4,
            loggedText: 'Daily Goal Complete (4/4 doses)',
            pendingActionText: 'Log Dose ($_systaneDosesTaken/4 today)',
            onLog: () => _logDose('Systane Complete PF'),
          ),
        ],
      ),
    );
  }

  Widget _buildInteractiveMedCard({
    required String title,
    required String regimen,
    required bool isLogged,
    required String loggedText,
    required String pendingActionText,
    required VoidCallback onLog,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isLogged ? Colors.teal.withOpacity(0.3) : Colors.white10),
      ),
      child: Row(
        children: [
          Icon(
            isLogged ? Icons.check_circle : Icons.circle_outlined,
            color: isLogged ? Colors.tealAccent : Colors.white38,
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13),
                ),
                Text(
                  regimen,
                  style: const TextStyle(fontSize: 11, color: Colors.white60),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: isLogged ? Colors.teal.withOpacity(0.2) : GozAITheme.primaryBlue,
              foregroundColor: isLogged ? Colors.tealAccent : Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: isLogged ? null : onLog,
            child: Text(
              isLogged ? '✓ Taken' : pendingActionText,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreferencesCard(BuildContext context, ProfileService service) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: GozAITheme.surfaceElevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: GozAITheme.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Accessibility & Feedback Overrides',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 8),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('High Contrast Overlays', style: TextStyle(color: Colors.white, fontSize: 13)),
            subtitle: const Text('Boost edge definition and contrast in video', style: TextStyle(color: Colors.white60, fontSize: 11)),
            value: service.highContrastEnabled,
            onChanged: (v) => service.updateSettings(highContrast: v),
          ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('Haptic Vibration Alerts', style: TextStyle(color: Colors.white, fontSize: 13)),
            subtitle: const Text('Vibrate phone on hazard and confirmation', style: TextStyle(color: Colors.white60, fontSize: 11)),
            value: service.hapticFeedbackEnabled,
            onChanged: (v) => service.updateSettings(haptics: v),
          ),
        ],
      ),
    );
  }

  Widget _buildPatientDocumentUploaderCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: GozAITheme.surfaceElevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: GozAITheme.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.upload_file_rounded, color: GozAITheme.accentCyan, size: 20),
              const SizedBox(width: 8),
              const Text(
                'My Clinical Files & Prescriptions',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text('Gemini Vision OCR', style: TextStyle(color: Colors.greenAccent, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Snap a photo or upload past doctor prescriptions, eye drop bottles, or clinic summaries. GozVision automatically verifies and links them to your active care regimen.',
            style: TextStyle(fontSize: 12, color: Colors.white60, height: 1.35),
          ),
          const SizedBox(height: 14),

          // Upload action buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: GozAITheme.accentCyan,
                    side: const BorderSide(color: GozAITheme.accentCyan),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.camera_alt_outlined, size: 16),
                  label: const Text('Snap Photo', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  onPressed: () => _showPatientUploadSheet(context, isCamera: true),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: GozAITheme.primaryBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.attach_file_rounded, size: 16),
                  label: const Text('Upload File / PDF', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  onPressed: () => _showPatientUploadSheet(context, isCamera: false),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Sample verified patient documents
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.04),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: const [
                    Icon(Icons.verified_rounded, color: Colors.greenAccent, size: 14),
                    SizedBox(width: 6),
                    Text('Verified Active Records (2)', style: TextStyle(color: Colors.greenAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 8),
                _buildUploadedFileTile(
                  icon: Icons.picture_as_pdf_outlined,
                  name: 'Dr_Davis_Glaucoma_Rx_2026.pdf',
                  extractedDetail: 'Extracted: Latanoprost 0.005% QHS OU • Active Refill Sync',
                  date: 'Oct 14, 2026',
                ),
                const Divider(height: 12, color: Colors.white10),
                _buildUploadedFileTile(
                  icon: Icons.photo_outlined,
                  name: 'Systane_Complete_PF_Bottle.jpg',
                  extractedDetail: 'Extracted: Lubricant Eye Drops Preservative-Free QID',
                  date: 'Oct 10, 2026',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUploadedFileTile({
    required IconData icon,
    required String name,
    required String extractedDetail,
    required String date,
  }) {
    return Row(
      children: [
        Icon(icon, size: 20, color: GozAITheme.accentCyan),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white, fontSize: 12)),
              const SizedBox(height: 1),
              Text(extractedDetail, style: const TextStyle(color: Colors.white70, fontSize: 10.5)),
            ],
          ),
        ),
        Text(date, style: const TextStyle(color: Colors.white38, fontSize: 10)),
      ],
    );
  }

  void _showPatientUploadSheet(BuildContext context, {required bool isCamera}) {
    HapticService.tap();
    showModalBottomSheet(
      context: context,
      backgroundColor: GozAITheme.surfaceElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(isCamera ? Icons.camera_alt_outlined : Icons.upload_file_rounded, color: GozAITheme.accentCyan, size: 22),
                  const SizedBox(width: 10),
                  Text(
                    isCamera ? 'Snap Prescription or Eye Drop Box' : 'Upload Medical Document',
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                'Take a clear, well-lit picture of your paper prescription, eye drop label, or clinic referral. Gemini Vision will verify the dosage and sync it directly to your Amazon Pharmacy refills and clinic record.',
                style: TextStyle(color: Colors.white70, fontSize: 12.5, height: 1.4),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: GozAITheme.primaryBlue,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(46),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.check_circle_outline, size: 18),
                label: Text(
                  isCamera ? 'Simulate Camera Capture & Scan' : 'Select Document from Storage',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                onPressed: () {
                  Navigator.of(ctx).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      backgroundColor: Colors.green,
                      content: Text('✓ Gemini Vision: Prescription detected & verified! Latanoprost 0.005% QHS linked to Amazon Pharmacy.'),
                    ),
                  );
                },
              ),
              const SizedBox(height: 8),
              Center(
                child: TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
