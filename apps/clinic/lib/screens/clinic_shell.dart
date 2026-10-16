import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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
import '../modules/clinic_crm_page.dart';
import '../modules/ehr_hub_page.dart';

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
          child: CircularProgressIndicator(color: ClinicTheme.brandAccent),
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
                  style: FilledButton.styleFrom(backgroundColor: ClinicTheme.brandAccent, foregroundColor: ClinicTheme.obsidian),
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
      ClinicCrmPage(),
      EhrHubPage(),
    ];

    return Scaffold(
      backgroundColor: ClinicTheme.obsidian,
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Professional Full-Height B2B Sidebar
          _buildSidebar(context, scope),
          const VerticalDivider(width: 1, thickness: 1, color: ClinicTheme.border),
          // Main Clinical Module Content Area
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                color: ClinicTheme.obsidian,
                gradient: RadialGradient(
                  center: Alignment(0.4, -0.8),
                  radius: 1.4,
                  colors: [
                    Color(0x1838BDF8),
                    Color(0xFF08090C),
                  ],
                ),
              ),
              child: Column(
                children: [
                  _buildContentHeader(context, scope),
                  const Divider(height: 1, thickness: 1, color: ClinicTheme.border),
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
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContentHeader(BuildContext context, ClinicScope scope) {
    const titles = [
      'Low Vision Hub',
      'Front Desk',
      'Scribe Studio',
      'Practice Insights',
      'Doctor Profile',
      'Clinic Directory',
      'Optical Dispensary',
      'Developer Console',
      'Patient Recall & CRM',
      'EHR & Interoperability Hub',
    ];

    final currentTitle = (_index >= 0 && _index < titles.length) ? titles[_index] : 'Practice Suite';

    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      color: ClinicTheme.obsidian,
      child: Row(
        children: [
          // Executive Breadcrumb Trail
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Practice Suite',
                style: GoogleFonts.plusJakartaSans(
                  color: ClinicTheme.textMuted,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  '/',
                  style: GoogleFonts.plusJakartaSans(
                    color: ClinicTheme.textMuted.withValues(alpha: 0.5),
                    fontSize: 13,
                  ),
                ),
              ),
              Text(
                currentTitle,
                style: GoogleFonts.sora(
                  color: ClinicTheme.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
          const Spacer(),
          // Clinical Copilot RAG Guidelines Button
          FilledButton.tonalIcon(
            style: FilledButton.styleFrom(
              backgroundColor: ClinicTheme.cardBackground,
              foregroundColor: ClinicTheme.brandAccent,
              side: const BorderSide(color: ClinicTheme.border),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            icon: const Icon(Icons.auto_stories_outlined, size: 16),
            label: Text(
              'Clinical Copilot RAG',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            onPressed: () => DoctorReferenceDialog.show(context),
          ),
          const SizedBox(width: 10),
          // In-App Care Thread Chat Button
          IconButton(
            style: IconButton.styleFrom(
              backgroundColor: ClinicTheme.cardBackground,
              side: const BorderSide(color: ClinicTheme.border),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            icon: const Badge(
              backgroundColor: ClinicTheme.brandAccent,
              smallSize: 7,
              child: Icon(Icons.chat_bubble_outline_rounded, color: ClinicTheme.textSecondary, size: 18),
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
        ],
      ),
    );
  }

  Widget _buildSidebar(BuildContext context, ClinicScope scope) {
    return Container(
      width: 256,
      color: ClinicTheme.obsidian,
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Sidebar Practice Brand
          Padding(
            padding: const EdgeInsets.only(left: 6, bottom: 16),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.asset(
                    'assets/gozvision_lens.png',
                    width: 28,
                    height: 28,
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'GozVision',
                  style: GoogleFonts.sora(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                    letterSpacing: -0.4,
                  ),
                ),
              ],
            ),
          ),

          // Workspace Practice Card & Location Switcher
          InkWell(
            onTap: () => _showPracticeLocationModal(context, scope),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              margin: const EdgeInsets.only(bottom: 18),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: ClinicTheme.cardBackground,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: ClinicTheme.border),
              ),
              child: Row(
                children: [
                  Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: ClinicTheme.brandAccentFaint,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Center(
                      child: Text(
                        scope.countryFlag,
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          scope.clinicName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(
                            color: ClinicTheme.textPrimary,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Row(
                          children: [
                            Text(
                              '${scope.stateOrCity}, ${scope.country}',
                              style: GoogleFonts.plusJakartaSans(
                                color: ClinicTheme.brandAccent,
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(Icons.edit, size: 9, color: ClinicTheme.textMuted),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          if (scope.isDeveloper) ...[
            const Padding(
              padding: EdgeInsets.only(left: 8, bottom: 8),
              child: Text(
                'PLATFORM ROOT',
                style: TextStyle(
                  color: ClinicTheme.brandAccent,
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
            ),
            _buildNavItem(
              index: 3,
              icon: Icons.insights_rounded,
              activeIcon: Icons.insights_rounded,
              label: 'Practice Insights',
            ),
            _buildNavItem(
              index: 9,
              icon: Icons.sync_alt_rounded,
              activeIcon: Icons.sync_alt_rounded,
              label: 'EHR & Data Bridge',
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
          ),

          const SizedBox(height: 16),
          const Padding(
            padding: EdgeInsets.only(left: 8, bottom: 8),
            child: Text(
              'PATIENT ENGAGEMENT & CRM',
              style: TextStyle(
                color: ClinicTheme.textSecondary,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.0,
              ),
            ),
          ),
          _buildNavItem(
            index: 8,
            icon: Icons.people_alt_outlined,
            activeIcon: Icons.people_alt_rounded,
            label: 'Patient Recall & CRM',
          ),

          const Spacer(),

          // Practitioner Profile Card
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: ClinicTheme.cardBackground,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: ClinicTheme.border),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => setState(() => _index = 4),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 14,
                        backgroundColor: ClinicTheme.brandAccentFaint,
                        child: const Icon(Icons.person, color: ClinicTheme.brandAccent, size: 16),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              scope.displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.plusJakartaSans(
                                color: ClinicTheme.textPrimary,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              scope.role.toUpperCase(),
                              style: GoogleFonts.plusJakartaSans(
                                color: ClinicTheme.brandAccentDim,
                                fontSize: 9.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.logout_rounded, color: ClinicTheme.textMuted, size: 16),
                        tooltip: 'Sign Out',
                        onPressed: () => Supabase.instance.client.auth.signOut(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Bottom EHR Status Indicator (Interactive Shortcut)
          Container(
            decoration: BoxDecoration(
              color: ClinicTheme.cardBackground.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: _index == 9 ? ClinicTheme.brandAccent : ClinicTheme.border,
                width: _index == 9 ? 1.5 : 1.0,
              ),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => setState(() => _index = 9),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.shield_outlined, size: 14, color: ClinicTheme.brandAccent),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'EHR Bridge Active',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: _index == 9 ? ClinicTheme.brandAccent : ClinicTheme.textPrimary,
                              ),
                            ),
                            Text(
                              'Epic & Eyefinity Sync (Click to view)',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 9,
                                color: ClinicTheme.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios_rounded, size: 10, color: ClinicTheme.textMuted),
                    ],
                  ),
                ),
              ),
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
            color: isSelected ? ClinicTheme.brandAccentFaint : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? ClinicTheme.brandAccent.withValues(alpha: 0.3) : Colors.transparent,
            ),
          ),
          child: Row(
            children: [
              Icon(
                isSelected ? activeIcon : icon,
                size: 19,
                color: isSelected ? ClinicTheme.brandAccent : ClinicTheme.textSecondary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.plusJakartaSans(
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
                    color: (badgeColor ?? ClinicTheme.brandAccent).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: (badgeColor ?? ClinicTheme.brandAccent).withValues(alpha: 0.4),
                    ),
                  ),
                  child: Text(
                    badgeText,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      color: badgeColor ?? ClinicTheme.brandAccent,
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

  void _showPracticeLocationModal(BuildContext context, ClinicScope scope) {
    String selectedCountry = scope.country;
    String selectedCity = scope.stateOrCity;
    final nameCtrl = TextEditingController(text: scope.clinicName);

    final presets = [
      {
        'country': 'Nigeria',
        'city': 'Lagos',
        'flag': '🇳🇬',
        'subtitle': 'NOA / ODORBN Standard • Reliance & AXA HMO • NGN (₦)',
      },
      {
        'country': 'Nigeria',
        'city': 'Abuja',
        'flag': '🇳🇬',
        'subtitle': 'Teaching Hospital Manila Folder • NHIA Social Health • NGN (₦)',
      },
      {
        'country': 'Ghana',
        'city': 'Accra',
        'flag': '🇬🇭',
        'subtitle': 'Ghana Optometric Standard • NHIS Optical • GHS (GH₵)',
      },
      {
        'country': 'Kenya',
        'city': 'Nairobi',
        'flag': '🇰🇪',
        'subtitle': 'Ophthalmic Clinical Card • SHA / SHIF Tariffs • KES (KSh)',
      },
      {
        'country': 'South Africa',
        'city': 'Johannesburg',
        'flag': '🇿🇦',
        'subtitle': 'Council for Medical Schemes • Discovery Health PMB • ZAR (R)',
      },
      {
        'country': 'United Kingdom',
        'city': 'London',
        'flag': '🇬🇧',
        'subtitle': 'NHS GOS 18 Optical Voucher • Metropolitan 4-Quadrant • GBP (£)',
      },
      {
        'country': 'United States',
        'city': 'New York',
        'flag': '🇺🇸',
        'subtitle': 'Medicare CMS RTM (CPT 98975 / 98980) • HIPAA BAA • USD (\$)',
      },
    ];

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return Dialog(
              backgroundColor: ClinicTheme.obsidianElevated,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: ClinicTheme.border),
              ),
              child: Container(
                width: 620,
                padding: const EdgeInsets.all(24),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: ClinicTheme.brandAccentFaint,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.public_rounded, color: ClinicTheme.brandAccent, size: 22),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Practice Location & Automatic Regional Context',
                                  style: GoogleFonts.sora(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'GozVision automatically context-switches paper forms, currencies, HMO tariffs, and regulatory compliance based on your practice location.',
                                  style: GoogleFonts.plusJakartaSans(fontSize: 11.5, color: ClinicTheme.textSecondary),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: ClinicTheme.textMuted, size: 18),
                            onPressed: () => Navigator.of(dialogCtx).pop(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),

                      Text('Practice / Hospital Name:', style: GoogleFonts.plusJakartaSans(fontSize: 11.5, color: ClinicTheme.textSecondary, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: nameCtrl,
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                        decoration: InputDecoration(
                          isDense: true,
                          filled: true,
                          fillColor: ClinicTheme.surfaceDark,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: ClinicTheme.border)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: ClinicTheme.border)),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: ClinicTheme.brandAccent)),
                        ),
                      ),
                      const SizedBox(height: 16),

                      Text('Select Registered Practice Jurisdiction:', style: GoogleFonts.plusJakartaSans(fontSize: 11.5, color: ClinicTheme.textSecondary, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 10),
                      Column(
                        children: presets.map((p) {
                          final isSelected = selectedCountry == p['country'] && selectedCity == p['city'];
                          return InkWell(
                            onTap: () {
                              setDialogState(() {
                                selectedCountry = p['country']!;
                                selectedCity = p['city']!;
                              });
                            },
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: isSelected ? ClinicTheme.brandAccentFaint : ClinicTheme.surfaceDark,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isSelected ? ClinicTheme.brandAccent : ClinicTheme.border.withOpacity(0.4),
                                  width: isSelected ? 1.5 : 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Text(p['flag']!, style: const TextStyle(fontSize: 20)),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '${p['city']}, ${p['country']}',
                                          style: GoogleFonts.plusJakartaSans(fontSize: 12.5, fontWeight: FontWeight.bold, color: Colors.white),
                                        ),
                                        Text(
                                          p['subtitle']!,
                                          style: GoogleFonts.plusJakartaSans(fontSize: 10.5, color: ClinicTheme.textSecondary),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (isSelected)
                                    const Icon(Icons.check_circle_rounded, color: ClinicTheme.brandAccent, size: 18),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.of(dialogCtx).pop(),
                            child: const Text('Cancel', style: TextStyle(color: ClinicTheme.textSecondary)),
                          ),
                          const SizedBox(width: 10),
                          FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: ClinicTheme.brandAccent,
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            ),
                            icon: const Icon(Icons.check_circle, size: 16),
                            label: const Text('Apply Location Context', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                            onPressed: () {
                              scope.updatePracticeLocation(
                                newCountry: selectedCountry,
                                newStateOrCity: selectedCity,
                                newClinicName: nameCtrl.text.trim(),
                              );
                              Navigator.of(dialogCtx).pop();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  backgroundColor: const Color(0xFF10B981),
                                  content: Text('✓ Practice context updated to $selectedCity, $selectedCountry (${scope.currencySymbol} ${scope.currency}). All clinical modules adapted!'),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
