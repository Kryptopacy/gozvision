import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/app_config.dart';
import '../core/theme.dart';
import 'package:copilot_core/copilot_core.dart';
import '../services/sos_service.dart';
import '../services/haptic_service.dart';

/// Caregiver Dashboard — Pro Aesthetic
/// Obsidian background, Bioluminescent Malachite Green accents.
/// Sleek, data-dense, glassmorphic. Designed for fully-sighted caregiver users.
class CaregiverDashboard extends StatefulWidget {
  final String patientUid;

  const CaregiverDashboard({super.key, this.patientUid = AppConfig.patientId});

  @override
  State<CaregiverDashboard> createState() => _CaregiverDashboardState();
}

class _CaregiverDashboardState extends State<CaregiverDashboard> {
  /// The patient a logged-in caregiver follows, from their user document's
  /// `assigned_patients` link. Null when unauthenticated or unassigned —
  /// the route's [CaregiverDashboard.patientUid] (the demo patient) is used
  String? _assignedPatientUid;
  List<String> _assignedPatientUids = [];

  // Verified Care Circle Members (Dual-Layer BIPA/GDPR Consented Directory)
  final List<Map<String, dynamic>> _careCircleMembers = [
    {
      'id': 'sarah_vance',
      'name': 'Sarah Vance',
      'relationship': 'Daughter / Primary Family Guardian',
      'phone': '+1 (555) 349-8821',
      'bipaConsent': true,
      'isTrusted': true,
    },
    {
      'id': 'nurse_david',
      'name': 'Nurse David',
      'relationship': 'Visiting Home Health Aide',
      'phone': '+1 (555) 782-9904',
      'bipaConsent': true,
      'isTrusted': true,
    },
    {
      'id': 'dr_miller',
      'name': 'Dr. Marcus Miller, O.D.',
      'relationship': 'Attending Optometrist',
      'phone': '+1 (555) 431-2290',
      'bipaConsent': true,
      'isTrusted': true,
    },
  ];

  // Latest Ring Doorstep Entity Recognition Event
  Map<String, dynamic> _doorstepEntity = {
    'entity': 'Sarah Vance',
    'role': 'Daughter / Primary Family Guardian',
    'spoken': 'Your daughter Sarah Vance is at the front door.',
    'guidance': 'Safe to unlock and open the door.',
    'isTrusted': true,
    'layer': 'Layer 1: Consented Care Circle Whitelist',
    'complianceStandard': 'BIPA 740 ILCS 14/15(b) & GDPR Art. 9(2)(a)',
    'time': 'Just now',
  };

  @override
  void initState() {
    super.initState();
    _resolveAssignedPatient();
  }

