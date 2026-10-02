import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/clinic_theme.dart';
import '../data/clinic_scope.dart';

/// Insights — practice analytics (v0: live counters over the clinic's own
/// collections; deeper aggregation lands with the backend jobs).
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
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: fits,
            builder: (context, fitsSnap) {
              return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: referrals,
                builder: (context, refSnap) {
                  final fitDocs = fitsSnap.data?.docs ?? const [];
                  final refDocs = refSnap.data?.docs ?? const [];

                  final trialing =
                      fitDocs.where((d) => d.data()['status'] == 'trialing').length;
                  final abandoned =
                      fitDocs.where((d) => d.data()['status'] == 'abandoned').length;
                  final sustained =
                      fitDocs.where((d) => d.data()['status'] == 'sustained').length;
                  final attended =
                      refDocs.where((d) => d.data()['status'] == 'attended').length;

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
                          value: '$attended / ${refDocs.length}'),
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
