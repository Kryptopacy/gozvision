import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/clinic_theme.dart';
import '../data/clinic_scope.dart';

/// Insights — practice analytics (v0: live counters over the clinic's own
/// tables; deeper aggregation lands with SQL views — the reason the platform
/// sits on Postgres, see ADR-0003).
class InsightsPage extends StatelessWidget {
  const InsightsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = context.watch<ClinicScope>();
    final fits = scope.stream('device_fits');
    final referrals = scope.stream('low_vision_referrals');

    if (fits == null || referrals == null) {
      return const Center(child: CircularProgressIndicator(color: ClinicTheme.malachite));
    }

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Insights', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
          const Text('Where your low-vision loop leaks — and where it holds.',
              style: TextStyle(color: ClinicTheme.textSecondary)),
          const SizedBox(height: 24),
          StreamBuilder<ClinicRows>(
            stream: fits,
            builder: (context, fitsSnap) {
              return StreamBuilder<ClinicRows>(
                stream: referrals,
                builder: (context, refSnap) {
                  final fitRows = fitsSnap.data ?? const [];
                  final refRows = refSnap.data ?? const [];

                  final trialing =
                      fitRows.where((d) => d['status'] == 'trialing').length;
                  final abandoned =
                      fitRows.where((d) => d['status'] == 'abandoned').length;
                  final sustained =
                      fitRows.where((d) => d['status'] == 'sustained').length;
                  final attended =
                      refRows.where((d) => d['status'] == 'attended').length;

                  return Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: [
                      _StatCard(
                          label: 'Device fits trialing', value: '$trialing'),
                      _StatCard(label: 'Sustained use', value: '$sustained'),
                      _StatCard(
                          label: 'Abandoned',
                          value: '$abandoned',
                          accent: abandoned > 0
                              ? ClinicTheme.hazardAlert
                              : ClinicTheme.malachite),
                      _StatCard(
                          label: 'Referrals attended',
                          value: '$attended / ${refRows.length}'),
                    ],
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value, this.accent});

  final String label;
  final String value;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value,
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    color: accent ?? ClinicTheme.malachite,
                  )),
              const SizedBox(height: 4),
              Text(label, style: const TextStyle(color: ClinicTheme.textSecondary)),
            ],
          ),
        ),
      ),
    );
  }
}
