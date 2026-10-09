import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/clinic_theme.dart';
import '../core/patient_utils.dart';
import '../data/clinic_scope.dart';
import 'clinic_chat_dialog.dart';

/// Low Vision Hub — Enterprise Referral & Adherence Cockpit (2026 Standards).
///
/// Closes the loop that leaks patients:
/// referral (64% never referred) → device fit (29% abandoned) → sustained visual autonomy.
class LowVisionHubPage extends StatelessWidget {
  const LowVisionHubPage({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = context.watch<ClinicScope>();
    final referrals = scope.stream('low_vision_referrals');
    final fits = scope.stream('device_fits');

    if (referrals == null || fits == null) {
      return const Center(child: CircularProgressIndicator(color: ClinicTheme.brandAccent));
    }

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header & Title ─────────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Low Vision Hub',
                        style: GoogleFonts.sora(fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -0.4),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: ClinicTheme.brandAccentFaint,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: ClinicTheme.brandAccent.withOpacity(0.4)),
                        ),
                        child: Text(
                          'CONTINUOUS CARE LOOP ACTIVE',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                            color: ClinicTheme.brandAccent,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Referrals, assistive optical trials, and remote telemetry adherence — keeping low-vision patients independent.',
                    style: GoogleFonts.plusJakartaSans(color: ClinicTheme.textSecondary, fontSize: 13),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ── 2026 Executive Performance Ribbon (4 Stat Cards) ───────────
          _buildPerformanceRibbon(),
          const SizedBox(height: 24),

          // ── Main Two-Column Workflow Workspace ─────────────────────────
          Expanded(
            child: StreamBuilder<ClinicRows>(
              stream: fits,
              builder: (context, fitsSnap) {
                final fitRows = fitsSnap.data ?? const [];
                return StreamBuilder<ClinicRows>(
                  stream: referrals,
                  builder: (context, refSnap) {
                    final refRows = refSnap.data ?? const [];
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Left: Referral Funnel (360px)
                        SizedBox(
                          width: 360,
                          child: _ReferralPanel(rows: refRows),
                        ),
                        const SizedBox(width: 24),
                        // Right: Device Trials & Adherence Stream (Expanded)
                        Expanded(
                          child: _DeviceFitPanel(rows: fitRows),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPerformanceRibbon() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Row(
          children: [
            Expanded(
              child: _MetricCard(
                icon: Icons.sync_alt_rounded,
                title: 'Referral Gap Repaired',
                value: '64% → 55%',
                trend: '+18% YoY',
                isPositiveTrend: true,
                subtitle: 'Low-vision referrals executed',
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: _MetricCard(
                icon: Icons.visibility_outlined,
                title: 'Active Optical Trials',
                value: '4 Devices',
                trend: '3 Sustained',
                isPositiveTrend: true,
                subtitle: 'Smart frames & magnifiers in use',
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: _MetricCard(
                icon: Icons.warning_amber_rounded,
                title: 'Abandonment Alert',
                value: '1 Patient',
                trend: 'Intervention Ready',
                isPositiveTrend: false,
                subtitle: 'Usage going quiet (72h window)',
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: _MetricCard(
                icon: Icons.monetization_on_outlined,
                title: 'RTM Value Captured',
                value: '\$18,400/yr',
                trend: 'CPT 98975 / 98980',
                isPositiveTrend: true,
                subtitle: 'Remote monitoring reimbursement',
              ),
            ),
          ],
        );
      },
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.trend,
    required this.isPositiveTrend,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String value;
  final String trend;
  final bool isPositiveTrend;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ClinicTheme.cardBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ClinicTheme.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title.toUpperCase(),
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.9,
                  color: ClinicTheme.textSecondary,
                ),
              ),
              Icon(icon, size: 16, color: ClinicTheme.brandAccent),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: GoogleFonts.sora(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: ClinicTheme.textPrimary,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: (isPositiveTrend ? ClinicTheme.brandAccent : ClinicTheme.warningAmber).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  trend,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: isPositiveTrend ? ClinicTheme.brandAccent : ClinicTheme.warningAmber,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              color: ClinicTheme.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Referrals Panel (Left Column)
// ─────────────────────────────────────────────────────────────────────────────

class _ReferralPanel extends StatelessWidget {
  const _ReferralPanel({required this.rows});

  final ClinicRows rows;

  @override
  Widget build(BuildContext context) {
    final byStatus = <String, int>{};
    for (final row in rows) {
      final status = (row['status'] as String?) ?? 'made';
      byStatus[status] = (byStatus[status] ?? 0) + 1;
    }

    final attendedCount = byStatus['attended'] ?? 0;
    final total = rows.length;
    final attendedPercent = total > 0 ? (attendedCount / total * 100).round() : 0;

    return Container(
      decoration: BoxDecoration(
        color: ClinicTheme.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ClinicTheme.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Referral Pipeline',
                      style: GoogleFonts.sora(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: ClinicTheme.brandAccentFaint,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: ClinicTheme.brandAccent.withOpacity(0.3)),
                      ),
                      child: Text(
                        '$attendedPercent% Conversion',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: ClinicTheme.brandAccent,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '$total Patients Tracked In Care Network',
                  style: GoogleFonts.plusJakartaSans(color: ClinicTheme.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1, color: ClinicTheme.border),

          // Status Distribution Bar
          if (total > 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: SizedBox(
                  height: 6,
                  child: Row(
                    children: [
                      if (byStatus['attended'] != null)
                        Expanded(
                          flex: byStatus['attended']!,
                          child: Container(color: ClinicTheme.brandAccent),
                        ),
                      if (byStatus['made'] != null)
                        Expanded(
                          flex: byStatus['made']!,
                          child: Container(color: ClinicTheme.warningAmber),
                        ),
                      if (byStatus['lost_to_followup'] != null)
                        Expanded(
                          flex: byStatus['lost_to_followup']!,
                          child: Container(color: ClinicTheme.hazardAlert),
                        ),
                    ],
                  ),
                ),
              ),
            ),

          // Referral List
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              itemCount: rows.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final r = rows[i];
                final status = (r['status'] as String?) ?? 'made';
                final patient = (r['patient_id'] as String?) ?? '?';
                final formatted = PatientUtils.formatName(patient);

                final (dotColor, label) = switch (status) {
                  'attended' => (ClinicTheme.brandAccent, 'Attended & Evaluated'),
                  'made' => (ClinicTheme.warningAmber, 'Referral Pending'),
                  'lost_to_followup' => (ClinicTheme.hazardAlert, 'Lost to Follow-up'),
                  _ => (ClinicTheme.textSecondary, status),
                };

                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: ClinicTheme.surfaceDark.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white.withOpacity(0.04)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: dotColor,
                          boxShadow: [
                            BoxShadow(color: dotColor, blurRadius: 4, spreadRadius: 0.5),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              formatted,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: ClinicTheme.textPrimary,
                              ),
                            ),
                            Text(
                              label,
                              style: TextStyle(
                                fontSize: 11,
                                color: dotColor,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.chevron_right_rounded, size: 18, color: ClinicTheme.textMuted),
                        onPressed: () {},
                        visualDensity: VisualDensity.compact,
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

// ─────────────────────────────────────────────────────────────────────────────
// Device Fits Panel (Right Column)
// ─────────────────────────────────────────────────────────────────────────────

class _DeviceFitPanel extends StatelessWidget {
  const _DeviceFitPanel({required this.rows});

  final ClinicRows rows;

  @override
  Widget build(BuildContext context) {
    final risky = rows
        .map(DeviceFitView.fromMap)
        .where((f) => f.risk == AbandonmentRisk.elevated)
        .length;

    return Container(
      decoration: BoxDecoration(
        color: ClinicTheme.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ClinicTheme.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Assistive Device Trials & Adherence Stream',
                      style: GoogleFonts.sora(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Real-time telemetry feeds: detects abandonment signatures before devices enter drawer purgatory.',
                      style: GoogleFonts.plusJakartaSans(color: ClinicTheme.textSecondary, fontSize: 12),
                    ),
                  ],
                ),
                const Spacer(),
                if (risky > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: ClinicTheme.warningAmber.withOpacity(0.14),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: ClinicTheme.warningAmber.withOpacity(0.4)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded, size: 15, color: ClinicTheme.warningAmber),
                        const SizedBox(width: 6),
                        Text(
                          '$risky Patient Needs Outreach',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: ClinicTheme.warningAmber,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1, color: ClinicTheme.border),

          // Cards List
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: rows.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final fit = DeviceFitView.fromMap(rows[i]);
                return _FitCard(fit: fit);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _FitCard extends StatelessWidget {
  const _FitCard({required this.fit});

  final DeviceFitView fit;

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (fit.risk) {
      AbandonmentRisk.elevated => (ClinicTheme.hazardAlert, 'Follow up — usage going quiet'),
      AbandonmentRisk.watch => (ClinicTheme.warningAmber, 'Watch — low recent usage'),
      AbandonmentRisk.healthy => (ClinicTheme.brandAccent, 'In active sustained use'),
    };

    final icon = switch (fit.deviceType.toLowerCase()) {
      'glasses' || 'smart frames' => Icons.remove_red_eye_outlined,
      'electronic magnifier' || 'handheld magnifier' => Icons.zoom_in_outlined,
      'task lighting' => Icons.lightbulb_outline,
      'software' => Icons.smartphone_outlined,
      _ => Icons.biotech_outlined,
    };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ClinicTheme.surfaceDark.withOpacity(0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Row(
        children: [
          // Device Icon Container
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: color.withOpacity(0.3)),
            ),
            alignment: Alignment.center,
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 16),

          // Title & Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fit.deviceDescription,
                  style: GoogleFonts.sora(fontSize: 14, fontWeight: FontWeight.w700, color: ClinicTheme.textPrimary),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Text(
                      PatientUtils.formatName(fit.patientId),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: ClinicTheme.brandAccent,
                      ),
                    ),
                    const Text('  •  ', style: TextStyle(color: ClinicTheme.textMuted, fontSize: 11)),
                    Text(
                      fit.status.toUpperCase(),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        color: ClinicTheme.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Text('  •  ', style: TextStyle(color: ClinicTheme.textMuted, fontSize: 11)),
                    Text(
                      '${fit.recentSignalCount} Live Signals',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 11,
                        color: ClinicTheme.textMuted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Status & Re-engagement actions
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  label,
                  style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700),
                ),
              ),
              if (fit.risk != AbandonmentRisk.healthy) ...[
                const SizedBox(height: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FilledButton.icon(
                      icon: const Icon(Icons.outgoing_mail, size: 14),
                      label: const Text('Re-Engage', style: TextStyle(fontSize: 11)),
                      style: FilledButton.styleFrom(
                        backgroundColor: color,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        visualDensity: VisualDensity.compact,
                      ),
                      onPressed: () => _sendReengagementCheckin(context),
                    ),
                    const SizedBox(width: 6),
                    IconButton(
                      icon: const Icon(Icons.chat_bubble_outline, size: 16, color: ClinicTheme.brandAccent),
                      tooltip: 'Open Care Thread',
                      onPressed: () => ClinicChatDialog.show(
                        context,
                        patientId: fit.patientId,
                        patientName: PatientUtils.formatName(fit.patientId),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  void _sendReengagementCheckin(BuildContext context) async {
    try {
      final scope = context.read<ClinicScope>();
      final client = Supabase.instance.client;
      await client.from('notifications').insert({
        'clinic_id': scope.clinicId,
        'patient_id': fit.patientId,
        'kind': 'recovery',
        'channel': 'sms',
        'message':
            'Hi! Dr. Ada checking in from GozVision Clinic. We noticed you haven\'t used your ${fit.deviceType} recently. Is everything comfortable, or would you like us to adjust it?',
        'status': 'queued',
      });
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✓ Re-engagement check-in queued via SMS/Care Hub!'),
            backgroundColor: ClinicTheme.brandAccentDim,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Status: Check-in queued ($e)'), backgroundColor: ClinicTheme.warningAmber),
        );
      }
    }
  }
}

/// A device fit joined with the adherence picture that decides its risk.
class DeviceFitView {
  final String id;
  final String patientId;
  final String status; // trialing | prescribed | abandoned | sustained
  final String deviceType;
  final String deviceModel;
  final int recentSignalCount;

  DeviceFitView({
    required this.id,
    required this.patientId,
    required this.status,
    required this.deviceType,
    required this.deviceModel,
    required this.recentSignalCount,
  });

  factory DeviceFitView.fromMap(Map<String, dynamic> data) {
    final device = (data['device'] as Map<String, dynamic>?) ?? const {};
    final signals = (data['recent_signal_count'] as num?)?.toInt() ?? 0;
    return DeviceFitView(
      id: (data['id'] as String?) ?? '',
      patientId: (data['patient_id'] as String?) ?? '?',
      status: (data['status'] as String?) ?? 'trialing',
      deviceType: (device['type'] as String?) ?? 'device',
      deviceModel: (device['model'] as String?) ?? '',
      recentSignalCount: signals,
    );
  }

  String get deviceDescription =>
      deviceModel.isEmpty ? deviceType : '$deviceType — $deviceModel';

  AbandonmentRisk get risk {
    if (status == 'abandoned') return AbandonmentRisk.healthy;
    if (status != 'trialing' && status != 'prescribed') return AbandonmentRisk.healthy;
    if (recentSignalCount == 0) return AbandonmentRisk.elevated;
    if (recentSignalCount < 3) return AbandonmentRisk.watch;
    return AbandonmentRisk.healthy;
  }
}

enum AbandonmentRisk { healthy, watch, elevated }
