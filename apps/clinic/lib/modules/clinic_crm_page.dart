import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/clinic_theme.dart';
import '../data/clinic_scope.dart';

/// Clinic CRM & Patient Lifecycle Engine
///
/// Designed based on cross-specialty clinical benchmarks (NexHealth, ModMed, Jane App):
/// 1. Automated annual exam recalls (11-month cadence) to boost patient retention.
/// 2. Chronic disease & glaucoma drop adherence refill cadence (day 25 reorder).
/// 3. Optical order pickup notifications (frames / smart glasses ready).
/// 4. Intelligent recipient routing: Patient, Caregiver, or Both (critical for low vision).
/// 5. Post-visit 5-star review booster (Google Reviews automated prompts).
class ClinicCrmPage extends StatefulWidget {
  const ClinicCrmPage({super.key});

  @override
  State<ClinicCrmPage> createState() => _ClinicCrmPageState();
}

class _ClinicCrmPageState extends State<ClinicCrmPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _pipelineFilter = 'All';
  bool _isDispatching = false;

  // Active recall pipeline records (fallback mock + live Supabase)
  final List<Map<String, dynamic>> _recalls = [
    {
      'id': 'rec_001',
      'patient_name': 'Eleanor Vance',
      'patient_id': 'demo_patient_001',
      'pipeline': 'Annual Exam Recall',
      'type_code': 'annual_exam',
      'due_text': 'Due in 5 days (11-Month Cadence)',
      'due_color': ClinicTheme.warningAmber,
      'status': 'Pending',
      'target': 'Both (Patient & Caregiver)',
      'notes': 'Macular degeneration stage 2. Routine visual acuity & OCT check due.',
      'last_contacted': 'Never',
    },
    {
      'id': 'rec_002',
      'patient_name': 'Arthur Pendelton',
      'patient_id': 'patient_pendelton_02',
      'pipeline': 'Glaucoma IOP Check',
      'type_code': 'glaucoma_check',
      'due_text': 'Overdue by 8 days',
      'due_color': Colors.redAccent,
      'status': 'Overdue',
      'target': 'Caregiver (Employed Aide)',
      'notes': 'Target IOP <= 15 mmHg. Pressure check overdue. Last visit 6 mos ago.',
      'last_contacted': '3 days ago (SMS)',
    },
    {
      'id': 'rec_003',
      'patient_name': 'Devin Harris',
      'patient_id': 'patient_harris_04',
      'pipeline': 'Diabetic Retinopathy Screen',
      'type_code': 'diabetic_screen',
      'due_text': 'Due in 2 weeks',
      'due_color': Colors.blueAccent,
      'status': 'Scheduled',
      'target': 'Patient Only',
      'notes': 'Type 2 Diabetic. Dilated fundus exam annual screening.',
      'last_contacted': 'Yesterday',
    },
    {
      'id': 'rec_004',
      'patient_name': 'Clara Oswald',
      'patient_id': 'patient_oswald_07',
      'pipeline': 'Smart Frame Fitting Follow-Up',
      'type_code': 'annual_exam',
      'due_text': '30-Day Check-in',
      'due_color': ClinicTheme.malachite,
      'status': 'Pending',
      'target': 'Patient Only',
      'notes': 'Fitted with AirGo 3 directional audio glasses. Experience review.',
      'last_contacted': 'Never',
    },
  ];

  // Optical order pickup and refill items
  final List<Map<String, dynamic>> _opticalEvents = [
    {
      'patient_name': 'Eleanor Vance',
      'type': 'Drop Refill Due (Day 25)',
      'item': 'Latanoprost 0.005% Ophthalmic Solution',
      'streak': '14-Day Perfect Streak',
      'action_label': 'Send 1-Tap Bachs Reorder Prompt',
      'badge_color': Colors.amber,
      'target': 'Caregiver & Patient',
    },
    {
      'patient_name': 'Marcus Vance',
      'type': 'Lab Lenses Ready for In-Clinic Pickup',
      'item': 'Goz Frame Pro S4 (Prescription Anti-Reflective)',
      'streak': 'Order #ORD-2026-9941',
      'action_label': 'Send Ready for Pickup Alert',
      'badge_color': ClinicTheme.malachite,
      'target': 'Patient Only',
    },
    {
      'patient_name': 'Martha Alvarez',
      'type': 'Abandoned Prescription Follow-up',
      'item': 'FL-41 Rose Photophobia Filter Lenses',
      'streak': 'Recommended in Scribe 48h ago',
      'action_label': 'Send Assisted Checkout Link',
      'badge_color': Colors.purpleAccent,
      'target': 'Patient Only',
    },
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _dispatchRecall(Map<String, dynamic> recall) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ClinicTheme.cardBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: ClinicTheme.border),
        ),
        title: Row(
          children: [
            const Icon(Icons.send_rounded, color: ClinicTheme.malachite),
            const SizedBox(width: 10),
            Text('Dispatch Recall: ${recall['patient_name']}', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Recall Type: ${recall['pipeline']}',
                style: const TextStyle(color: ClinicTheme.malachite, fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 6),
              Text(
                'Recipient Target: ${recall['target']}',
                style: const TextStyle(color: ClinicTheme.textSecondary, fontSize: 12),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: ClinicTheme.obsidian,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: ClinicTheme.border),
                ),
                child: Text(
                  '“Hi ${recall['patient_name']}, this is your care team at GozVision Clinic. It’s time for your ${recall['pipeline']}. Tap here to confirm your appointment slot with Dr. Miller: https://gozvision.vercel.app/book”',
                  style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.4),
                ),
              ),
              const SizedBox(height: 16),
              const Text('Dispatch Channel:', style: TextStyle(color: ClinicTheme.textSecondary, fontSize: 12)),
              const SizedBox(height: 8),
              Row(
                children: [
                  _buildChannelPill('SMS / Text', true),
                  const SizedBox(width: 8),
                  _buildChannelPill('In-App Voice Prompt', false),
                  const SizedBox(width: 8),
                  _buildChannelPill('Email', false),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            child: const Text('Cancel', style: TextStyle(color: ClinicTheme.textSecondary)),
            onPressed: () => Navigator.pop(ctx),
          ),
          FilledButton.icon(
            icon: const Icon(Icons.outgoing_mail, size: 16),
            label: const Text('Send Recall Now'),
            style: FilledButton.styleFrom(backgroundColor: ClinicTheme.malachite, foregroundColor: Colors.black),
            onPressed: () async {
              Navigator.pop(ctx);
              setState(() => _isDispatching = true);
              try {
                // Record in Supabase notifications table
                final scope = context.read<ClinicScope>();
                if (scope.clinicId != null) {
                  await Supabase.instance.client.from('notifications').insert({
                    'clinic_id': scope.clinicId,
                    'patient_id': recall['patient_id'],
                    'patient_name': recall['patient_name'],
                    'kind': 'recall',
                    'channel': 'sms',
                    'recipient_target': 'both',
                    'message': 'Annual eye exam recall prompt dispatched.',
                    'status': 'sent',
                    'sent_at': DateTime.now().toIso8601String(),
                  });
                }
              } catch (_) {}
              setState(() {
                _isDispatching = false;
                recall['status'] = 'Contacted';
                recall['last_contacted'] = 'Just now';
              });
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('✓ Recall dispatched to ${recall['patient_name']} (${recall['target']})'),
                    backgroundColor: ClinicTheme.malachite,
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildChannelPill(String label, bool isSelected) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isSelected ? ClinicTheme.malachiteFaint : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isSelected ? ClinicTheme.malachite : ClinicTheme.border),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: isSelected ? ClinicTheme.malachite : ClinicTheme.textSecondary,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ClinicTheme.obsidian,
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Executive CRM Header
            _buildCrmHeader(),
            const SizedBox(height: 20),

            // 4 Executive CRM KPIs (Learned from NexHealth & Solutionreach)
            _buildKpiMetrics(),
            const SizedBox(height: 20),

            // Navigation Tabs
            TabBar(
              controller: _tabController,
              isScrollable: true,
              indicatorColor: ClinicTheme.malachite,
              indicatorWeight: 3,
              labelColor: ClinicTheme.malachite,
              unselectedLabelColor: ClinicTheme.textSecondary,
              labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              tabs: const [
                Tab(icon: Icon(Icons.event_repeat, size: 18), text: 'Annual Exam & Clinical Recalls'),
                Tab(icon: Icon(Icons.local_pharmacy_outlined, size: 18), text: 'Drop Refills & Optical Orders'),
                Tab(icon: Icon(Icons.mark_chat_read_outlined, size: 18), text: 'Patient & Caregiver Messaging'),
                Tab(icon: Icon(Icons.star_rate_rounded, size: 18), text: 'Reputation & 5-Star Reviews'),
              ],
            ),
            const Divider(height: 1, color: ClinicTheme.border),
            const SizedBox(height: 16),

            // Tab Views
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildRecallsTab(),
                  _buildOpticalRefillsTab(),
                  _buildMessagingTab(),
                  _buildReputationTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCrmHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: ClinicTheme.malachite.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: ClinicTheme.malachite.withValues(alpha: 0.3)),
              ),
              child: const Icon(Icons.people_alt_rounded, color: ClinicTheme.malachite, size: 24),
            ),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'PATIENT LIFECYCLE & RECALL CRM',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: ClinicTheme.textPrimary,
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  'Automate annual eye exam recalls, glaucoma drop refills, and caregiver communication.',
                  style: TextStyle(fontSize: 12, color: ClinicTheme.textSecondary),
                ),
              ],
            ),
          ],
        ),
        FilledButton.icon(
          icon: const Icon(Icons.bolt, size: 16),
          label: const Text('Run Automated Recall Sweep'),
          style: FilledButton.styleFrom(backgroundColor: ClinicTheme.malachite, foregroundColor: Colors.black),
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('✓ Recall sweep executed: 12 upcoming patients queued for outreach.'),
                backgroundColor: ClinicTheme.malachite,
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildKpiMetrics() {
    return Row(
      children: [
        _buildKpiCard('Recall Retention', '84%', '+19% vs. unautomated clinic', Icons.trending_up, ClinicTheme.malachite),
        const SizedBox(width: 12),
        _buildKpiCard('Pending Recalls', '24 Due', '11-month exam horizon', Icons.hourglass_top, Colors.amberAccent),
        const SizedBox(width: 12),
        _buildKpiCard('Active Drop Cadences', '18 Active', 'Glaucoma & Dry Eye streaks', Icons.water_drop_outlined, Colors.tealAccent),
        const SizedBox(width: 12),
        _buildKpiCard('Patient Rating', '4.9 ★', '128 verified Google reviews', Icons.star, Colors.orangeAccent),
      ],
    );
  }

  Widget _buildKpiCard(String title, String val, String sub, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: ClinicTheme.cardBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: ClinicTheme.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title, style: TextStyle(color: ClinicTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.bold)),
                Icon(icon, color: color, size: 18),
              ],
            ),
            const SizedBox(height: 8),
            Text(val, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(sub, style: TextStyle(color: ClinicTheme.textSecondary, fontSize: 11)),
          ],
        ),
      ),
    );
  }

  // ── Tab 1: Recalls Tab ─────────────────────────────────────────────────────
  Widget _buildRecallsTab() {
    return Column(
      children: [
        // Filter bar
        Row(
          children: [
            const Text('Filter Pipeline:', style: TextStyle(color: ClinicTheme.textSecondary, fontSize: 12)),
            const SizedBox(width: 10),
            _buildFilterChip('All'),
            const SizedBox(width: 6),
            _buildFilterChip('Annual Exam'),
            const SizedBox(width: 6),
            _buildFilterChip('Glaucoma Check'),
            const SizedBox(width: 6),
            _buildFilterChip('Diabetic Screen'),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: ListView.separated(
            itemCount: _filteredRecalls.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (ctx, idx) {
              final r = _filteredRecalls[idx];
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: ClinicTheme.cardBackground,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: ClinicTheme.border),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: (r['due_color'] as Color).withValues(alpha: 0.15),
                      child: Icon(Icons.event_repeat, color: r['due_color'] as Color, size: 20),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(r['patient_name'] as String, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: (r['due_color'] as Color).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(r['due_text'] as String, style: TextStyle(color: r['due_color'] as Color, fontSize: 10, fontWeight: FontWeight.bold)),
                              ),
                              const Spacer(),
                              Text('Target: ${r['target']}', style: TextStyle(color: ClinicTheme.textSecondary, fontSize: 11)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text('${r['pipeline']} • ${r['notes']}', style: TextStyle(color: Colors.white70, fontSize: 12)),
                          const SizedBox(height: 4),
                          Text('Last Contact: ${r['last_contacted']} • Status: ${r['status']}', style: TextStyle(color: ClinicTheme.textSecondary, fontSize: 11)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: r['status'] == 'Contacted' ? ClinicTheme.surface : ClinicTheme.malachite,
                        foregroundColor: r['status'] == 'Contacted' ? ClinicTheme.malachite : Colors.black,
                        visualDensity: VisualDensity.compact,
                      ),
                      onPressed: () => _dispatchRecall(r),
                      child: Text(r['status'] == 'Contacted' ? 'Follow Up' : 'Dispatch Recall', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  List<Map<String, dynamic>> get _filteredRecalls {
    if (_pipelineFilter == 'All') return _recalls;
    if (_pipelineFilter == 'Annual Exam') return _recalls.where((r) => r['type_code'] == 'annual_exam').toList();
    if (_pipelineFilter == 'Glaucoma Check') return _recalls.where((r) => r['type_code'] == 'glaucoma_check').toList();
    if (_pipelineFilter == 'Diabetic Screen') return _recalls.where((r) => r['type_code'] == 'diabetic_screen').toList();
    return _recalls;
  }

  Widget _buildFilterChip(String label) {
    final isSelected = _pipelineFilter == label;
    return InkWell(
      onTap: () => setState(() => _pipelineFilter = label),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? ClinicTheme.malachiteFaint : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isSelected ? ClinicTheme.malachite : ClinicTheme.border),
        ),
        child: Text(
          label,
          style: TextStyle(color: isSelected ? ClinicTheme.malachite : ClinicTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  // ── Tab 2: Optical Orders & Drop Refills ──────────────────────────────────
  Widget _buildOpticalRefillsTab() {
    return ListView.separated(
      itemCount: _opticalEvents.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (ctx, idx) {
        final ev = _opticalEvents[idx];
        return Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: ClinicTheme.cardBackground,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: ClinicTheme.border),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: (ev['badge_color'] as Color).withValues(alpha: 0.15),
                child: Icon(Icons.medication_outlined, color: ev['badge_color'] as Color, size: 22),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(ev['patient_name'] as String, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: (ev['badge_color'] as Color).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(ev['type'] as String, style: TextStyle(color: ev['badge_color'] as Color, fontSize: 10, fontWeight: FontWeight.bold)),
                        ),
                        const Spacer(),
                        Text('Target: ${ev['target']}', style: TextStyle(color: ClinicTheme.textSecondary, fontSize: 11)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(ev['item'] as String, style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text('Compliance status: ${ev['streak']}', style: TextStyle(color: ClinicTheme.textSecondary, fontSize: 11)),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              FilledButton.icon(
                icon: const Icon(Icons.bolt, size: 14),
                label: Text(ev['action_label'] as String, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                style: FilledButton.styleFrom(
                  backgroundColor: ClinicTheme.malachite,
                  foregroundColor: Colors.black,
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('✓ ${ev['action_label']} dispatched to ${ev['patient_name']}')),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Tab 3: Messaging Hub ──────────────────────────────────────────────────
  Widget _buildMessagingTab() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ClinicTheme.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ClinicTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text('TWO-WAY CLINIC COMMUNICATION STREAM', style: TextStyle(color: ClinicTheme.malachite, fontSize: 13, fontWeight: FontWeight.bold)),
              Text('SMS · In-App Voice · Push Telemetry', style: TextStyle(color: ClinicTheme.textSecondary, fontSize: 11)),
            ],
          ),
          const SizedBox(height: 14),
          Expanded(
            child: ListView(
              children: const [
                _ChatBubble(
                  sender: 'Front Desk Coordinator',
                  message: 'Hi Eleanor, Dr. Miller reviewed your drop compliance streak. Your intraocular pressure is trending perfectly! Your annual exam is scheduled for Friday at 2:00 PM.',
                  time: '10:15 AM',
                  isClinic: true,
                ),
                _ChatBubble(
                  sender: 'Eleanor Vance (via Goz Voice Copilot)',
                  message: 'Thank you! My daughter and I will be there on Friday. My Systane bottle is almost empty though.',
                  time: '10:18 AM',
                  isClinic: false,
                ),
                _ChatBubble(
                  sender: 'Automated CRM Dispatch',
                  message: '✓ 1-Tap Bachs Reorder link sent for Systane Complete PF Multi-Pack (₦18,500.00). Dispatched to daughter’s phone.',
                  time: '10:19 AM',
                  isClinic: true,
                ),
              ],
            ),
          ),
          const Divider(color: ClinicTheme.border),
          Row(
            children: [
              Expanded(
                child: TextField(
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: const InputDecoration(
                    hintText: 'Type message or recall note to patient / caregiver...',
                    border: InputBorder.none,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.send, color: ClinicTheme.malachite),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Message dispatched via GozVision CRM stream')),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Tab 4: Reputation & 5-Star Reviews ────────────────────────────────────
  Widget _buildReputationTab() {
    return ListView(
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: ClinicTheme.cardBackground,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: ClinicTheme.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text('AUTOMATED GOOGLE & REPUTATION ENGINE', style: TextStyle(color: ClinicTheme.malachite, fontSize: 13, fontWeight: FontWeight.bold)),
                      SizedBox(height: 4),
                      Text('Automatically prompts satisfied patients to leave a 5-star Google review after completed visits.', style: TextStyle(color: ClinicTheme.textSecondary, fontSize: 12)),
                    ],
                  ),
                  FilledButton.icon(
                    icon: const Icon(Icons.auto_awesome, size: 16),
                    label: const Text('Send Review Prompts (3 Today)'),
                    style: FilledButton.styleFrom(backgroundColor: ClinicTheme.malachite, foregroundColor: Colors.black),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('✓ 3 Google review requests dispatched to recently completed encounters.')),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  _buildReviewMetric('4.9 / 5.0', 'Current Google Rating', Icons.star, Colors.amber),
                  const SizedBox(width: 12),
                  _buildReviewMetric('128 Reviews', 'Verified Patient Reviews', Icons.rate_review_outlined, Colors.blueAccent),
                  const SizedBox(width: 12),
                  _buildReviewMetric('38% Response', 'Review Conversion Rate', Icons.pie_chart_outline, ClinicTheme.malachite),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildReviewMetric(String val, String sub, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: ClinicTheme.obsidian,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: ClinicTheme.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(val, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                Icon(icon, color: color, size: 18),
              ],
            ),
            const SizedBox(height: 4),
            Text(sub, style: TextStyle(color: ClinicTheme.textSecondary, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  final String sender;
  final String message;
  final String time;
  final bool isClinic;

  const _ChatBubble({
    required this.sender,
    required this.message,
    required this.time,
    required this.isClinic,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isClinic ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isClinic ? ClinicTheme.malachite.withValues(alpha: 0.12) : ClinicTheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isClinic ? ClinicTheme.malachite.withValues(alpha: 0.3) : ClinicTheme.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(sender, style: TextStyle(color: isClinic ? ClinicTheme.malachite : Colors.tealAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                const SizedBox(width: 8),
                Text(time, style: TextStyle(color: ClinicTheme.textSecondary, fontSize: 10)),
              ],
            ),
            const SizedBox(height: 6),
            Text(message, style: const TextStyle(color: Colors.white, fontSize: 12.5, height: 1.4)),
          ],
        ),
      ),
    );
  }
}
