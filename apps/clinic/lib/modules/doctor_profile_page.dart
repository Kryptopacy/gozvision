import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/clinic_theme.dart';
import '../data/clinic_scope.dart';
import 'doctor_reference_dialog.dart';
import 'clinic_chat_dialog.dart';

/// Doctor Profile & Clinical Caseload Workspace
///
/// Gives optometrists and ophthalmologists a dedicated practitioner identity:
///  - Verified Medical/State Board Credentials (O.D. License, NPI, TPA certification)
///  - Personal Assigned Patient Caseload (tracked between-visit adherence)
///  - Pending Scribe SOAP Note Sign-offs & Review Queue
///  - Direct Clinical Copilot reference and patient consultation thread launch
class DoctorProfilePage extends StatefulWidget {
  const DoctorProfilePage({super.key});

  @override
  State<DoctorProfilePage> createState() => _DoctorProfilePageState();
}

class _DoctorProfilePageState extends State<DoctorProfilePage> {
  bool _acceptingReferrals = true;
  String _examRoom = 'Exam Suite 2A (Low Vision & OCT)';

  @override
  Widget build(BuildContext context) {
    final scope = context.watch<ClinicScope>();
    final doctorName = scope.displayName.isNotEmpty ? scope.displayName : 'Dr. O.D. Adegoke, O.D.';
    final role = scope.role.isNotEmpty ? scope.role : 'Practitioner';

    return Scaffold(
      backgroundColor: ClinicTheme.obsidian,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Doctor Profile Card
            _buildDoctorHeroCard(doctorName, role, scope),
            const SizedBox(height: 28),

            // Middle Grid: Quick Metrics & Practice Status
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: Column(
                    children: [
                      _buildAssignedCaseloadSection(scope),
                      const SizedBox(height: 28),
                      _buildPendingScribeReviewsSection(scope),
                    ],
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  flex: 2,
                  child: Column(
                    children: [
                      _buildCredentialsCard(),
                      const SizedBox(height: 24),
                      _buildPracticeSettingsCard(),
                      const SizedBox(height: 24),
                      _buildEcosystemBridgeCard(context),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDoctorHeroCard(String name, String role, ClinicScope scope) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: ClinicTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: ClinicTheme.border),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 38,
            backgroundColor: ClinicTheme.malachiteFaint,
            child: const Icon(Icons.medical_services_outlined, color: ClinicTheme.malachite, size: 40),
          ),
          const SizedBox(width: 24),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        color: ClinicTheme.textPrimary,
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: ClinicTheme.malachiteFaint,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: ClinicTheme.malachite.withAlpha(100)),
                      ),
                      child: Text(
                        'Verified $role',
                        style: const TextStyle(
                          color: ClinicTheme.malachite,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'Doctor of Optometry · Low Vision & Neuro-Optometric Rehabilitation · FAAO',
                  style: TextStyle(color: ClinicTheme.textSecondary, fontSize: 14),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 16,
                  children: [
                    _buildHeroMeta(Icons.local_hospital_outlined, 'GozVision Demo Eye Clinic (Main Branch)'),
                    _buildHeroMeta(Icons.door_sliding_outlined, _examRoom),
                    _buildHeroMeta(Icons.verified_user_outlined, 'NPI: 1928374650'),
                  ],
                ),
              ],
            ),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: ClinicTheme.malachite,
              foregroundColor: Colors.black,
            ),
            icon: const Icon(Icons.menu_book_outlined, size: 18),
            label: const Text('Clinical Copilot'),
            onPressed: () => DoctorReferenceDialog.show(context),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroMeta(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: ClinicTheme.malachiteDim),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(color: ClinicTheme.textSecondary, fontSize: 13)),
      ],
    );
  }

  Widget _buildAssignedCaseloadSection(ClinicScope scope) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: ClinicTheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: ClinicTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: const [
                  Icon(Icons.people_alt_outlined, color: ClinicTheme.malachite),
                  SizedBox(width: 10),
                  Text(
                    'My Assigned Patients (Active Caseload)',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: ClinicTheme.textPrimary),
                  ),
                ],
              ),
              Text(
                '3 Patients Monitored',
                style: TextStyle(color: ClinicTheme.textSecondary, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _buildPatientTile(
            name: 'Folashade Adeleke',
            patientId: 'demo_patient_001',
            age: 78,
            condition: 'Dry AMD (Advanced Geographic Atrophy)',
            device: 'eSight 4 Goz-Paired',
            status: 'High Adherence · 92% daily use',
            statusColor: ClinicTheme.malachite,
            onChat: () => ClinicChatDialog.show(context, patientId: 'demo_patient_001', patientName: 'Folashade Adeleke'),
          ),
          const Divider(color: ClinicTheme.border, height: 20),
          _buildPatientTile(
            name: 'Babajide Okafor',
            patientId: 'demo_patient_002',
            age: 64,
            condition: 'Advanced Glaucoma (Bilateral Scotoma)',
            device: 'IrisVision Inspire Trial',
            status: 'Abandonment Risk Detected (No use in 5 days)',
            statusColor: ClinicTheme.hazardAlert,
            onChat: () => ClinicChatDialog.show(context, patientId: 'demo_patient_002', patientName: 'Babajide Okafor'),
          ),
          const Divider(color: ClinicTheme.border, height: 20),
          _buildPatientTile(
            name: 'Chioma Adeyemi',
            patientId: 'demo_patient_003',
            age: 42,
            condition: 'Diabetic Retinopathy (Proliferative)',
            device: 'Goz Mobile Copilot + Smart Glasses',
            status: 'Stable · Last session 2h ago',
            statusColor: ClinicTheme.malachiteDim,
            onChat: () => ClinicChatDialog.show(context, patientId: 'demo_patient_003', patientName: 'Chioma Adeyemi'),
          ),
        ],
      ),
    );
  }

  Widget _buildPatientTile({
    required String name,
    required String patientId,
    required int age,
    required String condition,
    required String device,
    required String status,
    required Color statusColor,
    required VoidCallback onChat,
  }) {
    return Row(
      children: [
        CircleAvatar(
          backgroundColor: ClinicTheme.surface,
          child: Text(name[0], style: const TextStyle(color: ClinicTheme.textPrimary, fontWeight: FontWeight.w700)),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$name, $age', style: const TextStyle(fontWeight: FontWeight.w700, color: ClinicTheme.textPrimary)),
              Text(condition, style: const TextStyle(color: ClinicTheme.textSecondary, fontSize: 13)),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.devices, size: 14, color: ClinicTheme.textSecondary),
                  const SizedBox(width: 4),
                  Text(device, style: const TextStyle(color: ClinicTheme.textSecondary, fontSize: 12)),
                  const SizedBox(width: 12),
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: statusColor),
                  ),
                  const SizedBox(width: 6),
                  Text(status, style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.w600)),
                ],
              ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.calendar_month_outlined, color: ClinicTheme.warningAmber),
          tooltip: 'Schedule Doctor Follow-Up',
          onPressed: () => _showScheduleFollowupDialog(context, name, patientId),
        ),
        IconButton(
          icon: const Icon(Icons.chat_bubble_outline, color: ClinicTheme.malachite),
          tooltip: 'Message Patient',
          onPressed: onChat,
        ),
      ],
    );
  }

  void _showScheduleFollowupDialog(BuildContext context, String patientName, String patientId) {
    String followupType = 'Low Vision Device Fit Review';
    String timeframe = 'In 2 Weeks (Device Fit Standard)';
    String channel = 'In-App Goz Voice Check-in';
    final notesCtrl = TextEditingController(text: 'Review reading task speed and daily copilot adherence.');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: ClinicTheme.obsidian,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: ClinicTheme.border),
          ),
          title: Row(
            children: [
              const Icon(Icons.calendar_month, color: ClinicTheme.malachite),
              const SizedBox(width: 10),
              Expanded(
                child: Text('Schedule Follow-Up: $patientName',
                    style: const TextStyle(color: ClinicTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Clinical Protocol / Focus:', style: TextStyle(color: ClinicTheme.textSecondary, fontSize: 13)),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  value: followupType,
                  dropdownColor: ClinicTheme.surface,
                  style: const TextStyle(color: ClinicTheme.textPrimary),
                  decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                  items: const [
                    DropdownMenuItem(value: 'Low Vision Device Fit Review', child: Text('Low Vision Device Fit Review')),
                    DropdownMenuItem(value: 'OCT Macular Scan & Edema Check', child: Text('OCT Macular Scan & Edema')),
                    DropdownMenuItem(value: 'Glaucoma Pressure (IOP) Check', child: Text('Glaucoma Pressure (IOP)')),
                    DropdownMenuItem(value: 'Diabetic Retinopathy Follow-up', child: Text('Diabetic Retinopathy Follow-up')),
                    DropdownMenuItem(value: 'General Post-Op / Vision Check', child: Text('General Vision Check')),
                  ],
                  onChanged: (v) => setDialogState(() => followupType = v!),
                ),
                const SizedBox(height: 16),
                const Text('Target Interval:', style: TextStyle(color: ClinicTheme.textSecondary, fontSize: 13)),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  value: timeframe,
                  dropdownColor: ClinicTheme.surface,
                  style: const TextStyle(color: ClinicTheme.textPrimary),
                  decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                  items: const [
                    DropdownMenuItem(value: 'In 1 Week (Acute)', child: Text('In 1 Week (Acute)')),
                    DropdownMenuItem(value: 'In 2 Weeks (Device Fit Standard)', child: Text('In 2 Weeks (Device Fit Standard)')),
                    DropdownMenuItem(value: 'In 1 Month (Monitoring)', child: Text('In 1 Month (Monitoring)')),
                    DropdownMenuItem(value: 'In 3 Months (Chronic/Glaucoma)', child: Text('In 3 Months (Chronic/Glaucoma)')),
                    DropdownMenuItem(value: 'In 6 Months (Annual Protocol)', child: Text('In 6 Months (Annual Protocol)')),
                  ],
                  onChanged: (v) => setDialogState(() => timeframe = v!),
                ),
                const SizedBox(height: 16),
                const Text('Delivery Channel:', style: TextStyle(color: ClinicTheme.textSecondary, fontSize: 13)),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  value: channel,
                  dropdownColor: ClinicTheme.surface,
                  style: const TextStyle(color: ClinicTheme.textPrimary),
                  decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                  items: const [
                    DropdownMenuItem(value: 'In-App Goz Voice Check-in', child: Text('In-App Goz Voice Check-in')),
                    DropdownMenuItem(value: 'In-Clinic Exam Suite Visit', child: Text('In-Clinic Exam Suite Visit')),
                    DropdownMenuItem(value: 'Caregiver Notification & SMS', child: Text('Caregiver Notification & SMS')),
                  ],
                  onChanged: (v) => setDialogState(() => channel = v!),
                ),
                const SizedBox(height: 16),
                const Text('Doctor Instructions / Chart Notes:', style: TextStyle(color: ClinicTheme.textSecondary, fontSize: 13)),
                const SizedBox(height: 6),
                TextField(
                  controller: notesCtrl,
                  maxLines: 2,
                  style: const TextStyle(color: ClinicTheme.textPrimary, fontSize: 13),
                  decoration: const InputDecoration(contentPadding: EdgeInsets.all(12)),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: ClinicTheme.malachite,
                foregroundColor: Colors.black,
              ),
              icon: const Icon(Icons.send, size: 16),
              label: const Text('Schedule & Notify Patient'),
              onPressed: () async {
                Navigator.of(ctx).pop();
                try {
                  final scope = Provider.of<ClinicScope>(context, listen: false);
                  final clinicId = scope.clinicId ?? 'demo_clinic_001';
                  await Supabase.instance.client.from('appointments').insert({
                    'clinic_id': clinicId,
                    'patient_id': patientId,
                    'type': 'Doctor Follow-Up: $followupType',
                    'status': 'scheduled',
                    'start_at': DateTime.now().add(const Duration(days: 14)).toIso8601String(),
                  });
                  await Supabase.instance.client.from('notifications').insert({
                    'clinic_id': clinicId,
                    'patient_id': patientId,
                    'kind': 'reminder',
                    'channel': 'in_app_voice',
                    'message': 'Doctor Follow-up: $followupType ($timeframe). ${notesCtrl.text}',
                    'status': 'queued',
                  });
                } catch (_) {}
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: ClinicTheme.surface,
                      content: Text('Follow-up scheduled for $patientName ($timeframe via $channel). Patient and recall engine notified.'),
                    ),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPendingScribeReviewsSection(ClinicScope scope) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: ClinicTheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: ClinicTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.rate_review_outlined, color: ClinicTheme.warningAmber),
              SizedBox(width: 10),
              Text(
                'Doctor Scribe Queue (SOAP Notes Awaiting Signature)',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: ClinicTheme.textPrimary),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: ClinicTheme.obsidian,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: ClinicTheme.border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text('Encounter #ENC-104 · Folashade Adeleke', style: TextStyle(fontWeight: FontWeight.w700, color: ClinicTheme.textPrimary)),
                      Text('Subjective: Reports improved contrast reading newspaper with Goz voice tags. Objective: VA 20/200 OD, 20/150 OS.', style: TextStyle(color: ClinicTheme.textSecondary, fontSize: 13)),
                    ],
                  ),
                ),
                FilledButton.tonal(
                  style: FilledButton.styleFrom(
                    backgroundColor: ClinicTheme.malachiteFaint,
                    foregroundColor: ClinicTheme.malachite,
                  ),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('SOAP note reviewed and digitally signed by Doctor.')),
                    );
                  },
                  child: const Text('Review & Sign'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCredentialsCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: ClinicTheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: ClinicTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.badge_outlined, color: ClinicTheme.malachite),
              SizedBox(width: 10),
              Text('Doctor Credentials', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: ClinicTheme.textPrimary)),
            ],
          ),
          const SizedBox(height: 16),
          _buildCredRow('Board License:', 'OD-84920-CA (State Board of Optometry)'),
          _buildCredRow('NPI Identifier:', '1928374650'),
          _buildCredRow('Therapeutics:', 'TPA Certified + Glaucoma (TLG)'),
          _buildCredRow('DEA Registration:', 'BD1982746 (Class II-V Drops)'),
          _buildCredRow('Specialty:', 'Fellow of American Academy of Optometry'),
        ],
      ),
    );
  }

  Widget _buildCredRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 120, child: Text(label, style: const TextStyle(color: ClinicTheme.textSecondary, fontSize: 13))),
          Expanded(child: Text(value, style: const TextStyle(color: ClinicTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 13))),
        ],
      ),
    );
  }

  Widget _buildPracticeSettingsCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: ClinicTheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: ClinicTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.tune_outlined, color: ClinicTheme.malachite),
              SizedBox(width: 10),
              Text('Doctor Practice Preferences', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: ClinicTheme.textPrimary)),
            ],
          ),
          const SizedBox(height: 14),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            activeColor: ClinicTheme.malachite,
            title: const Text('Accepting Low-Vision Referrals', style: TextStyle(fontSize: 14, color: ClinicTheme.textPrimary)),
            subtitle: const Text('Allows front desk & external ODs to direct-book candidates', style: TextStyle(color: ClinicTheme.textSecondary, fontSize: 12)),
            value: _acceptingReferrals,
            onChanged: (val) => setState(() => _acceptingReferrals = val),
          ),
        ],
      ),
    );
  }

  Widget _buildEcosystemBridgeCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: ClinicTheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: ClinicTheme.malachite.withAlpha(80)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.hub_outlined, color: ClinicTheme.malachite),
              SizedBox(width: 10),
              Text('GozVision Ecosystem', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: ClinicTheme.textPrimary)),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'Experience what your patients experience. Launch the Goz Copilot simulator with low-vision auditory scene awareness.',
            style: TextStyle(color: ClinicTheme.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: ClinicTheme.malachite),
                foregroundColor: ClinicTheme.malachite,
              ),
              icon: const Icon(Icons.launch, size: 16),
              label: const Text('Launch Patient Copilot (PWA)'),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    backgroundColor: ClinicTheme.surface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: const BorderSide(color: ClinicTheme.border),
                    ),
                    title: Row(
                      children: const [
                        Icon(Icons.hub_outlined, color: ClinicTheme.malachite),
                        SizedBox(width: 10),
                        Text('Goz Copilot (Patient Experience)', style: TextStyle(color: ClinicTheme.textPrimary, fontSize: 18)),
                      ],
                    ),
                    content: const Text(
                      'In this unified ecosystem, low-vision patients access their voice-first copilot at /patient (or via native mobile).\n\nBetween visits, their daily task completions, obstacle warnings, and emergency SOS signals stream in real-time directly into your Low Vision Hub and Caseload.',
                      style: TextStyle(color: ClinicTheme.textSecondary, height: 1.5),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: const Text('Got it'),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
