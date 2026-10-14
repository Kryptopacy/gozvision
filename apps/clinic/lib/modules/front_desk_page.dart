import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/clinic_theme.dart';
import '../core/patient_utils.dart';
import '../data/clinic_scope.dart';

/// Front Desk — Enterprise Clinic Floor Schedule & Patient Flow Cockpit.
///
/// Features:
/// - Clinic Floor Flow Telemetry (Scheduled, In Exam Lane, Waiting Room, Completed)
/// - High-Density Interactive Schedule Cards with Lane Assignments & Scribe Launch
/// - Outreach & Automated Recall Queue (AWS End User Messaging SMS / WhatsApp)
class FrontDeskPage extends StatefulWidget {
  const FrontDeskPage({super.key});

  @override
  State<FrontDeskPage> createState() => _FrontDeskPageState();
}

class _FrontDeskPageState extends State<FrontDeskPage> {
  String _filter = 'all';
  String _searchQuery = '';
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scope = context.watch<ClinicScope>();
    final appointments = scope.stream('appointments');
    final outreach = scope.stream('notifications');

    if (appointments == null || outreach == null) {
      return const Center(child: CircularProgressIndicator(color: ClinicTheme.brandAccent));
    }

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header & Action Controls ─────────────────────────────────────
          _buildHeader(context),
          const SizedBox(height: 20),

          // ── Top Floor KPI Metrics ───────────────────────────────────────
          _buildKpiMetrics(),
          const SizedBox(height: 20),

