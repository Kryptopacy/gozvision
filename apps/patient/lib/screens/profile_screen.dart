import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:copilot_core/copilot_core.dart';

import '../core/app_config.dart';
import '../core/theme.dart';
import '../services/app_haptics.dart';

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
class PatientProfileScreen extends StatelessWidget {
  const PatientProfileScreen({super.key});

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

          // 4. Prescribed Eye Drops & Device Fits
          _buildPrescriptionsAndFits(context),
          const SizedBox(height: 24),

          // 5. Accessible Preferences
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
            children: const [
              Icon(Icons.medication_outlined, color: Colors.tealAccent, size: 20),
              SizedBox(width: 8),
              Text(
                'Active Prescriptions & Drops',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildItemRow('Latanoprost 0.005%', '1 drop OU at bedtime (Glaucoma management)'),
          const Divider(color: Colors.white10, height: 16),
          _buildItemRow('Systane Complete PF', 'Preservative-free tears QID as needed for dry eye'),
        ],
      ),
    );
  }

  Widget _buildItemRow(String title, String desc) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.check_circle_outline, color: Colors.tealAccent, size: 16),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white, fontSize: 13)),
              Text(desc, style: const TextStyle(fontSize: 11, color: Colors.white60)),
            ],
          ),
        ),
      ],
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
}
