import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/clinic_theme.dart';
import '../data/clinic_scope.dart';

/// Front Desk — the schedule and intake queue (v0: the live appointment
/// list; recall/no-show automation lands next).
class FrontDeskPage extends StatelessWidget {
  const FrontDeskPage({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = context.watch<ClinicScope>();
    final appointments = scope.stream('appointments');

    if (appointments == null) {
      return const Center(child: CircularProgressIndicator(color: ClinicTheme.malachite));
    }

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Front Desk', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
          const Text('Schedule and intake queue.',
              style: TextStyle(color: ClinicTheme.textSecondary)),
          const SizedBox(height: 24),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: appointments,
              builder: (context, snap) {
                final docs = snap.data?.docs ?? const [];
                if (docs.isEmpty) {
                  return const Card(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Text(
                        'No appointments scheduled yet. Once the practice books one, it appears here.',
                        style: TextStyle(color: ClinicTheme.textSecondary),
                      ),
                    ),
                  );
                }
                return ListView.separated(
                  itemCount: docs.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final data = docs[i].data();
                    final patient = (data['patientId'] as String?) ?? '?';
                    final type = (data['type'] as String?) ?? 'appointment';
                    final status = (data['status'] as String?) ?? 'scheduled';
                    return Card(
                      child: ListTile(
                        leading: const Icon(Icons.event, color: ClinicTheme.malachite),
                        title: Text('$type — patient $patient'),
                        subtitle: Text('status: $status'),
                      ),
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