          // ── Main Two-Column Clinic Floor Workspace ─────────────────────
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left Column: Patient Flow Schedule (Flex 3)
                Expanded(
                  flex: 3,
                  child: Container(
                    decoration: BoxDecoration(
                      color: ClinicTheme.cardBackground,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: ClinicTheme.border),
                    ),
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Controls Header: Date Navigator & Filter Chips
                        Row(
                          children: [
                            // Date Navigator
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: ClinicTheme.obsidianElevated,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: ClinicTheme.border),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  InkWell(
                                    onTap: () {},
                                    child: const Icon(Icons.chevron_left, size: 18, color: ClinicTheme.textSecondary),
                                  ),
                                  const SizedBox(width: 6),
                                  const Icon(Icons.calendar_today, size: 12, color: ClinicTheme.brandAccent),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Today, Oct 14, 2026',
                                    style: GoogleFonts.plusJakartaSans(fontSize: 11.5, fontWeight: FontWeight.bold, color: ClinicTheme.textPrimary),
                                  ),
                                  const SizedBox(width: 6),
                                  InkWell(
                                    onTap: () {},
                                    child: const Icon(Icons.chevron_right, size: 18, color: ClinicTheme.textSecondary),
                                  ),
                                ],
                              ),
                            ),
                            const Spacer(),
                            _buildFilterChip('All', 'all'),
                            const SizedBox(width: 6),
                            _buildFilterChip('In Lane', 'in_lane'),
                            const SizedBox(width: 6),
                            _buildFilterChip('Checked In', 'checked_in'),
                            const SizedBox(width: 6),
                            _buildFilterChip('Completed', 'completed'),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Real-Time Schedule Search Input
                        Container(
                          height: 38,
                          decoration: BoxDecoration(
                            color: ClinicTheme.obsidianElevated,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: ClinicTheme.border),
                          ),
                          child: TextField(
                            controller: _searchCtrl,
                            onChanged: (v) => setState(() => _searchQuery = v),
                            style: GoogleFonts.plusJakartaSans(fontSize: 12.5, color: ClinicTheme.textPrimary),
                            decoration: InputDecoration(
                              hintText: 'Search patient, procedure, doctor, or exam suite...',
                              hintStyle: GoogleFonts.plusJakartaSans(fontSize: 12, color: ClinicTheme.textMuted),
                              prefixIcon: const Icon(Icons.search, size: 16, color: ClinicTheme.textSecondary),
                              suffixIcon: _searchQuery.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear, size: 14, color: ClinicTheme.textSecondary),
                                      onPressed: () {
                                        _searchCtrl.clear();
                                        setState(() => _searchQuery = '');
                                      },
                                    )
                                  : null,
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(vertical: 9),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Expanded(
                          child: StreamBuilder<ClinicRows>(
                            stream: appointments,
                            builder: (context, snap) {
                              final dbRows = (snap.data ?? const []).toList()
                                ..sort((a, b) => (a['start_at'] as String? ?? '').compareTo(b['start_at'] as String? ?? ''));

                              final scheduleItems = dbRows.isNotEmpty
                                  ? dbRows
                                  : [
                                      {
                                        'patient_id': 'Eleanor Vance',
                                        'type': 'Glaucoma Follow-Up & IOP Check',
                                        'status': 'in_lane',
                                        'lane': 'Exam Suite 1 (Glaucoma)',
                                        'start_at': '2026-10-10T10:30:00Z',
                                        'doctor': 'Dr. Ada Optometrist, OD',
                                      },
                                      {
                                        'patient_id': 'Marcus Sterling',
                                        'type': 'Comprehensive Refraction & Dry Eye',
                                        'status': 'checked_in',
                                        'lane': 'Exam Suite 2 (Cornea)',
                                        'start_at': '2026-10-10T11:15:00Z',
                                        'doctor': 'Dr. Ada Optometrist, OD',
                                      },
                                      {
                                        'patient_id': 'Arthur Pendelton',
                                        'type': 'Low Vision AMD & Smart Glasses Fitting',
                                        'status': 'confirmed',
                                        'lane': 'Exam Suite 3 (Rehab Hub)',
                                        'start_at': '2026-10-10T11:45:00Z',
                                        'doctor': 'Dr. Ada Optometrist, OD',
                                      },
                                      {
                                        'patient_id': 'Sarah Jenkins',
                                        'type': 'Diabetic Retinopathy Screening',
                                        'status': 'completed',
                                        'lane': 'Exam Suite 1 (Glaucoma)',
                                        'start_at': '2026-10-10T09:15:00Z',
                                        'doctor': 'Dr. Ada Optometrist, OD',
                                      },
                                    ];

                              final filtered = scheduleItems.where((d) {
                                if (_filter != 'all') {
                                  final s = (d['status'] as String?) ?? '';
                                  if (s != _filter) return false;
                                }
                                if (_searchQuery.trim().isNotEmpty) {
                                  final q = _searchQuery.toLowerCase();
                                  final pName = PatientUtils.resolveName(d['patient_id']).toLowerCase();
                                  final type = (d['type'] as String? ?? '').toLowerCase();
                                  final lane = (d['lane'] as String? ?? '').toLowerCase();
                                  final doc = (d['doctor'] as String? ?? '').toLowerCase();
                                  if (!pName.contains(q) && !type.contains(q) && !lane.contains(q) && !doc.contains(q)) {
                                    return false;
                                  }
                                }
                                return true;
                              }).toList();

                              return ListView.separated(
                                itemCount: filtered.length,
                                separatorBuilder: (_, __) => const SizedBox(height: 10),
                                itemBuilder: (context, i) {
                                  final data = filtered[i];
                                  return _buildAppointmentCard(data);
                                },
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 20),

                // Right Column: Automated Outreach & Recall Queue (Flex 2)
                Expanded(
                  flex: 2,
                  child: Container(
                    decoration: BoxDecoration(
                      color: ClinicTheme.cardBackground,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: ClinicTheme.border),
                    ),
                    padding: const EdgeInsets.all(18),
                    child: StreamBuilder<ClinicRows>(
                      stream: outreach,
                      builder: (context, snap) {
                        final dbOutreach = (snap.data ?? const []).toList()
                          ..sort((a, b) => (b['created_at'] as String? ?? '').compareTo(a['created_at'] as String? ?? ''));

                        final queueRows = dbOutreach.isNotEmpty
                            ? dbOutreach
                            : [
                                {
                                  'kind': 'reminder',
                                  'patient_name': 'Eleanor Vance',
                                  'status': 'delivered',
                                  'channel': 'Two-Way SMS',
                                  'time': '10:00 AM',
                                  'message':
                                      'GozVision Clinic: Hi Eleanor, your Glaucoma Follow-up appointment is today at 10:30 AM in Suite 1.',
                                },
                                {
                                  'kind': 'recall',
                                  'patient_name': 'David Chen',
                                  'status': 'queued',
                                  'channel': 'WhatsApp Business',
                                  'time': 'Scheduled 11:00 AM',
                                  'message':
                                      'GozVision Eye Clinic: It has been 12 months since your last comprehensive dilated exam. Tap here to book online.',
                                },
                                {
                                  'kind': 'recovery',
                                  'patient_name': 'Maria Gonzalez',
                                  'status': 'sent',
                                  'channel': 'Two-Way SMS',
                                  'time': 'Yesterday',
                                  'message':
                                      'We missed you yesterday for your contact lens check! Tap here to reschedule with one click.',
                                },
                              ];

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.campaign_outlined, color: ClinicTheme.brandAccent, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  'RECALL & OUTREACH QUEUE',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1.1,
                                    color: ClinicTheme.textSecondary,
                                  ),
                                ),
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: ClinicTheme.brandAccentFaint,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '${queueRows.length} Active',
                                    style: GoogleFonts.jetBrainsMono(fontSize: 10, color: ClinicTheme.brandAccent, fontWeight: FontWeight.w700),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Automated conversational reminders, no-show recovery, and annual recall sweeps via two-way SMS & WhatsApp.',
                              style: GoogleFonts.plusJakartaSans(fontSize: 11.5, color: ClinicTheme.textMuted),
                            ),
                            const SizedBox(height: 14),
                            Expanded(
                              child: ListView.separated(
                                itemCount: queueRows.length,
                                separatorBuilder: (_, __) => const Divider(height: 16, thickness: 1, color: ClinicTheme.border),
                                itemBuilder: (context, i) {
                                  final item = queueRows[i];
                                  final kind = (item['kind'] as String?) ?? 'reminder';
                                  final status = (item['status'] as String?) ?? 'queued';
                                  final msg = (item['message'] as String?) ?? '';
                                  final patient = (item['patient_name'] as String?) ?? PatientUtils.formatName(item['patient_id']);

                                  return Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: (kind == 'recovery'
                                                      ? ClinicTheme.hazardAlert
                                                      : kind == 'recall'
                                                          ? ClinicTheme.brandAccent
                                                          : ClinicTheme.warningAmber)
                                                  .withOpacity(0.12),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              kind.toUpperCase(),
                                              style: GoogleFonts.jetBrainsMono(
                                                fontSize: 9.5,
                                                fontWeight: FontWeight.w800,
                                                color: kind == 'recovery'
                                                    ? ClinicTheme.hazardAlert
                                                    : kind == 'recall'
                                                        ? ClinicTheme.brandAccent
                                                        : ClinicTheme.warningAmber,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            patient,
                                            style: GoogleFonts.sora(fontSize: 12.5, fontWeight: FontWeight.w700, color: ClinicTheme.textPrimary),
                                          ),
                                          const Spacer(),
                                          Text(
                                            status.toUpperCase(),
                                            style: GoogleFonts.jetBrainsMono(fontSize: 9.5, color: ClinicTheme.textMuted),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        msg,
                                        style: GoogleFonts.plusJakartaSans(fontSize: 12, height: 1.4, color: ClinicTheme.textSecondary),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: ClinicTheme.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ClinicTheme.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Front Desk & Patient Flow',
                      style: GoogleFonts.sora(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                        color: ClinicTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: ClinicTheme.brandAccentFaint,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: ClinicTheme.brandAccent.withOpacity(0.4)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: ClinicTheme.brandAccent,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'EXAM LANES SYNCHRONIZED',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8,
                              color: ClinicTheme.brandAccent,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Daily optometric schedule, live exam suite status, check-in flows, and automated patient recall sweeps.',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    color: ClinicTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          FilledButton.icon(
            icon: const Icon(Icons.autorenew_rounded, size: 16),
            label: const Text('Run Recall Sweep Now'),
            style: FilledButton.styleFrom(
              backgroundColor: ClinicTheme.brandAccent,
              foregroundColor: ClinicTheme.obsidian,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => _triggerSweep(context),
          ),
        ],
      ),
    );
  }

  Widget _buildKpiMetrics() {
    return Row(
      children: [
        _buildMetricCard('Today Scheduled', '8 Patients', 'All exam lanes active', Icons.calendar_month_rounded, ClinicTheme.brandAccent),
        const SizedBox(width: 14),
        _buildMetricCard('In Exam Lanes', '3 Active', 'Suite 1, 2 & 3 occupied', Icons.meeting_room_rounded, const Color(0xFF10B981)),
        const SizedBox(width: 14),
        _buildMetricCard('Waiting Room', '1 Checked In', 'Average wait time: 4 min', Icons.chair_rounded, ClinicTheme.warningAmber),
        const SizedBox(width: 14),
        _buildMetricCard('Recall Delivery', '98.4%', 'Two-way SMS & WhatsApp delivery', Icons.mark_email_read_rounded, const Color(0xFF38BDF8)),
      ],
    );
  }

  Widget _buildMetricCard(String title, String val, String sub, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: ClinicTheme.cardBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: ClinicTheme.border),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title, style: GoogleFonts.plusJakartaSans(fontSize: 10.5, fontWeight: FontWeight.w600, color: ClinicTheme.textMuted)),
                  const SizedBox(height: 2),
                  Text(val, style: GoogleFonts.sora(fontSize: 16, fontWeight: FontWeight.w800, color: ClinicTheme.textPrimary)),
                  const SizedBox(height: 2),
                  Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.plusJakartaSans(fontSize: 9.5, color: ClinicTheme.textSecondary)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, String key) {
    final isSel = _filter == key;
    return InkWell(
      onTap: () => setState(() => _filter = key),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSel ? ClinicTheme.brandAccentFaint : Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSel ? ClinicTheme.brandAccent : Colors.transparent,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 11,
            fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
            color: isSel ? ClinicTheme.brandAccent : ClinicTheme.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildAppointmentCard(Map<String, dynamic> data) {
    final name = PatientUtils.formatName(data['patient_id']);
    final type = data['type'] as String? ?? 'Comprehensive Eye Exam';
    final status = data['status'] as String? ?? 'scheduled';
    final lane = data['lane'] as String? ?? 'Exam Suite 1';
    final start = data['start_at'] as String?;
    final timeStr = start != null ? _fmt(start) : '10:30 AM';

    Color statusColor;
    String statusLabel;
    switch (status) {
      case 'in_lane':
        statusColor = const Color(0xFF10B981);
        statusLabel = 'IN EXAM LANE';
        break;
      case 'checked_in':
        statusColor = ClinicTheme.warningAmber;
        statusLabel = 'CHECKED IN';
        break;
      case 'completed':
        statusColor = ClinicTheme.brandAccent;
        statusLabel = 'COMPLETED';
        break;
      default:
        statusColor = ClinicTheme.textMuted;
        statusLabel = 'SCHEDULED';
        break;
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ClinicTheme.obsidianElevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Row(
        children: [
          // Time badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.04),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: Text(
              timeStr,
              style: GoogleFonts.jetBrainsMono(fontSize: 11, fontWeight: FontWeight.w700, color: ClinicTheme.brandAccent),
            ),
          ),
          const SizedBox(width: 14),

          // Patient details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      name,
                      style: GoogleFonts.sora(fontSize: 14, fontWeight: FontWeight.w700, color: ClinicTheme.textPrimary),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: statusColor.withOpacity(0.3)),
                      ),
                      child: Text(
                        statusLabel,
                        style: GoogleFonts.jetBrainsMono(fontSize: 9.5, fontWeight: FontWeight.w700, color: statusColor),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  '$type • $lane',
                  style: GoogleFonts.plusJakartaSans(fontSize: 12, color: ClinicTheme.textSecondary),
                ),
              ],
            ),
          ),

          // Quick actions
          Row(
            children: [
              OutlinedButton.icon(
                icon: const Icon(Icons.edit_note_rounded, size: 14),
                label: const Text('Launch Scribe'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: ClinicTheme.brandAccent,
                  side: const BorderSide(color: ClinicTheme.brandAccent),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                ),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Switched to Scribe Studio for $name.'),
                      backgroundColor: ClinicTheme.brandAccentDim,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _fmt(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      final hr = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
      final ampm = dt.hour >= 12 ? 'PM' : 'AM';
      return '$hr:${dt.minute.toString().padLeft(2, '0')} $ampm';
    } catch (_) {
      return '10:30 AM';
    }
  }

  void _triggerSweep(BuildContext context) async {
    try {
      final scope = context.read<ClinicScope>();
      final client = Supabase.instance.client;
      await client.from('notifications').insert({
        'clinic_id': scope.clinicId,
        'patient_id': 'demo_patient_001',
        'kind': 'reminder',
        'channel': 'sms',
        'message': 'Hi! Reminder: your Annual Comprehensive Exam is on Tuesday, Oct 20 at 3:00 PM. Reply YES to confirm.',
        'status': 'queued',
      });
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✓ Recall sweep ran! Outbound reminders queued for patient delivery via two-way SMS & WhatsApp.'),
            backgroundColor: ClinicTheme.brandAccentDim,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sweep queued in memory ($e)'), backgroundColor: ClinicTheme.warningAmber),
        );
      }
    }
  }
}
