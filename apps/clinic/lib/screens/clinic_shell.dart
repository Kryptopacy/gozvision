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
import '../modules/doctor_reference_dialog.dart';
import '../modules/doctor_profile_page.dart';
import '../modules/clinic_directory_page.dart';
import '../modules/optical_storefront_page.dart';
import '../modules/developer_console_page.dart';

/// GozVision Clinic Suite — Enterprise Multi-Tenant Clinical Shell.
///
/// Clean, dark clinical obsidian aesthetics with frosted glass surfaces,
/// intelligent patient queue badges, instant doctor reference RAG dialogs,
/// and responsive sidebar navigation.
class ClinicShell extends StatefulWidget {
  const ClinicShell({super.key});

  @override
  State<ClinicShell> createState() => _ClinicShellState();
}

class _ClinicShellState extends State<ClinicShell> {
  int _index = 0;
  bool _initializedIndex = false;

  @override
  Widget build(BuildContext context) {
    final scope = context.watch<ClinicScope>();

    if (!_initializedIndex && scope.resolved) {
      if (scope.isDeveloper) {
        _index = 7; // Open Developer Console directly for developer
      } else if (scope.isStaff && !scope.isClinicManager) {
        _index = 1; // Open Front Desk directly for staff
      }
      _initializedIndex = true;
    }

    if (!scope.resolved) {
      return const Scaffold(
        backgroundColor: ClinicTheme.obsidian,
        body: Center(
          child: CircularProgressIndicator(color: ClinicTheme.malachite),
        ),
      );
    }

    if (scope.clinicId == null && !scope.isDeveloper) {
      return Scaffold(
        backgroundColor: ClinicTheme.obsidian,
        body: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 420),
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: ClinicTheme.cardBackground,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: ClinicTheme.border),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.domain_disabled_rounded, size: 48, color: ClinicTheme.warningAmber),
                const SizedBox(height: 16),
                const Text(
                  'No Practice Linked',
                  style: TextStyle(color: ClinicTheme.textPrimary, fontSize: 20, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Your profile is not yet assigned to an active clinic tenant. Ask your practice administrator to link your account.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: ClinicTheme.textSecondary, fontSize: 13),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: ClinicTheme.malachite, foregroundColor: Colors.black),
                  icon: const Icon(Icons.logout, size: 16),
                  label: const Text('Sign Out'),
                  onPressed: () => Supabase.instance.client.auth.signOut(),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final pages = const [
      LowVisionHubPage(),
      FrontDeskPage(),
      ScribePage(),
      InsightsPage(),
      DoctorProfilePage(),
      ClinicDirectoryPage(),
      OpticalStorefrontPage(),
      DeveloperConsolePage(),
    ];

