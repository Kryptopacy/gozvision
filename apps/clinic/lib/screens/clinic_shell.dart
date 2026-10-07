import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/clinic_theme.dart';
import '../data/clinic_scope.dart';
import '../modules/front_desk_page.dart';
import '../modules/insights_page.dart';
import '../modules/low_vision_hub_page.dart';
import '../modules/scribe_page.dart';
import '../modules/clinic_chat_dialog.dart';

/// The clinic suite shell: one rail, four modules. The Low Vision Hub is
/// the flagship — it closes the referral → device fit → adherence loop.
class ClinicShell extends StatefulWidget {
  const ClinicShell({super.key});

  @override
  State<ClinicShell> createState() => _ClinicShellState();
}

class _ClinicShellState extends State<ClinicShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final scope = context.watch<ClinicScope>();

    if (!scope.resolved) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: ClinicTheme.malachite)),
      );
    }
    if (scope.clinicId == null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'No clinic linked to this account.',
                style: TextStyle(color: ClinicTheme.textPrimary),
              ),
              const SizedBox(height: 8),
              Text(
                'Ask your practice owner to assign you in profiles.clinic_id.',
                style: const TextStyle(color: ClinicTheme.textSecondary),
              ),
              const SizedBox(height: 24),
              TextButton(
                onPressed: () => Supabase.instance.client.auth.signOut(),
                child: const Text('Sign out'),
              ),
            ],
          ),
        ),
      );
    }

    final pages = const [
      LowVisionHubPage(),
      FrontDeskPage(),
      ScribePage(),
      InsightsPage(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text('GozVision',
                style: TextStyle(color: ClinicTheme.malachite, fontWeight: FontWeight.w800)),
            Text('  ·  Clinic Suite',
                style: const TextStyle(color: ClinicTheme.textSecondary)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.chat_bubble_outline, color: ClinicTheme.malachite),
            tooltip: 'In-App Care Threads (Push & Email Active)',
            onPressed: () {
              ClinicChatDialog.show(
                context,
                patientId: 'demo_patient_001',
                patientName: 'Eleanor Vance (AMD Trial)',
              );
            },
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16, left: 8),
            child: Center(
              child: Text(
                '${scope.displayName}  ·  ${scope.role}',
                style: const TextStyle(color: ClinicTheme.textSecondary),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: ClinicTheme.textSecondary),
            tooltip: 'Sign out',
            onPressed: () => Supabase.instance.client.auth.signOut(),
          ),
        ],
      ),
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _index,
            onDestinationSelected: (i) => setState(() => _index = i),
            labelType: NavigationRailLabelType.all,
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.visibility_outlined),
                selectedIcon: Icon(Icons.visibility),
                label: Text('Low Vision Hub'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.event_outlined),
                selectedIcon: Icon(Icons.event),
                label: Text('Front Desk'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.edit_note_outlined),
                selectedIcon: Icon(Icons.edit_note),
                label: Text('Scribe'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.insights_outlined),
                selectedIcon: Icon(Icons.insights),
                label: Text('Insights'),
              ),
            ],
          ),
          const VerticalDivider(width: 1, color: ClinicTheme.border),
          Expanded(child: pages[_index]),
        ],
      ),
    );
  }
}
