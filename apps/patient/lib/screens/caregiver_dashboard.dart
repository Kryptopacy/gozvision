import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../core/app_config.dart';
import '../core/theme.dart';
import 'package:copilot_core/copilot_core.dart';
import '../services/sos_service.dart';

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
  /// instead. See CONTEXT.md ("Patient").
  String? _assignedPatientUid;

  @override
  void initState() {
    super.initState();
    _resolveAssignedPatient();
  }

  Future<void> _resolveAssignedPatient() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final assigned = doc.data()?['assigned_patients'];
      if (assigned is List && assigned.isNotEmpty && mounted) {
        setState(() => _assignedPatientUid = assigned.first as String);
      }
    } catch (e) {
      debugPrint('CaregiverDashboard: Failed to resolve assigned patients: $e');
    }
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
          title: Text(
            'Caregiver Overview',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: GozAITheme.malachite),
            onPressed: () => context.go('/'),
            tooltip: 'Back to Home',
          ),
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
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('sos_alerts')
          .doc(patientUid)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data?.data() == null) {
          return const SizedBox.shrink(); // No alert document
        }

        final data = snapshot.data!.data()!;
        final resolved = data['resolved'] == true;
        if (resolved) {
          return const SizedBox.shrink(); // Alert is resolved
        }

        final message = data['message'] ?? data['note'] ?? 'Emergency assistance requested.';
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
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('patients')
                      .doc(patientUid)
                      .collection('clinical_events')
                      .where('type', whereIn: ['hazard', 'wandering'])
                      .orderBy('timestamp', descending: true)
                      .limit(20)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator(color: GozAITheme.malachite));
                    }
                    if (snapshot.hasError) {
                      return Center(
                        child: Text('Error loading events.',
                            style: TextStyle(color: GozAITheme.hazardAlert)),
                      );
                    }
                    final docs = snapshot.data?.docs ?? [];
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
                        final data = docs[index].data() as Map<String, dynamic>;
                        final isHazard = data['type'] == 'hazard';
                        final time = data['timestamp'] as Timestamp?;
                        final timeStr = time != null
                            ? _formatTimestamp(time.toDate())
                            : 'Just now';
                        return _AlertRow(
                          isHazard: isHazard,
                          note: data['note'] ?? 'Unknown event',
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
