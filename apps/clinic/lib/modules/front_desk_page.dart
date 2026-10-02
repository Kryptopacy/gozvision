import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/clinic_theme.dart';
import '../data/clinic_scope.dart';

/// Front Desk — the schedule plus the recall/no-show outreach queue.
///
/// The queue is computed by the backend recall engine
/// (`python -m gozvision_agent.recall --clinic <id>`), which writes
/// `notifications` rows (status: queued). A delivery job drains them; when
/// one does, it stamps provider + sent_at. Channel today is SMS-shaped; the
/// provider (AWS End User Messaging, WhatsApp, SES) is a swap-in seam.
class FrontDeskPage extends StatelessWidget {
  const FrontDeskPage({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = context.watch<ClinicScope>();
    final appointments = scope.stream('appointments');
    final outreach = scope.stream('notifications');

    if (appointments == null || outreach == null) {
      return const Center(child: CircularProgressIndicator(color: ClinicTheme.malachite));
    }

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Front Desk', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
          const Text('Schedule and the recall / no-show outreach queue.',
              style: TextStyle(color: ClinicTheme.textSecondary)),
          const SizedBox(height: 24),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: StreamBuilder<ClinicRows>(
                    stream: appointments,
                    builder: (context, snap) {
                      final rows = (snap.data ?? const [])
                          .toList()
                        ..sort((a, b) => (a['start_at'] as String? ?? '')
                            .compareTo(b['start_at'] as String? ?? ''));
                      if (rows.isEmpty) {
                        return const Card(
                          child: Padding(
                            padding: EdgeInsets.all(20),
                            child: Text(
                              'No appointments yet — seed the demo world or book one.',
                              style: TextStyle(color: ClinicTheme.textSecondary),
                            ),
                          ),
                        );
                      }
                      return ListView.separated(
                        itemCount: rows.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, i) {
                          final data = rows[i];
                          final status = (data['status'] as String?) ?? 'scheduled';
                          final start = data['start_at'] as String?;
                          return Card(
                            child: ListTile(
                              leading: Icon(
                                switch (status) {
                                  'confirmed' => Icons.check_circle_outline,
                                  'no_show' => Icons.warning_amber_rounded,
                                  'completed' => Icons.done_all_outlined,
                                  _ => Icons.event_outlined,
                                },
                                color: switch (status) {
                                  'confirmed' => ClinicTheme.malachite,
                                  'no_show' => ClinicTheme.hazardAlert,
                                  _ => ClinicTheme.textSecondary,
                                },
                              ),
                              title: Text(
                                  '${data['type'] ?? 'appointment'} — patient ${data['patient_id'] ?? '?'}'),
                              subtitle: Text(
                                  'status: $status${start != null ? '  ·  starts ${_fmt(start)}' : ''}'),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  flex: 2,
                  child: StreamBuilder<ClinicRows>(
                    stream: outreach,
                    builder: (context, snap) {
                      final rows = (snap.data ?? const [])
                          .toList()
                        ..sort((a, b) => (b['created_at'] as String? ?? '')
                            .compareTo(a['created_at'] as String? ?? ''));
                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.campaign_outlined,
                                      color: ClinicTheme.malachite, size: 20),
                                  const SizedBox(width: 8),
                                  Text('Outreach queue',
                                      style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          color: ClinicTheme.textPrimary)),
                                  const Spacer(),
                                  Text('${rows.length}',
                                      style: const TextStyle(
                                          color: ClinicTheme.textSecondary)),
                                ],
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Recall engine output — reminders, no-show recovery, '
                                'and annual recalls awaiting delivery.',
                                style: TextStyle(
                                    color: ClinicTheme.textSecondary, fontSize: 12),
                              ),
                              const SizedBox(height: 12),
                              if (rows.isEmpty)
                                const Text(
                                  'Queue empty. Run the sweep:\n'
                                  'python -m gozvision_agent.recall --clinic <id>',
                                  style: TextStyle(
                                      color: ClinicTheme.textSecondary, fontSize: 12),
                                )
                              else
                                Expanded(
                                  child: ListView.separated(
                                    itemCount: rows.length,
                                    separatorBuilder: (_, _) => const Divider(
                                        color: ClinicTheme.border, height: 16),
                                    itemBuilder: (context, i) {
                                      final n = rows[i];
                                      final kind = (n['kind'] as String?) ?? 'recall';
                                      final status = (n['status'] as String?) ?? 'queued';
                                      return Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Text(kind.toUpperCase(),
                                                  style: TextStyle(
                                                      fontSize: 11,
                                                      fontWeight: FontWeight.w800,
                                                      color: switch (kind) {
                                                        'recovery' => ClinicTheme.hazardAlert,
                                                        'reminder' => ClinicTheme.warningAmber,
                                                        _ => ClinicTheme.malachite,
                                                      })),
                                              const Spacer(),
                                              Text(status,
                                                  style: const TextStyle(
                                                      fontSize: 11,
                                                      color: ClinicTheme.textSecondary)),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Text((n['message'] as String?) ?? '',
                                              style: const TextStyle(
                                                  fontSize: 12,
                                                  color: ClinicTheme.textPrimary)),
                                        ],
                                      );
                                    },
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _fmt(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.month}/${dt.day} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }
}