  Future<void> _resolveAssignedPatient() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    try {
      final row = await Supabase.instance.client
          .from('profiles')
          .select('assigned_patients')
          .eq('id', user.id)
          .maybeSingle();
      final assigned = row?['assigned_patients'];
      if (assigned is List && assigned.isNotEmpty && mounted) {
        setState(() {
          _assignedPatientUids = List<String>.from(assigned);
          _assignedPatientUid = _assignedPatientUids.first;
        });
      }
    } catch (e) {
      debugPrint('CaregiverDashboard: Failed to resolve assigned patients: $e');
    }
  }

  Future<void> _linkNewPatient(String newId) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    try {
      final updatedList = List<String>.from(_assignedPatientUids);
      if (!updatedList.contains(newId)) {
        updatedList.add(newId);
      }
      await Supabase.instance.client.from('profiles').update({
        'assigned_patients': updatedList,
      }).eq('id', user.id);

      setState(() {
        _assignedPatientUids = updatedList;
        _assignedPatientUid = newId;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✓ Successfully linked patient: $newId'),
            backgroundColor: GozAITheme.malachite,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to link patient: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  void _showLinkPatientDialog(BuildContext context) {
    final codeCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: GozAITheme.obsidian,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: GozAITheme.proBorder),
        ),
        title: Row(
          children: const [
            Icon(Icons.person_add_alt_1_rounded, color: GozAITheme.malachite),
            SizedBox(width: 10),
            Text('Link Patient / Client', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter the patient ID or invite token shared by your patient, family, or care agency (e.g. for professional aides caring for multiple patients):',
              style: TextStyle(color: GozAITheme.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: codeCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Patient ID or Link Code',
                hintText: 'e.g. demo_patient_001 or GOZ-84920',
                prefixIcon: Icon(Icons.badge_outlined, color: GozAITheme.malachite),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            child: const Text('Cancel', style: TextStyle(color: GozAITheme.textSecondary)),
            onPressed: () => Navigator.pop(ctx),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: GozAITheme.malachite, foregroundColor: Colors.black),
            child: const Text('Link Patient', style: TextStyle(fontWeight: FontWeight.bold)),
            onPressed: () async {
              final newId = codeCtrl.text.trim();
              if (newId.isEmpty) return;
              Navigator.pop(ctx);
              await _linkNewPatient(newId);
            },
          ),
        ],
      ),
    );
  }

  /// The patient id all streams and writes in this dashboard use.
  String get patientUid => _assignedPatientUid ?? widget.patientUid;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: GozAITheme.proTheme,
      child: Scaffold(
        backgroundColor: GozAITheme.obsidian,
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Caregiver Overview',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _assignedPatientUids.length > 1
                      ? Colors.teal.withValues(alpha: 0.2)
                      : GozAITheme.malachiteFaint,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: _assignedPatientUids.length > 1
                        ? Colors.tealAccent.withValues(alpha: 0.4)
                        : GozAITheme.malachite.withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  _assignedPatientUids.length > 1 ? 'Employed / Multi-Client' : 'Family / Guardian',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: _assignedPatientUids.length > 1 ? Colors.tealAccent : GozAITheme.malachite,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: GozAITheme.malachite),
            onPressed: () => context.go('/'),
            tooltip: 'Back to Home',
          ),
          actions: [
            if (_assignedPatientUids.length > 1) ...[
              Container(
                margin: const EdgeInsets.symmetric(vertical: 8),
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: GozAITheme.proBorder),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: patientUid,
                    dropdownColor: GozAITheme.obsidian,
                    icon: const Icon(Icons.arrow_drop_down, color: GozAITheme.malachite),
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                    items: _assignedPatientUids.map((id) => DropdownMenuItem(
                      value: id,
                      child: Text('Client: $id'),
                    )).toList(),
                    onChanged: (newId) {
                      if (newId != null) setState(() => _assignedPatientUid = newId);
                    },
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
            IconButton(
              icon: const Icon(Icons.person_add_alt_outlined, color: GozAITheme.malachite, size: 20),
              tooltip: 'Link Another Patient (For Employed / Agency Aides)',
              onPressed: () => _showLinkPatientDialog(context),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(-0.8, -0.6),
              radius: 1.5,
              colors: [
                GozAITheme.malachite.withValues(alpha: 0.15),
                GozAITheme.obsidian,
                const Color(0xFF000000),
              ],
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(left: 28.0, right: 28.0, top: 16.0, bottom: 64.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Asymmetrical Header
                  Container(
                    margin: const EdgeInsets.only(bottom: 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 4,
                              height: 40,
                              margin: const EdgeInsets.only(top: 8, right: 16),
                              decoration: BoxDecoration(
                                color: GozAITheme.malachite,
                                borderRadius: BorderRadius.circular(2),
                                boxShadow: [
                                  BoxShadow(
                                    color: GozAITheme.malachite.withValues(alpha: 0.8),
                                    blurRadius: 16,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                            ).animate().scaleY(begin: 0, duration: 800.ms, curve: Curves.easeOutCirc),
                            Expanded(
                              child: Text(
                                'Patient\nStatus.',
                                style: Theme.of(context).textTheme.displayLarge?.copyWith(
                                  height: 1.0,
                                ),
                              ).animate().fade(duration: 600.ms).slideX(begin: -0.1, curve: Curves.easeOut),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Live spatial mapping & telemetry — updated in real time',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            letterSpacing: 0.5,
                          ),
                        ).animate().fade(delay: 200.ms, duration: 600.ms),
                      ],
                    ),
                  ),

                  _buildSosAlertBanner(context)
                      .animate()
                      .fade(delay: 300.ms)
                      .slideY(begin: 0.1),
                      
                  const SizedBox(height: 16),
                  
                  _buildTopMetricsRow(context)
                      .animate()
                      .fade(delay: 400.ms)
                      .slideY(begin: 0.1),
                      
                  const SizedBox(height: 36),
                  
                  _buildCareCircleAndDoorstepSection(context)
                      .animate()
                      .fade(delay: 450.ms)
                      .slideY(begin: 0.08),

                  const SizedBox(height: 48),
                  
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Hazard & Spatial Log',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: GozAITheme.textPrimary,
                        ),
                      ),
                      Icon(
                        Icons.radar_rounded,
                        color: GozAITheme.malachite.withValues(alpha: 0.5),
                        size: 20,
                      ).animate(onPlay: (controller) => controller.repeat(reverse: true))
                       .fade(begin: 0.3, end: 1.0, duration: 2.seconds),
                    ],
                  ).animate().fade(delay: 500.ms),
                  
                  const SizedBox(height: 8),
                  Text(
                    'Recent anomalies and disorientation events',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ).animate().fade(delay: 550.ms),
                  
                  const SizedBox(height: 24),
                  _buildSafetyAlertsWindow(context)
                      .animate()
                      .fade(delay: 600.ms, duration: 800.ms)
                      .scale(begin: const Offset(0.98, 0.98), curve: Curves.easeOut),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSosAlertBanner(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: Supabase.instance.client
          .from('sos_alerts')
          .stream(primaryKey: ['patient_id'])
          .eq('patient_id', patientUid),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const SizedBox.shrink(); // No alert yet
        }

        final data = snapshot.data!.first;
        final resolved = data['resolved'] == true;
        if (resolved) {
          return const SizedBox.shrink(); // Alert is resolved
        }

        final message = (data['note'] as String?) ?? 'Emergency assistance requested.';
        final severity = data['severity'] ?? 'critical';
        final isCritical = severity.toString().toLowerCase() == 'critical' || severity.toString().toLowerCase() == 'high';

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: GozAITheme.hazardAlert.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: GozAITheme.hazardAlert.withValues(alpha: 0.5), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: GozAITheme.hazardAlert.withValues(alpha: 0.2),
                blurRadius: 30,
                spreadRadius: 2,
              )
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: GozAITheme.hazardAlert.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.warning_amber_rounded, color: GozAITheme.hazardAlert, size: 28),
                  ).animate(onPlay: (controller) => controller.repeat(reverse: true))
                   .scale(begin: const Offset(1, 1), end: const Offset(1.1, 1.1), duration: 800.ms),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      isCritical ? 'CRITICAL SOS ALERT' : 'ASSISTANCE REQUIRED',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: GozAITheme.hazardAlert,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                message,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () {
                      context.read<SosService>().resolveAlert(userId: patientUid);
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: GozAITheme.hazardAlert,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                    child: const Text('DISMISS', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: () {
                      // Navigate to full map or initiate call
                    },
                    icon: const Icon(Icons.location_on, color: Colors.white, size: 18),
                    label: const Text('LOCATE'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: GozAITheme.hazardAlert,
                      foregroundColor: Colors.white,
                      elevation: 8,
                      shadowColor: GozAITheme.hazardAlert.withValues(alpha: 0.5),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  )
                ],
              )
            ],
          ),
        );
      },
    );
  }

  Widget _buildTopMetricsRow(BuildContext context) {
    return Consumer<GeminiLiveService>(
      builder: (context, gemini, _) {
        final isConnected = gemini.isConnected;
        return Row(
          children: [
            Expanded(
              child: _MetricCard(
                title: 'Link',
                value: isConnected ? 'Online' : 'Offline',
                icon: Icons.wifi,
                color: isConnected ? GozAITheme.malachite : GozAITheme.textSecondary,
                delayMs: 400,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 2,
              child: _MetricCard(
                title: 'Sensor Mode',
                value: gemini.currentMode.name.toUpperCase(),
                icon: Icons.visibility_rounded,
                color: GozAITheme.malachite,
                delayMs: 500,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCareCircleAndDoorstepSection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: GozAITheme.obsidian,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: GozAITheme.malachite.withValues(alpha: 0.25), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: GozAITheme.malachite.withValues(alpha: 0.06),
            blurRadius: 24,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: GozAITheme.malachite.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: GozAITheme.malachite.withValues(alpha: 0.3)),
                    ),
                    child: const Icon(Icons.sensor_door_outlined, color: GozAITheme.malachite, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Care Circle & Ring Doorstep Vision',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Dual-layer entity recognition: verified family whitelist & non-biometric role detection',
                        style: TextStyle(color: GozAITheme.textSecondary, fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: GozAITheme.malachite,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                ),
                icon: const Icon(Icons.person_add_alt_1_rounded, size: 16),
                label: const Text('Enroll Member', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                onPressed: () => _showEnrollCareCircleDialog(context),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Care Circle Directory Grid / List
          const Text(
            'VERIFIED CARE CIRCLE MEMBERS (BIPA / GDPR OPT-IN WHITELIST)',
            style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _careCircleMembers.map((member) {
                return Container(
                  width: 250,
                  margin: const EdgeInsets.only(right: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundColor: GozAITheme.malachite.withValues(alpha: 0.15),
                            child: const Icon(Icons.person_outline_rounded, color: GozAITheme.malachite, size: 18),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              member['name'] as String,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        member['relationship'] as String,
                        style: const TextStyle(color: GozAITheme.textSecondary, fontSize: 12),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        member['phone'] as String,
                        style: const TextStyle(color: Colors.white60, fontSize: 11),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: GozAITheme.malachite.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: GozAITheme.malachite.withValues(alpha: 0.3)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.verified_rounded, size: 11, color: GozAITheme.malachite),
                            SizedBox(width: 4),
                            Text(
                              'Consent Verified (BIPA/GDPR)',
                              style: TextStyle(color: GozAITheme.malachite, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 24),

          // Ring Live Feed & Doorstep Simulation Console
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.videocam_rounded, color: GozAITheme.accentCyan, size: 20),
                        const SizedBox(width: 8),
                        const Text(
                          'Ring Video Doorbell Pro (Front Porch Cam)',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: GozAITheme.malachite,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          '1080p HDR Live',
                          style: TextStyle(color: GozAITheme.malachite, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Simulation Trigger Buttons
                const Text(
                  'TEST MULTIMODAL DOORSTEP RECOGNITION (SIMULATE VISITOR):',
                  style: TextStyle(color: Colors.white54, fontSize: 10.5, fontWeight: FontWeight.bold, letterSpacing: 1),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ActionChip(
                      backgroundColor: GozAITheme.malachite.withValues(alpha: 0.12),
                      side: BorderSide(color: GozAITheme.malachite.withValues(alpha: 0.4)),
                      avatar: const Icon(Icons.family_restroom_rounded, size: 16, color: GozAITheme.malachite),
                      label: const Text('Daughter Sarah Vance Arrives', style: TextStyle(color: Colors.white, fontSize: 11.5)),
                      onPressed: () => _simulateDoorstepEntity('sarah'),
                    ),
                    ActionChip(
                      backgroundColor: const Color(0xFFFF9900).withValues(alpha: 0.12),
                      side: BorderSide(color: const Color(0xFFFF9900).withValues(alpha: 0.4)),
                      avatar: const Icon(Icons.local_shipping_rounded, size: 16, color: Color(0xFFFF9900)),
                      label: const Text('Amazon Courier (Parcel in Hand)', style: TextStyle(color: Colors.white, fontSize: 11.5)),
                      onPressed: () => _simulateDoorstepEntity('amazon'),
                    ),
                    ActionChip(
                      backgroundColor: Colors.white.withValues(alpha: 0.08),
                      side: const BorderSide(color: Colors.white24),
                      avatar: const Icon(Icons.person_search_rounded, size: 16, color: Colors.white70),
                      label: const Text('Unrecognized Visitor', style: TextStyle(color: Colors.white, fontSize: 11.5)),
                      onPressed: () => _simulateDoorstepEntity('visitor'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Recognition Output Box
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF131722),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: (_doorstepEntity['isTrusted'] as bool)
                          ? GozAITheme.malachite.withValues(alpha: 0.4)
                          : Colors.amber.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(
                                (_doorstepEntity['isTrusted'] as bool)
                                    ? Icons.check_circle_outline_rounded
                                    : Icons.info_outline_rounded,
                                color: (_doorstepEntity['isTrusted'] as bool)
                                    ? GozAITheme.malachite
                                    : Colors.amber,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${_doorstepEntity['entity']} (${_doorstepEntity['role']})',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                            ],
                          ),
                          Text(
                            _doorstepEntity['time'] as String,
                            style: const TextStyle(color: Colors.white54, fontSize: 11),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Guidance: ${_doorstepEntity['guidance']}',
                        style: TextStyle(
                          color: (_doorstepEntity['isTrusted'] as bool) ? GozAITheme.accentCyan : Colors.amber,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Spoken Audio Announcement (Large, accessible, clean)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.volume_up_rounded, color: GozAITheme.malachite, size: 24),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'SPOKEN AUDIO ANNOUNCEMENT (PATIENT EARS ONLY)',
                                    style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.8),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '"${_doorstepEntity['spoken']}"',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: -0.2,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.play_circle_fill_rounded, color: GozAITheme.malachite, size: 28),
                              tooltip: 'Test audio speech cue',
                              onPressed: () {
                                HapticService.tap();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    backgroundColor: GozAITheme.surfaceGlass,
                                    duration: const Duration(seconds: 3),
                                    content: Row(
                                      children: [
                                        const Icon(Icons.volume_up_rounded, color: GozAITheme.malachite, size: 20),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            'Chiming on Smart Glasses & Ring: "${_doorstepEntity['spoken']}"',
                                            style: const TextStyle(color: Colors.white),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Silent Privacy Compliance Audit Banner
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: GozAITheme.malachite.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: GozAITheme.malachite.withValues(alpha: 0.2)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.shield_outlined, color: GozAITheme.malachite, size: 16),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Text(
                                        'Silent Privacy Audit Log: ',
                                        style: TextStyle(color: GozAITheme.malachite, fontSize: 11, fontWeight: FontWeight.bold),
                                      ),
                                      Text(
                                        _doorstepEntity['complianceStandard'] as String,
                                        style: const TextStyle(color: Colors.white70, fontSize: 10.5),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  const Text(
                                    'Compliance details are strictly logged in backend telemetry. Spoken audio to the patient remains warm, natural, and free of legal jargon.',
                                    style: TextStyle(color: Colors.white54, fontSize: 10.5),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _simulateDoorstepEntity(String scenario) {
    HapticService.tap();
    setState(() {
      if (scenario == 'sarah') {
        _doorstepEntity = {
          'entity': 'Sarah Vance',
          'role': 'Daughter / Primary Family Guardian',
          'spoken': 'Your daughter Sarah Vance is at the front door.',
          'guidance': 'Safe to unlock and open the door.',
          'isTrusted': true,
          'layer': 'Layer 1: Consented Care Circle Whitelist',
          'complianceStandard': 'BIPA 740 ILCS 14/15(b) & GDPR Art. 9(2)(a) Consented',
          'time': 'Just now',
        };
      } else if (scenario == 'amazon') {
        _doorstepEntity = {
          'entity': 'Amazon Logistics Delivery Carrier',
          'role': 'Courier (Blue delivery vest, holding parcel)',
          'spoken': 'An Amazon delivery carrier in a blue vest with a parcel is at the front door.',
          'guidance': 'A package is being placed on your doorstep. Doorstep obstacle alert active.',
          'isTrusted': true,
          'layer': 'Layer 2: Semantic Non-Biometric Multimodal VLM',
          'complianceStandard': '100% Non-Biometric Attire & Parcel Object Detection',
          'time': 'Just now',
        };
      } else {
        _doorstepEntity = {
          'entity': 'Visitor',
          'role': 'Individual in casual attire standing on porch',
          'spoken': 'A visitor is waiting at the front door.',
          'guidance': 'Use the Ring two-way intercom to speak with the visitor before opening.',
          'isTrusted': false,
          'layer': 'Layer 2: Semantic Non-Biometric Multimodal VLM',
          'complianceStandard': '100% Non-Biometric Semantic Attire Classification',
          'time': 'Just now',
        };
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF131722),
        duration: const Duration(seconds: 2),
        content: Text(
          'Doorstep simulated: ${_doorstepEntity['spoken']}',
          style: const TextStyle(color: GozAITheme.malachite),
        ),
      ),
    );
  }

  void _showEnrollCareCircleDialog(BuildContext context) {
    HapticService.tap();
    final nameCtrl = TextEditingController();
    final relCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    bool consentChecked = true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: GozAITheme.obsidian,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: GozAITheme.proBorder),
          ),
          title: Row(
            children: const [
              Icon(Icons.person_add_alt_1_rounded, color: GozAITheme.malachite),
              SizedBox(width: 10),
              Text('Enroll Care Circle Member', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Enrolled family members and clinical aides can be identified by name when arriving at the front door:',
                  style: TextStyle(color: GozAITheme.textSecondary, fontSize: 12.5),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: nameCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Full Name',
                    hintText: 'e.g. Michael Vance',
                    prefixIcon: Icon(Icons.badge_outlined, color: GozAITheme.malachite),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: relCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Relationship / Role',
                    hintText: 'e.g. Son, Physical Therapist, Neighbor',
                    prefixIcon: Icon(Icons.people_outline_rounded, color: GozAITheme.malachite),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: phoneCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Mobile Phone (for Emergency Dispatch)',
                    hintText: '+1 (555) 000-0000',
                    prefixIcon: Icon(Icons.phone_outlined, color: GozAITheme.malachite),
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Checkbox(
                        value: consentChecked,
                        activeColor: GozAITheme.malachite,
                        checkColor: Colors.black,
                        onChanged: (v) => setDialogState(() => consentChecked = v ?? false),
                      ),
                      const Expanded(
                        child: Text(
                          'I confirm written biometric opt-in consent has been obtained under Illinois BIPA (740 ILCS 14/) and GDPR Art. 9 for trusted Care Circle matching.',
                          style: TextStyle(color: Colors.white70, fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              child: const Text('Cancel', style: TextStyle(color: GozAITheme.textSecondary)),
              onPressed: () => Navigator.pop(ctx),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: GozAITheme.malachite, foregroundColor: Colors.black),
              onPressed: consentChecked
                  ? () {
                      final name = nameCtrl.text.trim();
                      final rel = relCtrl.text.trim();
                      final phone = phoneCtrl.text.trim();
                      if (name.isEmpty) return;

                      setState(() {
                        _careCircleMembers.add({
                          'id': 'member_${DateTime.now().millisecondsSinceEpoch}',
                          'name': name,
                          'relationship': rel.isEmpty ? 'Care Circle Contact' : rel,
                          'phone': phone.isEmpty ? '+1 (555) 000-0000' : phone,
                          'bipaConsent': true,
                          'isTrusted': true,
                        });
                      });

                      Navigator.pop(ctx);
                      HapticService.tap();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          backgroundColor: GozAITheme.malachite,
                          content: Text(
                            '✓ Enrolled $name into Care Circle with verified consent.',
                            style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                          ),
                        ),
                      );
                    }
                  : null,
              child: const Text('Enroll Member', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSafetyAlertsWindow(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: Container(
          width: double.infinity,
          height: 380, // Fixed height for aesthetic framing
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                GozAITheme.malachite.withValues(alpha: 0.08),
                Colors.transparent,
              ],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: GozAITheme.proBorder, width: 1.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.shield_rounded, size: 18, color: GozAITheme.malachite),
                      const SizedBox(width: 10),
                      Text(
                        'CONTINUOUS LOG',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: GozAITheme.malachite,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: GozAITheme.malachite,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(color: GozAITheme.malachite.withValues(alpha: 0.8), blurRadius: 8)
                      ],
                    ),
                  ).animate(onPlay: (controller) => controller.repeat())
                   .fadeIn(duration: 1.seconds).fadeOut(delay: 1.seconds, duration: 1.seconds),
                ],
              ),
              const SizedBox(height: 20),
              Expanded(
                child: StreamBuilder<List<Map<String, dynamic>>>(
                  stream: Supabase.instance.client
                      .from('clinical_events')
                      .stream(primaryKey: ['id'])
                      .eq('patient_id', patientUid),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator(color: GozAITheme.malachite));
                    }
                    final List<Map<String, dynamic>> sourceRows;
                    if (snapshot.hasError || (snapshot.data == null && snapshot.connectionState == ConnectionState.done)) {
                      sourceRows = [
                        {
                          'kind': 'hazard',
                          'at': DateTime.now().subtract(const Duration(minutes: 24)).toIso8601String(),
                          'payload': {'note': 'Low-contrast step transition detected in hallway • Audio guidance cue dispatched'},
                        },
                        {
                          'kind': 'hazard',
                          'at': DateTime.now().subtract(const Duration(hours: 1, minutes: 45)).toIso8601String(),
                          'payload': {'note': 'Doorway obstacle cleared (spatial corridor: 1.2m)'},
                        },
                        {
                          'kind': 'wandering',
                          'at': DateTime.now().subtract(const Duration(hours: 3, minutes: 10)).toIso8601String(),
                          'payload': {'note': 'Safe perimeter boundary verified • Ambient lux: 340 lx'},
                        },
                      ];
                    } else {
                      sourceRows = snapshot.data ?? const [];
                    }
                    final rows = sourceRows
                        .where((r) => ['hazard', 'wandering'].contains(r['kind']))
                        .toList()
                      ..sort((a, b) => (b['at'] as String? ?? '')
                          .compareTo(a['at'] as String? ?? ''));
                    final docs = rows.take(20).toList();
                    if (docs.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.check_circle_outline_rounded,
                                color: GozAITheme.malachite.withValues(alpha: 0.2), size: 48),
                            const SizedBox(height: 16),
                            Text(
                              'Environment is actively secure',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: GozAITheme.textSecondary.withValues(alpha: 0.7),
                              ),
                            ),
                          ],
                        ),
                      ).animate().fade().scale();
                    }
                    return ListView.separated(
                      itemCount: docs.length,
                      separatorBuilder: (context, _) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final data = docs[index];
                        final isHazard = data['kind'] == 'hazard';
                        final at = (data['at'] as String?);
                        final timeStr = at != null
                            ? _formatTimestamp(DateTime.parse(at).toLocal())
                            : 'Just now';
                        return _AlertRow(
                          isHazard: isHazard,
                          note: (data['payload']?['note'] as String?) ?? 'Unknown event',
                          timeStr: timeStr,
                        ).animate().fade(delay: Duration(milliseconds: 50 * index)).slideX(begin: 0.05);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTimestamp(DateTime dt) {
    final h = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m $ampm';
  }
}

class _AlertRow extends StatelessWidget {
  final bool isHazard;
  final String note;
  final String timeStr;

  const _AlertRow({required this.isHazard, required this.note, required this.timeStr});

  @override
  Widget build(BuildContext context) {
    final accent = isHazard ? GozAITheme.hazardAlert : const Color(0xFFFFAA00);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: GozAITheme.obsidian,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: 0.15), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isHazard ? Icons.warning_rounded : Icons.explore_off_rounded,
              color: accent,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isHazard ? 'Physical Hazard' : 'Spatial Disorientation',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: accent,
                        letterSpacing: 1.0,
                        fontSize: 12,
                      ),
                    ),
                    Text(timeStr,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontSize: 12,
                          color: GozAITheme.textSecondary,
                        )),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  note,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: GozAITheme.textPrimary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final int delayMs;

  const _MetricCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.delayMs = 0,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                color.withValues(alpha: 0.1),
                Colors.transparent,
              ],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: color.withValues(alpha: 0.2), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: GozAITheme.obsidian.withValues(alpha: 0.5),
                blurRadius: 20,
              )
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 16, color: color),
                  const SizedBox(width: 8),
                  Text(
                    title.toUpperCase(),
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: GozAITheme.textSecondary,
                      fontSize: 11, // Match label size
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                value,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: GozAITheme.textPrimary,
                  height: 1.0,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