    return Scaffold(
      backgroundColor: ClinicTheme.obsidian,
      appBar: _buildTopUtilityBar(context, scope),
      body: Row(
        children: [
          // Professional B2B Sidebar
          _buildSidebar(context, scope),
          const VerticalDivider(width: 1, thickness: 1, color: ClinicTheme.border),
          // Main Clinical Module Content Area with smooth transition
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: KeyedSubtree(
                key: ValueKey<int>(_index),
                child: pages[_index],
              ),
            ),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildTopUtilityBar(BuildContext context, ClinicScope scope) {
    return AppBar(
      backgroundColor: ClinicTheme.obsidian,
      elevation: 0,
      titleSpacing: 20,
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: ClinicTheme.malachiteFaint,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: ClinicTheme.malachite.withOpacity(0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: ClinicTheme.malachite,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'TENANT: ${scope.clinicId?.toUpperCase() ?? "CLINIC"}',
                  style: const TextStyle(
                    color: ClinicTheme.malachite,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          const Text(
            'GozVision Practice Suite',
            style: TextStyle(
              color: ClinicTheme.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
      actions: [
        // Clinical Copilot RAG Guidelines Button
        FilledButton.tonalIcon(
          style: FilledButton.styleFrom(
            backgroundColor: ClinicTheme.cardBackground,
            foregroundColor: ClinicTheme.malachite,
            side: const BorderSide(color: ClinicTheme.border),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          ),
          icon: const Icon(Icons.menu_book_outlined, size: 16),
          label: const Text('Clinical Copilot RAG', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
          onPressed: () => DoctorReferenceDialog.show(context),
        ),
        const SizedBox(width: 10),
        // In-App Care Thread Chat
        IconButton(
          icon: const Badge(
            backgroundColor: ClinicTheme.malachite,
            smallSize: 8,
            child: Icon(Icons.chat_bubble_outline_rounded, color: ClinicTheme.textPrimary, size: 20),
          ),
          tooltip: 'In-App Care Threads (Active)',
          onPressed: () {
            ClinicChatDialog.show(
              context,
              patientId: 'demo_patient_001',
              patientName: 'Eleanor Vance (AMD Trial)',
            );
          },
        ),
        const SizedBox(width: 6),
        // Practitioner Profile Pill
        InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => setState(() => _index = 4),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: ClinicTheme.cardBackground,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: ClinicTheme.border),
            ),
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 12,
                  backgroundColor: ClinicTheme.malachiteFaint,
                  child: Icon(Icons.person, color: ClinicTheme.malachite, size: 14),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      scope.displayName,
                      style: const TextStyle(
                        color: ClinicTheme.textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      scope.role.toUpperCase(),
                      style: const TextStyle(
                        color: ClinicTheme.malachiteDim,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        IconButton(
          icon: const Icon(Icons.logout_rounded, color: ClinicTheme.textSecondary, size: 19),
          tooltip: 'Sign Out',
          onPressed: () => Supabase.instance.client.auth.signOut(),
        ),
        const SizedBox(width: 14),
      ],
    );
  }

  Widget _buildSidebar(BuildContext context, ClinicScope scope) {
    return Container(
      width: 230,
      color: ClinicTheme.obsidian,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Sidebar Practice Brand
          Padding(
            padding: const EdgeInsets.only(left: 8, bottom: 18),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: ClinicTheme.malachite,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: ClinicTheme.malachite.withOpacity(0.3),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(Icons.remove_red_eye_rounded, size: 16, color: Colors.black),
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  'GozVision',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 17,
                    letterSpacing: -0.3,
                  ),
                ),
              ],
            ),
          ),

          if (scope.isDeveloper) ...[
            const Padding(
              padding: EdgeInsets.only(left: 8, bottom: 8),
              child: Text(
                'PLATFORM ROOT',
                style: TextStyle(
                  color: ClinicTheme.malachite,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            _buildNavItem(
              index: 7,
              icon: Icons.terminal_rounded,
              activeIcon: Icons.terminal,
              label: 'Developer Console',
              badgeText: 'Root',
              badgeColor: ClinicTheme.malachite,
            ),
            const SizedBox(height: 16),
          ],

          const Padding(
            padding: EdgeInsets.only(left: 8, bottom: 8),
            child: Text(
              'CLINICAL MODULES',
              style: TextStyle(
                color: ClinicTheme.textSecondary,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.0,
              ),
            ),
          ),

          if (!scope.isStaff || scope.isClinicManager) ...[
            _buildNavItem(
              index: 0,
              icon: Icons.visibility_outlined,
              activeIcon: Icons.visibility,
              label: 'Low Vision Hub',
              badgeText: 'Live',
              badgeColor: ClinicTheme.malachite,
            ),
          ],
          _buildNavItem(
            index: 1,
            icon: Icons.calendar_month_outlined,
            activeIcon: Icons.calendar_month,
            label: 'Front Desk',
          ),
          if (!scope.isStaff || scope.isClinicManager) ...[
            _buildNavItem(
              index: 2,
              icon: Icons.edit_note_rounded,
              activeIcon: Icons.edit_note_rounded,
              label: 'Scribe Studio',
              badgeText: 'Drafts',
              badgeColor: ClinicTheme.warningAmber,
            ),
            _buildNavItem(
              index: 3,
              icon: Icons.insights_rounded,
              activeIcon: Icons.insights_rounded,
              label: 'Practice Insights',
            ),
          ],

          const SizedBox(height: 16),
          const Padding(
            padding: EdgeInsets.only(left: 8, bottom: 8),
            child: Text(
              'PRACTICE ROSTER',
              style: TextStyle(
                color: ClinicTheme.textSecondary,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.0,
              ),
            ),
          ),

          if (!scope.isStaff || scope.isClinicManager) ...[
            _buildNavItem(
              index: 4,
              icon: Icons.badge_outlined,
              activeIcon: Icons.badge,
              label: 'Doctor Profile',
            ),
          ],
          _buildNavItem(
            index: 5,
            icon: Icons.domain_outlined,
            activeIcon: Icons.domain,
            label: 'Clinic Directory',
          ),

          const SizedBox(height: 16),
          const Padding(
            padding: EdgeInsets.only(left: 8, bottom: 8),
            child: Text(
              'COMMERCE & DISPENSARY',
              style: TextStyle(
                color: ClinicTheme.textSecondary,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.0,
              ),
            ),
          ),
          _buildNavItem(
            index: 6,
            icon: Icons.storefront_outlined,
            activeIcon: Icons.storefront_rounded,
            label: 'Optical Dispensary',
            badgeText: 'Bachs',
            badgeColor: ClinicTheme.malachite,
          ),

          const Spacer(),

          // Bottom Quick Status Indicator
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: ClinicTheme.cardBackground,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: ClinicTheme.border),
            ),
            child: Row(
              children: [
                const Icon(Icons.shield_outlined, size: 16, color: ClinicTheme.malachite),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Text(
                        'EHR Sync Active',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white),
                      ),
                      Text(
                        'Epic & Eyefinity Bridge',
                        style: TextStyle(fontSize: 9.5, color: ClinicTheme.textSecondary),
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

  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required IconData activeIcon,
    required String label,
    String? badgeText,
    Color? badgeColor,
  }) {
    final isSelected = _index == index;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: InkWell(
        onTap: () => setState(() => _index = index),
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          decoration: BoxDecoration(
            color: isSelected ? ClinicTheme.malachiteFaint : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? ClinicTheme.malachite.withOpacity(0.3) : Colors.transparent,
            ),
          ),
          child: Row(
            children: [
              Icon(
                isSelected ? activeIcon : icon,
                size: 19,
                color: isSelected ? ClinicTheme.malachite : ClinicTheme.textSecondary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? Colors.white : ClinicTheme.textSecondary,
                  ),
                ),
              ),
              if (badgeText != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: (badgeColor ?? ClinicTheme.malachite).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: (badgeColor ?? ClinicTheme.malachite).withOpacity(0.4),
                    ),
                  ),
                  child: Text(
                    badgeText,
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      color: badgeColor ?? ClinicTheme.malachite,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
