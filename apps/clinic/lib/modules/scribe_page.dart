import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/clinic_theme.dart';
import '../data/clinic_scope.dart';

/// Scribe — ambient documentation drafts (v0: the draft queue; the exam
/// conversation becomes a draft chart for practitioner review — never
/// auto-final, per CONTEXT.md "Grounding over generation").
class ScribePage extends StatelessWidget {
  const ScribePage({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = context.watch<ClinicScope>();
    final encounters = scope.stream('encounters');

    if (encounters == null) {
      return const Center(child: CircularProgressIndicator(color: ClinicTheme.malachite));
    }

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Scribe', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
          const Text('Ambient documentation drafts awaiting your review.',
              style: TextStyle(color: ClinicTheme.textSecondary)),
          const SizedBox(height: 24),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: encounters,
              builder: (context, snap) {
                final docs = snap.data?.docs ?? const [];
                if (docs.isEmpty) {
                  return const Card(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Text(
                        'No encounters yet. Start one from an appointment and the ambient '
                        'scribe drafts its chart here.',
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
                    final scribe = (data['scribe_draft'] as Map<String, dynamic>?) ?? const {};
                    final draftStatus = (scribe['status'] as String?) ?? 'none';
                    final type = (data['type'] as String?) ?? 'encounter';
                    return Card(
                      child: ListTile(
                        leading: Icon(
                          draftStatus == 'reviewed'
                              ? Icons.task_alt
                              : Icons.pending_outlined,
                          color: draftStatus == 'reviewed'
                              ? ClinicTheme.malachite
                              : ClinicTheme.warningAmber,
                        ),
                        title: Text('$type — patient ${data['patientId'] ?? '?'}'),
                        subtitle: Text('scribe draft: $draftStatus'),
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
