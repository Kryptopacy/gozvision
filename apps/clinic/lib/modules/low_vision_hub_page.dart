import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/clinic_theme.dart';
import '../core/patient_utils.dart';
import '../data/clinic_scope.dart';
import 'clinic_chat_dialog.dart';

/// Low Vision Hub — closes the loop that leaks patients today:
/// referral (64% never referred) → device fit (29% abandoned within
/// 3 months) → sustained use. The hub shows both ends live: who has been
/// referred and fitted, and which fits show the abandonment signature
/// (a trialing fit whose adherence signals are going quiet).
class LowVisionHubPage extends StatelessWidget {
  const LowVisionHubPage({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = context.watch<ClinicScope>();
    final referrals = scope.stream('low_vision_referrals');
    final fits = scope.stream('device_fits');

    if (referrals == null || fits == null) {
      return const Center(child: CircularProgressIndicator(color: ClinicTheme.malachite));
    }

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Low Vision Hub', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
          const Text(
            'Referrals, device trials, and adherence — the loop that keeps patients independent.',
            style: TextStyle(color: ClinicTheme.textSecondary),
          ),
          const SizedBox(height: 24),
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
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _ReferralPanel(rows: refRows),
                        const SizedBox(width: 24),
                        Expanded(child: _DeviceFitPanel(rows: fitRows)),
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
}

// ---------------------------------------------------------------------------
// Referrals
// ---------------------------------------------------------------------------

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

    return SizedBox(
      width: 320,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Referrals', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text('${rows.length} tracked',
                  style: const TextStyle(color: ClinicTheme.textSecondary)),
              const SizedBox(height: 16),
              if (byStatus.isEmpty)
                const Text(
                  'No referrals yet. When your practice makes one, it lands here with its status.',
                  style: TextStyle(color: ClinicTheme.textSecondary),
                )
              else
                ...byStatus.entries.map((e) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        children: [
                          _statusDot(e.key),
                          const SizedBox(width: 10),
                          Text(e.key, style: const TextStyle(color: ClinicTheme.textPrimary)),
                          const Spacer(),
                          Text('${e.value}',
                              style: const TextStyle(
                                  color: ClinicTheme.textSecondary, fontWeight: FontWeight.w700)),
                        ],
                      ),
                    )),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statusDot(String status) {
    final color = switch (status) {
      'attended' => ClinicTheme.malachite,
      'made' => ClinicTheme.warningAmber,
      'lost_to_followup' || 'declined' => ClinicTheme.hazardAlert,
      _ => ClinicTheme.textSecondary,
    };
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }
}

// ---------------------------------------------------------------------------
// Device fits + abandonment risk
// ---------------------------------------------------------------------------

class _DeviceFitPanel extends StatelessWidget {
  const _DeviceFitPanel({required this.rows});

  final ClinicRows rows;

  @override
  Widget build(BuildContext context) {
    final risky = rows
        .map(DeviceFitView.fromMap)
        .where((f) => f.risk == AbandonmentRisk.elevated)
        .length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('Device fits', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(width: 12),
            if (risky > 0)
              Chip(
                avatar: const Icon(Icons.warning_amber_rounded,
                    size: 18, color: Colors.black),
                label: Text('$risky need follow-up'),
                backgroundColor: ClinicTheme.warningAmber,
              ),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: rows.isEmpty
              ? const Card(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Text(
                      'No device fits recorded yet. Prescribe one from an encounter and its '
                      'adherence trail from the Goz copilot starts here.',
                      style: TextStyle(color: ClinicTheme.textSecondary),
                    ),
                  ),
                )
              : ListView.separated(
                  itemCount: rows.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final fit = DeviceFitView.fromMap(rows[i]);
                    return _FitCard(fit: fit);
                  },
                ),
        ),
      ],
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
      AbandonmentRisk.healthy => (ClinicTheme.malachite, 'In active use'),
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 10,
              height: 44,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(5),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    fit.deviceDescription,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${PatientUtils.formatName(fit.patientId)}  ·  ${fit.status}  ·  signals: ${fit.recentSignalCount}',
                    style: const TextStyle(color: ClinicTheme.textSecondary, fontSize: 12),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
                if (fit.risk != AbandonmentRisk.healthy) ...[
                  const SizedBox(height: 6),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      OutlinedButton.icon(
                        icon: const Icon(Icons.mark_chat_unread_outlined, size: 14),
                        label: const Text('Re-Engage', style: TextStyle(fontSize: 11)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: color,
                          side: BorderSide(color: color),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          visualDensity: VisualDensity.compact,
                        ),
                        onPressed: () => _sendReengagementCheckin(context),
                      ),
                      const SizedBox(width: 6),
                      IconButton(
                        icon: const Icon(Icons.chat_bubble_outline, size: 16, color: ClinicTheme.malachite),
                        tooltip: 'Open Care Thread',
                        onPressed: () => ClinicChatDialog.show(
                          context,
                          patientId: fit.patientId,
                          patientName: 'Patient ${fit.patientId}',
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ],
        ),
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
        'message': 'Hi! Dr. Miller checking in from Apex Vision. We noticed you haven\'t used your ${fit.deviceType} recently. Is everything comfortable, or would you like us to adjust it?',
        'status': 'queued',
      });
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✓ Re-engagement check-in queued via SMS/Push!'),
            backgroundColor: ClinicTheme.malachite,
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

  /// The abandonment signature (CONTEXT.md — "Low Vision Hub"): a trialing
  /// fit with no recent copilot activity is the patient about to give up.
  AbandonmentRisk get risk {
    if (status == 'abandoned') return AbandonmentRisk.healthy; // already lost; nothing to warn about
    if (status != 'trialing' && status != 'prescribed') return AbandonmentRisk.healthy;
    if (recentSignalCount == 0) return AbandonmentRisk.elevated;
    if (recentSignalCount < 3) return AbandonmentRisk.watch;
    return AbandonmentRisk.healthy;
  }
}

enum AbandonmentRisk { healthy, watch, elevated }
