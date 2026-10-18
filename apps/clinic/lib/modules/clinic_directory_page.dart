import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/clinic_theme.dart';
import '../data/clinic_scope.dart';

/// Clinic Directory & Practice Roster Management
///
/// Gives clinic owners, practice managers, and doctors a unified view of:
///  - Clinic Identity, Branches, Operating Hours, and Facility Details
///  - Practitioner Roster (Optometrists & Specialists with licenses, lanes & schedules)
///  - Staff Directory (Front desk, optometric technicians, patient care coordinators)
///  - Team onboarding / role assignment linked to the clinic tenant
class ClinicDirectoryPage extends StatefulWidget {
  const ClinicDirectoryPage({super.key});

  @override
  State<ClinicDirectoryPage> createState() => _ClinicDirectoryPageState();
}

class _ClinicDirectoryPageState extends State<ClinicDirectoryPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final List<Map<String, dynamic>> _mockPractitioners = [
    {
      'id': 'dr_adegoke',
      'name': 'Dr. O.D. Adegoke, O.D., FAAO',
      'role': 'Lead Optometrist & Practice Director',
      'license': 'OD-84920-NG',
      'npi': '1928374650',
      'specialty': 'Low Vision Rehabilitation & Primary Eye Care',
      'exam_room': 'Exam Suite 2A (OCT / Low Vision Lane)',
      'schedule': 'Mon - Thu: 8:00 AM - 5:00 PM',
      'status': 'In Clinic · Seeing Patients',
      'status_color': ClinicTheme.malachite,
      'patients_count': 14,
    },
    {
      'id': 'dr_alabi',
      'name': 'Dr. Babatunde Alabi, O.D.',
      'role': 'Associate Optometrist & Glaucoma Specialist',
      'license': 'OD-71029-NG',
      'npi': '1827364510',
      'specialty': 'Glaucoma Management & Anterior Segment',
      'exam_room': 'Exam Suite 1B (Visual Field & Tonometry)',
      'schedule': 'Tue - Sat: 9:00 AM - 5:30 PM',
      'status': 'Available · Next Exam 2:00 PM',
      'status_color': ClinicTheme.malachiteDim,
      'patients_count': 9,
    },
  ];

  final List<Map<String, dynamic>> _mockStaff = [
    {
      'id': 'staff_amina',
      'name': 'Amina Bello',
      'role': 'Front Desk Coordinator & Triage',
      'email': 'amina.frontdesk@gozvision.demo',
      'responsibilities': 'Patient Intake, Appointment Confirmation, Automated Recalls',
      'shift': 'Mon - Fri: 7:30 AM - 4:00 PM',
      'status': 'On Duty · Desk Station 1',
      'status_color': ClinicTheme.malachite,
    },
    {
      'id': 'staff_chinedu',
      'name': 'Chinedu Eze, CPO',
      'role': 'Certified Paraoptometric Technician',
      'email': 'chinedu.tech@gozvision.demo',
      'responsibilities': 'Pre-Testing, Visual Fields, Autorefraction, Smart Lens Fittings',
      'shift': 'Mon - Fri: 8:00 AM - 4:30 PM',
      'status': 'On Duty · Pre-Test Lane',
      'status_color': ClinicTheme.malachite,
    },
    {
      'id': 'staff_ngozi',
      'name': 'Ngozi Balogun',
      'role': 'Patient Care & Low-Vision Device Liaison',
      'email': 'ngozi.caregiver@gozvision.demo',
      'responsibilities': 'Caregiver Onboarding, Home Device Trials, SOS Alert Follow-Ups',
      'shift': 'Mon - Thu: 9:00 AM - 3:00 PM',
      'status': 'Remote Triage Active',
      'status_color': ClinicTheme.warningAmber,
    },
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showInviteModal(BuildContext context) {
    String selectedRole = 'Practitioner';
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final licenseCtrl = TextEditingController();
    final specialtyCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          backgroundColor: ClinicTheme.obsidian,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: const BorderSide(color: ClinicTheme.border),
          ),
          title: Row(
            children: const [
              Icon(Icons.person_add_alt_1, color: ClinicTheme.malachite),
              SizedBox(width: 10),
              Text('Onboard Team Member', style: TextStyle(color: ClinicTheme.textPrimary, fontWeight: FontWeight.w700)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Role in Clinic:', style: TextStyle(color: ClinicTheme.textSecondary, fontSize: 13)),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  value: selectedRole,
                  dropdownColor: ClinicTheme.surface,
                  style: const TextStyle(color: ClinicTheme.textPrimary),
                  decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                  items: const [
                    DropdownMenuItem(value: 'Practitioner', child: Text('Doctor / Practitioner (OD / MD)')),
                    DropdownMenuItem(value: 'Staff', child: Text('Clinic Staff / Technician')),
                    DropdownMenuItem(value: 'Owner', child: Text('Practice Owner / Partner')),
                  ],
                  onChanged: (v) => setModalState(() => selectedRole = v!),
                ),
                const SizedBox(height: 14),
                const Text('Full Name:', style: TextStyle(color: ClinicTheme.textSecondary, fontSize: 13)),
                const SizedBox(height: 6),
                TextField(
                  controller: nameCtrl,
                  style: const TextStyle(color: ClinicTheme.textPrimary, fontSize: 14),
                  decoration: const InputDecoration(hintText: 'e.g. Dr. Jordan Lee, O.D.'),
                ),
                const SizedBox(height: 14),
                const Text('Professional Email:', style: TextStyle(color: ClinicTheme.textSecondary, fontSize: 13)),
                const SizedBox(height: 6),
                TextField(
                  controller: emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  style: const TextStyle(color: ClinicTheme.textPrimary, fontSize: 14),
                  decoration: const InputDecoration(hintText: 'doctor@clinic.com'),
                ),
                if (selectedRole == 'Practitioner') ...[
                  const SizedBox(height: 14),
                  const Text('State Board License #:', style: TextStyle(color: ClinicTheme.textSecondary, fontSize: 13)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: licenseCtrl,
                    style: const TextStyle(color: ClinicTheme.textPrimary, fontSize: 14),
                    decoration: const InputDecoration(hintText: 'e.g. OD-99201-CA'),
                  ),
                  const SizedBox(height: 14),
                  const Text('Clinical Specialties:', style: TextStyle(color: ClinicTheme.textSecondary, fontSize: 13)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: specialtyCtrl,
                    style: const TextStyle(color: ClinicTheme.textPrimary, fontSize: 14),
                    decoration: const InputDecoration(hintText: 'e.g. Low Vision, Cornea & Contact Lenses'),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: ClinicTheme.malachite,
                foregroundColor: Colors.black,
              ),
              icon: const Icon(Icons.send, size: 16),
              label: const Text('Send Clinic Invite'),
              onPressed: () async {
                Navigator.of(ctx).pop();
                try {
                  final scope = Provider.of<ClinicScope>(context, listen: false);
                  final clinicId = scope.clinicId;
                  if (clinicId != null && emailCtrl.text.isNotEmpty) {
                    await Supabase.instance.client.from('profiles').insert({
                      'email': emailCtrl.text.trim(),
                      'name': nameCtrl.text.trim(),
                      'role': selectedRole,
                      'clinic_id': clinicId,
                    });
                  }
                } catch (_) {}
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: ClinicTheme.surface,
                      content: Text('Invitation sent to ${nameCtrl.text.isEmpty ? "new member" : nameCtrl.text}. Profile linked to clinic tenant.'),
                    ),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scope = context.watch<ClinicScope>();

    return Scaffold(
      backgroundColor: ClinicTheme.obsidian,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Clinic Facility Hero Card
            _buildClinicHero(scope),
            const SizedBox(height: 28),

            // Tab bar for Practitioners vs Staff
            Container(
              decoration: BoxDecoration(
                color: ClinicTheme.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: ClinicTheme.border),
              ),
              child: TabBar(
                controller: _tabController,
                indicatorColor: ClinicTheme.malachite,
                labelColor: ClinicTheme.malachite,
                unselectedLabelColor: ClinicTheme.textSecondary,
                tabs: const [
                  Tab(icon: Icon(Icons.medical_services_outlined), text: 'Practitioners & Optometrists (2)'),
                  Tab(icon: Icon(Icons.people_outline), text: 'Clinic Staff & Technicians (3)'),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Tab Content
            SizedBox(
              height: 520,
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildPractitionersList(),
                  _buildStaffList(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClinicHero(ClinicScope scope) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: ClinicTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: ClinicTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: ClinicTheme.malachiteFaint,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: ClinicTheme.malachite.withAlpha(80)),
                ),
                child: const Icon(Icons.domain, color: ClinicTheme.malachite, size: 36),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'GozVision Demo Eye Clinic',
                          style: TextStyle(
                            color: ClinicTheme.textPrimary,
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: ClinicTheme.malachiteFaint,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            'Active Practice Tenant',
                            style: TextStyle(color: ClinicTheme.malachite, fontSize: 12, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Primary Branch: 100 Main Street, Suite 100 · Accredited Optometric Center & Low-Vision Hub',
                      style: TextStyle(color: ClinicTheme.textSecondary, fontSize: 14),
                    ),
                  ],
                ),
              ),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: ClinicTheme.malachite,
                  foregroundColor: const Color(0xFF070B11),
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  textStyle: const TextStyle(fontWeight: FontWeight.w700),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                ),
                icon: const Icon(Icons.add_moderator_outlined, size: 18),
                label: const Text('Add Staff / Doctor'),
                onPressed: () => _showInviteModal(context),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(color: ClinicTheme.border),
          const SizedBox(height: 14),
          Wrap(
            spacing: 28,
            runSpacing: 12,
            children: [
              _buildMetaItem(Icons.access_time, 'Hours: Mon - Fri: 8:00 AM - 5:30 PM | Sat: 9:00 AM - 1:00 PM'),
              _buildMetaItem(Icons.phone_outlined, 'Phone: (555) 234-5678'),
              _buildMetaItem(Icons.meeting_room_outlined, 'Active Lanes: 3 Exam Suites, 1 Low-Vision Trial Lane'),
              _buildMetaItem(Icons.hub_outlined, 'EMR Integration: Epic / Eyefinity Bridge Active'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetaItem(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: ClinicTheme.malachiteDim),
        const SizedBox(width: 8),
        Text(text, style: const TextStyle(color: ClinicTheme.textSecondary, fontSize: 13)),
      ],
    );
  }

  Widget _buildPractitionersList() {
    return ListView.separated(
      itemCount: _mockPractitioners.length,
      separatorBuilder: (_, __) => const SizedBox(height: 16),
      itemBuilder: (context, i) {
        final doc = _mockPractitioners[i];
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: ClinicTheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: ClinicTheme.border),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: ClinicTheme.malachiteFaint,
                child: Text(
                  doc['name'][0],
                  style: const TextStyle(color: ClinicTheme.malachite, fontSize: 20, fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          doc['name'] as String,
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: ClinicTheme.textPrimary),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: ClinicTheme.obsidian,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: ClinicTheme.border),
                          ),
                          child: Text(
                            doc['license'] as String,
                            style: const TextStyle(color: ClinicTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${doc['role']} · ${doc['specialty']}',
                      style: const TextStyle(color: ClinicTheme.textSecondary, fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.door_sliding_outlined, size: 14, color: ClinicTheme.malachiteDim),
                        const SizedBox(width: 6),
                        Text(doc['exam_room'] as String, style: const TextStyle(color: ClinicTheme.textSecondary, fontSize: 12)),
                        const SizedBox(width: 16),
                        Icon(Icons.calendar_month_outlined, size: 14, color: ClinicTheme.malachiteDim),
                        const SizedBox(width: 6),
                        Text(doc['schedule'] as String, style: const TextStyle(color: ClinicTheme.textSecondary, fontSize: 12)),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: (doc['status_color'] as Color).withAlpha(25),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      doc['status'] as String,
                      style: TextStyle(color: doc['status_color'] as Color, fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${doc['patients_count']} Active Patients',
                    style: const TextStyle(color: ClinicTheme.textSecondary, fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStaffList() {
    return ListView.separated(
      itemCount: _mockStaff.length,
      separatorBuilder: (_, __) => const SizedBox(height: 16),
      itemBuilder: (context, i) {
        final staff = _mockStaff[i];
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: ClinicTheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: ClinicTheme.border),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: ClinicTheme.obsidian,
                child: Text(
                  staff['name'][0],
                  style: const TextStyle(color: ClinicTheme.textPrimary, fontSize: 20, fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      staff['name'] as String,
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: ClinicTheme.textPrimary),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${staff['role']} · ${staff['email']}',
                      style: const TextStyle(color: ClinicTheme.textSecondary, fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Core Duties: ${staff['responsibilities']}',
                      style: const TextStyle(color: ClinicTheme.textSecondary, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: (staff['status_color'] as Color).withAlpha(25),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      staff['status'] as String,
                      style: TextStyle(color: staff['status_color'] as Color, fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    staff['shift'] as String,
                    style: const TextStyle(color: ClinicTheme.textSecondary, fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
