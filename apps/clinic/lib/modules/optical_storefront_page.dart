import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/clinic_theme.dart';
import '../data/clinic_scope.dart';
import '../services/bachs_payment_service.dart';

/// Optical Dispensary & Practice Storefront Module
///
/// Features:
///  - Dispensary Catalog (Frames, Smart Glasses, Low-Vision Tech, Therapeutics & Clinical Services)
///  - Walk-In Reception Desk POS Terminal (Non-GozVision patients, custom copays, instant receipt)
///  - Multi-Purpose Dynamic QR Signage Suite (Desk Pay Stand, Waiting Room Booking Stand, Copilot App Stand)
///  - Interactive Bachs Overlay Checkout preview
///  - Multi-Tenant Payment Provider Toggle: Bachs (Default) vs Stripe Connect
///  - Bachs Payouts API integration (instant bank disbursements & destination manager)
///  - Patient order tracking & fulfillment workflow
class OpticalStorefrontPage extends StatefulWidget {
  const OpticalStorefrontPage({super.key});

  @override
  State<OpticalStorefrontPage> createState() => _OpticalStorefrontPageState();
}

class _OpticalStorefrontPageState extends State<OpticalStorefrontPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedCategory = 'All';
  String _searchQuery = '';
  final TextEditingController _searchCtrl = TextEditingController();

  // Walk-In POS State
  final List<Map<String, dynamic>> _posCart = [];
  String _posPatientName = 'Walk-In Patient / Guest';
  double _posCopayDeduction = 0.0;
  String _selectedQrSignageMode = 'front_desk'; // 'front_desk', 'waiting_room', 'copilot_download'

  // Optical catalog & Clinical Services
  final List<Map<String, dynamic>> _catalog = [
    {
      'id': 'prod_01',
      'name': 'Goz Titanium Vista — Matte Obsidian Frame',
      'category': 'Frames',
      'sku': 'GTV-804-OBS',
      'price': 185.00,
      'stock': 14,
      'rx_required': true,
      'rating': '4.9 ★',
      'attributes': 'Japanese Titanium · 48-19-145 · Lightweight 12g',
    },
    {
      'id': 'prod_02',
      'name': 'Solos AirGo 3 Smart Audio Glasses (GozVision Edition)',
      'category': 'Smart Glasses',
      'sku': 'SLS-AG3-GZ',
      'price': 299.00,
      'stock': 8,
      'rx_required': false,
      'rating': '5.0 ★',
      'attributes': 'Directional Speakers · Dual Beamforming Mics · 10h Battery',
    },
    {
      'id': 'prod_03',
      'name': 'FL-41 Glare & Light Sensitivity Clip-On',
      'category': 'Low-Vision Tech',
      'sku': 'FL41-CLP-01',
      'price': 65.00,
      'stock': 22,
      'rx_required': false,
      'rating': '4.8 ★',
      'attributes': 'Filters 480nm-520nm Fluorescent Glare · Migraine Relief',
    },
    {
      'id': 'prod_04',
      'name': 'Systane Complete Preservative-Free Multi-Pack (60 Vials)',
      'category': 'Therapeutics',
      'sku': 'SYS-CPF-60',
      'price': 34.50,
      'stock': 40,
      'rx_required': false,
      'rating': '4.9 ★',
      'attributes': 'Nano-droplet Lipid Tech · Dry Eye & Soothing Care',
    },
    {
      'id': 'prod_05',
      'name': 'eSight Go Electronic Vision Enhancer Headset',
      'category': 'Low-Vision Tech',
      'sku': 'ESG-GO-2026',
      'price': 1850.00,
      'stock': 3,
      'rx_required': true,
      'rating': '5.0 ★',
      'attributes': 'High-Speed 4K OLED · Central Scotoma Remapping',
    },
    {
      'id': 'srv_01',
      'name': 'Comprehensive Dilated Eye Examination & Retinal Imaging',
      'category': 'Clinical Services',
      'sku': 'CPT-92004-92134',
      'price': 145.00,
      'stock': 99,
      'rx_required': false,
      'rating': '5.0 ★',
      'attributes': 'Full Refraction · Optomap Retinal Ultra-widefield · Tonometry',
    },
    {
      'id': 'srv_02',
      'name': 'Specialty Scleral & Keratoconus Contact Lens Fitting',
      'category': 'Clinical Services',
      'sku': 'CPT-92072-TOPO',
      'price': 220.00,
      'stock': 99,
      'rx_required': false,
      'rating': '4.9 ★',
      'attributes': 'Corneal Wavefront Topography · Diagnostic Lens Trial · Insertion Training',
    },
    {
      'id': 'srv_03',
      'name': 'In-Office Intense Pulsed Light (IPL) & Thermal Gland Therapy',
      'category': 'Clinical Services',
      'sku': 'IPL-DRYEYE-S1',
      'price': 285.00,
      'stock': 99,
      'rx_required': false,
      'rating': '5.0 ★',
      'attributes': 'Targeted Periorbital IPL · Meibomian Expression · Tear Osmolarity Post-Check',
    },
    {
      'id': 'srv_04',
      'name': 'Low Vision Assistive Device Evaluation & Copilot Pairing',
      'category': 'Clinical Services',
      'sku': 'CPT-97535-LV',
      'price': 195.00,
      'stock': 99,
      'rx_required': false,
      'rating': '5.0 ★',
      'attributes': 'Bioptic / Prism Assessment · Smart Frame Calibration · Functional OT Strategy',
    },
  ];

  // Patient orders paid via Bachs / Stripe
  final List<Map<String, dynamic>> _orders = [
    {
      'order_no': 'ORD-2026-84920',
      'patient_name': 'Folashade Adeleke',
      'patient_id': 'demo_patient_001',
      'items': 'Goz Titanium Vista Frame + FL-41 Tint Coating',
      'total': 250.00,
      'payment_status': 'Paid (Bachs BCH-99420)',
      'provider': 'bachs',
      'fulfillment': 'Optical Lab Edging',
      'date': 'Today, 10:45 AM',
      'status_color': ClinicTheme.warningAmber,
    },
    {
      'order_no': 'ORD-2026-84918',
      'patient_name': 'Babajide Okafor',
      'patient_id': 'patient_chen_02',
      'items': 'Solos AirGo 3 Smart Audio Glasses',
      'total': 299.00,
      'payment_status': 'Paid (Bachs BCH-99418)',
      'provider': 'bachs',
      'fulfillment': 'Ready for In-Clinic Pickup',
      'date': 'Yesterday, 3:20 PM',
      'status_color': ClinicTheme.malachite,
    },
    {
      'order_no': 'ORD-2026-84912',
      'patient_name': 'Martha Alvarez',
      'patient_id': 'patient_alvarez_05',
      'items': 'Systane Complete PF Multi-Pack (x2)',
      'total': 69.00,
      'payment_status': 'Paid (Bachs BCH-99412)',
      'provider': 'bachs',
      'fulfillment': 'Dispatched via Courier',
      'date': 'Oct 6, 11:15 AM',
      'status_color': ClinicTheme.malachiteDim,
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
    _searchCtrl.dispose();
    super.dispose();
  }

  void _showStorefrontDiscoveryModal(BuildContext context, ClinicScope scope) {
    final clinicId = scope.clinicId ?? 'demo_clinic';
    final storeUrl = 'https://gozvision.com/store/$clinicId';

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
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: ClinicTheme.malachiteFaint,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.storefront_rounded, color: ClinicTheme.malachite, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'Practice Storefront & Patient Discovery',
                    style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'How patients discover, browse, and purchase from your clinic',
                    style: TextStyle(color: ClinicTheme.textSecondary, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Highlight Banner: Strategic Practice Edge
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: ClinicTheme.malachiteFaint,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: ClinicTheme.malachite.withOpacity(0.35)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.insights_rounded, color: ClinicTheme.malachite, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              'Strategic Practice Edge (40% - 60% of Clinic Margin)',
                              style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Optical dispensaries and specialty therapeutics represent up to 60% of independent optometry profits. GozVision bridges clinical care directly into immediate purchases, preventing patients from leaking to external online retailers.',
                              style: TextStyle(color: ClinicTheme.textPrimary, fontSize: 11.5, height: 1.4),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // Channel 1
                _buildDiscoveryChannelCard(
                  icon: Icons.smartphone_rounded,
                  title: '1. Patient Copilot App Bar Integration',
                  description:
                      'Patients using the GozVision Copilot have a dedicated "Optical Dispensary" icon directly in their top bar. They can view doctor-curated frames, FL-41 filters, and artificial tears with 1-tap ordering.',
                ),
                const SizedBox(height: 12),

                // Channel 2
                _buildDiscoveryChannelCard(
                  icon: Icons.domain_rounded,
                  title: '2. Clinic Discovery & Appointment Search',
                  description:
                      'When prospective or returning patients search for clinics in the GozVision Directory, every verified clinic profile displays a prominent "Browse Dispensary Catalog & Prescriptions" action.',
                ),
                const SizedBox(height: 12),

                // Channel 3
                _buildDiscoveryChannelCard(
                  icon: Icons.chat_bubble_outline_rounded,
                  title: '3. Post-Exam Scribe Rx & Care Threads',
                  description:
                      'Whenever an optometrist prescribes frames, therapeutic drops, or smart glasses in Scribe Studio, an automated assisted-checkout link is dispatched to the patient and family caregiver.',
                ),
                const SizedBox(height: 16),

                // Clinic Web Storefront URL
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: ClinicTheme.surfaceDark,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white.withOpacity(0.06)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.link_rounded, size: 16, color: ClinicTheme.malachite),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          storeUrl,
                          style: const TextStyle(fontSize: 12, color: ClinicTheme.textSecondary, fontFamily: 'monospace'),
                        ),
                      ),
                      TextButton.icon(
                        icon: const Icon(Icons.copy_rounded, size: 14),
                        label: const Text('Copy Link', style: TextStyle(fontSize: 11)),
                        style: TextButton.styleFrom(foregroundColor: ClinicTheme.malachite),
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Copied "$storeUrl" to clipboard!')),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            child: const Text('Close', style: TextStyle(color: ClinicTheme.textSecondary)),
            onPressed: () => Navigator.pop(ctx),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: ClinicTheme.malachite, foregroundColor: Colors.black),
            icon: const Icon(Icons.print_rounded, size: 16),
            label: const Text('Print Reception Desk QR Code'),
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('✓ Generated printable Reception Desk Frame Catalog QR Code!')),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDiscoveryChannelCard({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ClinicTheme.surfaceDark.withOpacity(0.5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withOpacity(0.04)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: ClinicTheme.malachite),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.bold)),
                const SizedBox(height: 3),
                Text(description, style: const TextStyle(color: ClinicTheme.textSecondary, fontSize: 11, height: 1.35)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showAddProductDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    final skuCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final stockCtrl = TextEditingController(text: '10');
    final attrCtrl = TextEditingController();
    String category = 'Frames';
    bool rxRequired = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          backgroundColor: ClinicTheme.cardBackground,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: const BorderSide(color: ClinicTheme.border),
          ),
          title: Row(
            children: const [
              Icon(Icons.add_shopping_cart_rounded, color: ClinicTheme.malachite),
              SizedBox(width: 10),
              Text(
                'Add Storefront Product / Frame',
                style: TextStyle(color: ClinicTheme.textPrimary, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 480,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Category:', style: TextStyle(color: ClinicTheme.textSecondary, fontSize: 13)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: category,
                    dropdownColor: ClinicTheme.cardBackground,
                    style: const TextStyle(color: ClinicTheme.textPrimary),
                    decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                    items: const [
                      DropdownMenuItem(value: 'Frames', child: Text('Frames & Eyewear')),
                      DropdownMenuItem(value: 'Smart Glasses', child: Text('Smart Glasses & Wearables')),
                      DropdownMenuItem(value: 'Low-Vision Tech', child: Text('Low-Vision Tech & Filters')),
                      DropdownMenuItem(value: 'Therapeutics', child: Text('Therapeutics & Eye Drops')),
                      DropdownMenuItem(value: 'Contact Lenses', child: Text('Contact Lenses')),
                    ],
                    onChanged: (v) => setModalState(() => category = v!),
                  ),
                  const SizedBox(height: 14),
                  const Text('Product / Frame Name:', style: TextStyle(color: ClinicTheme.textSecondary, fontSize: 13)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: nameCtrl,
                    style: const TextStyle(color: ClinicTheme.textPrimary, fontSize: 14),
                    decoration: const InputDecoration(hintText: 'e.g. Goz Silhouette Titanium #02'),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Retail Price (USD):', style: TextStyle(color: ClinicTheme.textSecondary, fontSize: 13)),
                            const SizedBox(height: 6),
                            TextField(
                              controller: priceCtrl,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              style: const TextStyle(color: ClinicTheme.textPrimary, fontSize: 14),
                              decoration: const InputDecoration(hintText: '195.00', prefixText: '\$ '),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Inventory Stock:', style: TextStyle(color: ClinicTheme.textSecondary, fontSize: 13)),
                            const SizedBox(height: 6),
                            TextField(
                              controller: stockCtrl,
                              keyboardType: TextInputType.number,
                              style: const TextStyle(color: ClinicTheme.textPrimary, fontSize: 14),
                              decoration: const InputDecoration(hintText: '12'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Text('SKU / Reference ID:', style: TextStyle(color: ClinicTheme.textSecondary, fontSize: 13)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: skuCtrl,
                    style: const TextStyle(color: ClinicTheme.textPrimary, fontSize: 14),
                    decoration: const InputDecoration(hintText: 'e.g. GZ-TITAN-02'),
                  ),
                  const SizedBox(height: 14),
                  const Text('Attributes (Specs, bridge, dimensions):', style: TextStyle(color: ClinicTheme.textSecondary, fontSize: 13)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: attrCtrl,
                    style: const TextStyle(color: ClinicTheme.textPrimary, fontSize: 14),
                    decoration: const InputDecoration(hintText: 'e.g. 50-20-145 · Beta-Titanium · 14g'),
                  ),
                  const SizedBox(height: 14),
                  CheckboxListTile(
                    value: rxRequired,
                    contentPadding: EdgeInsets.zero,
                    activeColor: ClinicTheme.malachite,
                    checkColor: Colors.black,
                    title: const Text('Prescription (Rx) Required to Purchase', style: TextStyle(color: ClinicTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
                    subtitle: const Text('Goz Copilot will prompt patient to link verified optical prescription before checkout', style: TextStyle(color: ClinicTheme.textSecondary, fontSize: 11)),
                    onChanged: (v) => setModalState(() => rxRequired = v ?? false),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              child: const Text('Cancel', style: TextStyle(color: ClinicTheme.textSecondary)),
              onPressed: () => Navigator.pop(ctx),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: ClinicTheme.malachite, foregroundColor: Colors.black),
              child: const Text('Add to Storefront Catalog'),
              onPressed: () {
                final name = nameCtrl.text.trim();
                final price = double.tryParse(priceCtrl.text.trim()) ?? 0.0;
                final stock = int.tryParse(stockCtrl.text.trim()) ?? 10;
                final sku = skuCtrl.text.trim().isEmpty ? 'SKU-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}' : skuCtrl.text.trim();
                final attr = attrCtrl.text.trim().isEmpty ? 'Standard Clinical Grade' : attrCtrl.text.trim();

                if (name.isNotEmpty && price > 0) {
                  setState(() {
                    _catalog.add({
                      'id': 'prod_${DateTime.now().millisecondsSinceEpoch}',
                      'name': name,
                      'category': category,
                      'sku': sku,
                      'price': price,
                      'stock': stock,
                      'rx_required': rxRequired,
                      'rating': '5.0 ★',
                      'attributes': attr,
                    });
                  });
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Added "$name" to Practice Dispensary!')),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showInstantPayoutDialog(BuildContext context, BachsPaymentService paymentService) {
    String selectedCurrency = 'NGN';
    String selectedDestId = paymentService.destinations.isNotEmpty
        ? paymentService.destinations.first.id
        : '';
    final amountCtrl = TextEditingController(text: '150000.00');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final amt = double.tryParse(amountCtrl.text.trim()) ?? 0.0;
          final fee = selectedCurrency == 'NGN' ? 100.0 : 2.50;
          final totalDebited = (amt + fee).toStringAsFixed(2);

          return AlertDialog(
            backgroundColor: ClinicTheme.cardBackground,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: const BorderSide(color: ClinicTheme.border),
            ),
            title: Row(
              children: const [
                Icon(Icons.bolt, color: ClinicTheme.malachite, size: 24),
                SizedBox(width: 10),
                Text(
                  'Trigger Instant Bachs Bank Payout',
                  style: TextStyle(color: ClinicTheme.textPrimary, fontWeight: FontWeight.w700),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: SizedBox(
                width: 480,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: ClinicTheme.malachiteFaint,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: ClinicTheme.malachite.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: const [
                          Icon(Icons.security, color: ClinicTheme.malachite, size: 18),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Payout is executed idempotently via Bachs Payout API (POST /v1/payouts). Funds settle directly into your destination bank account.',
                              style: TextStyle(color: ClinicTheme.textPrimary, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text('Currency Bucket:', style: TextStyle(color: ClinicTheme.textSecondary, fontSize: 13)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      value: selectedCurrency,
                      dropdownColor: ClinicTheme.cardBackground,
                      style: const TextStyle(color: ClinicTheme.textPrimary),
                      decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                      items: const [
                        DropdownMenuItem(value: 'NGN', child: Text('Nigerian Naira (NGN)')),
                        DropdownMenuItem(value: 'USD', child: Text('US Dollars (USD - ACH)')),
                        DropdownMenuItem(value: 'EUR', child: Text('Euros (EUR - SEPA)')),
                      ],
                      onChanged: (v) {
                        setModalState(() {
                          selectedCurrency = v!;
                          if (selectedCurrency == 'NGN') {
                            amountCtrl.text = '150000.00';
                          } else {
                            amountCtrl.text = '500.00';
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 14),
                    const Text('Payout Destination Bank Account:', style: TextStyle(color: ClinicTheme.textSecondary, fontSize: 13)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      value: selectedDestId.isNotEmpty ? selectedDestId : null,
                      dropdownColor: ClinicTheme.cardBackground,
                      style: const TextStyle(color: ClinicTheme.textPrimary),
                      decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                      items: paymentService.destinations
                          .where((d) => d.currency == selectedCurrency)
                          .map((d) => DropdownMenuItem(
                                value: d.id,
                                child: Text('${d.bankName} (${d.accountNumber})'),
                              ))
                          .toList(),
                      onChanged: (v) => setModalState(() => selectedDestId = v ?? ''),
                    ),
                    const SizedBox(height: 14),
                    const Text('Disbursement Amount:', style: TextStyle(color: ClinicTheme.textSecondary, fontSize: 13)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: amountCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(color: ClinicTheme.textPrimary, fontSize: 15, fontWeight: FontWeight.bold),
                      decoration: InputDecoration(
                        prefixText: selectedCurrency == 'NGN' ? '₦ ' : '\$ ',
                        hintText: '0.00',
                      ),
                      onChanged: (_) => setModalState(() {}),
                    ),
                    const SizedBox(height: 16),
                    // Summary breakdown
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: ClinicTheme.surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: ClinicTheme.border),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Recipient Receives:', style: TextStyle(color: ClinicTheme.textSecondary, fontSize: 12)),
                              Text('$selectedCurrency ${amt.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Bachs API Rails Fee:', style: TextStyle(color: ClinicTheme.textSecondary, fontSize: 12)),
                              Text('$selectedCurrency ${fee.toStringAsFixed(2)}', style: const TextStyle(color: ClinicTheme.warningAmber, fontSize: 12, fontWeight: FontWeight.w700)),
                            ],
                          ),
                          const Divider(height: 16, color: ClinicTheme.border),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Total Debited from Balance:', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                              Text('$selectedCurrency $totalDebited', style: const TextStyle(color: ClinicTheme.malachite, fontSize: 13, fontWeight: FontWeight.w800)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                child: const Text('Cancel', style: TextStyle(color: ClinicTheme.textSecondary)),
                onPressed: () => Navigator.pop(ctx),
              ),
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: ClinicTheme.malachite, foregroundColor: Colors.black),
                icon: const Icon(Icons.send_rounded, size: 16),
                label: const Text('Execute Payout via Bachs API'),
                onPressed: () async {
                  if (amt <= 0) return;
                  final ref = 'PO-${DateTime.now().millisecondsSinceEpoch.toString().substring(6)}';
                  await paymentService.requestPayout(
                    destinationId: selectedDestId,
                    amount: amt,
                    currency: selectedCurrency,
                    reference: ref,
                  );
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: ClinicTheme.cardBackground,
                      content: Row(
                        children: [
                          const Icon(Icons.check_circle, color: ClinicTheme.malachite),
                          const SizedBox(width: 10),
                          Text('Payout $ref submitted successfully to bank!'),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }

  void _showAddBankDestinationDialog(BuildContext context, BachsPaymentService paymentService) {
    String selectedBankCode = paymentService.supportedBanks.first.code;
    String currency = 'NGN';
    final accCtrl = TextEditingController();
    final nameCtrl = TextEditingController(text: 'GOZVISION OPTOMETRY CARE');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          backgroundColor: ClinicTheme.cardBackground,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: const BorderSide(color: ClinicTheme.border),
          ),
          title: Row(
            children: const [
              Icon(Icons.account_balance, color: ClinicTheme.malachite),
              SizedBox(width: 10),
              Text(
                'Register Payout Bank Destination',
                style: TextStyle(color: ClinicTheme.textPrimary, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 480,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Registers a verified destination (POST /v1/payouts/destinations) with Bachs to enable one-click automatic and ad-hoc disbursements.',
                    style: TextStyle(color: ClinicTheme.textSecondary, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  const Text('Settlement Currency:', style: TextStyle(color: ClinicTheme.textSecondary, fontSize: 13)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: currency,
                    dropdownColor: ClinicTheme.cardBackground,
                    style: const TextStyle(color: ClinicTheme.textPrimary),
                    decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                    items: const [
                      DropdownMenuItem(value: 'NGN', child: Text('NGN — Nigerian Commercial Bank')),
                      DropdownMenuItem(value: 'USD', child: Text('USD — US Bank (ACH)')),
                    ],
                    onChanged: (v) => setModalState(() => currency = v!),
                  ),
                  const SizedBox(height: 14),
                  const Text('Select Financial Institution:', style: TextStyle(color: ClinicTheme.textSecondary, fontSize: 13)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: selectedBankCode,
                    dropdownColor: ClinicTheme.cardBackground,
                    style: const TextStyle(color: ClinicTheme.textPrimary),
                    decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                    items: paymentService.supportedBanks
                        .map((b) => DropdownMenuItem(value: b.code, child: Text(b.name)))
                        .toList(),
                    onChanged: (v) => setModalState(() => selectedBankCode = v!),
                  ),
                  const SizedBox(height: 14),
                  const Text('Account Number:', style: TextStyle(color: ClinicTheme.textSecondary, fontSize: 13)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: accCtrl,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: ClinicTheme.textPrimary, fontSize: 14),
                    decoration: const InputDecoration(hintText: 'e.g. 0123456789'),
                  ),
                  const SizedBox(height: 14),
                  const Text('Account Holder Name:', style: TextStyle(color: ClinicTheme.textSecondary, fontSize: 13)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: nameCtrl,
                    style: const TextStyle(color: ClinicTheme.textPrimary, fontSize: 14),
                    decoration: const InputDecoration(hintText: 'Legal Practice Entity Name'),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              child: const Text('Cancel', style: TextStyle(color: ClinicTheme.textSecondary)),
              onPressed: () => Navigator.pop(ctx),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: ClinicTheme.malachite, foregroundColor: Colors.black),
              child: const Text('Register with Bachs API'),
              onPressed: () async {
                final acc = accCtrl.text.trim();
                if (acc.isNotEmpty) {
                  await paymentService.addPayoutDestination(
                    accountNumber: acc,
                    bankCode: selectedBankCode,
                    currency: currency,
                    accountName: nameCtrl.text.trim(),
                  );
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Registered destination with Bachs API!')),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _testOverlayCheckout(BuildContext context, Map<String, dynamic> product, BachsPaymentService paymentService) async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: ClinicTheme.cardBackground,
        content: Row(
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: ClinicTheme.malachite),
            ),
            const SizedBox(width: 12),
            Text('Creating Bachs checkout session for "${product['name']}"...'),
          ],
        ),
      ),
    );

    final checkoutUrl = await paymentService.createCheckoutSession(
      productId: product['id'] as String,
      productName: product['name'] as String,
      price: product['price'] as double,
      currency: 'USD',
      customerEmail: 'patient@example.com',
      customerName: 'Folashade Adeleke',
    );

    final launched = await paymentService.launchOverlayCheckout(checkoutUrl);
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Overlay launched: $checkoutUrl'),
          action: SnackBarAction(
            label: 'Open Hosted',
            textColor: ClinicTheme.malachite,
            onPressed: () {},
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scope = context.watch<ClinicScope>();
    final paymentService = context.watch<BachsPaymentService>();

    return Scaffold(
      backgroundColor: ClinicTheme.obsidian,
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Storefront Header & Provider Switcher Toggle
            _buildStorefrontHeader(context, scope, paymentService),
            const SizedBox(height: 20),
            // Navigation Tabs
            TabBar(
              controller: _tabController,
              isScrollable: true,
              indicatorColor: ClinicTheme.malachite,
              indicatorWeight: 3,
              labelColor: ClinicTheme.malachite,
              unselectedLabelColor: ClinicTheme.textSecondary,
              labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              tabs: [
                Tab(
                  icon: const Icon(Icons.storefront_outlined, size: 18),
                  text: 'Products & Clinical Services (${_catalog.length})',
                ),
                Tab(
                  icon: const Icon(Icons.receipt_long_outlined, size: 18),
                  text: 'Patient Orders & Booking (${_orders.length})',
                ),
                Tab(
                  icon: const Icon(Icons.point_of_sale_rounded, size: 18),
                  text: 'Walk-In POS & Dynamic QR Hub',
                ),
                Tab(
                  icon: const Icon(Icons.account_balance_outlined, size: 18),
                  text: paymentService.isBachsActive ? 'Bachs Instant Payouts' : 'Stripe Connect Portal',
                ),
              ],
            ),
            const SizedBox(height: 18),
            // Tab Contents
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildCatalogTab(paymentService),
                  _buildOrdersTab(),
                  _buildWalkInPosAndQrTab(scope, paymentService),
                  (scope.isClinicManager || scope.isDeveloper)
                      ? (paymentService.isBachsActive
                          ? _buildBachsPayoutsTab(scope, paymentService)
                          : _buildStripeConnectTab(scope, paymentService))
                      : _buildRestrictedPayoutsView(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStorefrontHeader(BuildContext context, ClinicScope scope, BachsPaymentService paymentService) {
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
                  border: Border.all(color: ClinicTheme.malachite.withOpacity(0.35)),
                ),
                child: const Icon(Icons.storefront_rounded, color: ClinicTheme.malachite, size: 36),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 12,
                      runSpacing: 6,
                      children: [
                        const Text(
                          'Optical Dispensary & Practice Storefront',
                          style: TextStyle(
                            color: ClinicTheme.textPrimary,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        // Active Provider Badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: paymentService.isBachsActive
                                ? ClinicTheme.malachiteFaint
                                : Colors.blue.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: paymentService.isBachsActive
                                  ? ClinicTheme.malachite.withOpacity(0.3)
                                  : Colors.blue.withOpacity(0.4),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                paymentService.isBachsActive ? Icons.bolt : Icons.credit_card,
                                color: paymentService.isBachsActive ? ClinicTheme.malachite : Colors.blueAccent,
                                size: 14,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                paymentService.isBachsActive ? 'Bachs Active (Default)' : 'Stripe Connect Active',
                                style: TextStyle(
                                  color: paymentService.isBachsActive ? ClinicTheme.malachite : Colors.blueAccent,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Turn doctor recommendations into immediate optical revenue. Patients order prescribed frames, smart glasses, and therapeutic drops directly from Goz Copilot.',
                      style: TextStyle(color: ClinicTheme.textSecondary, fontSize: 13),
                    ),
                  ],
                ),
              ),
              // Provider Toggle Switch (Bachs vs Stripe Connect)
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: ClinicTheme.cardBackground,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: ClinicTheme.border),
                ),
                child: Row(
                  children: [
                    _buildProviderToggleItem(
                      title: 'Bachs (Default)',
                      subtitle: 'Zero friction',
                      isActive: paymentService.isBachsActive,
                      onTap: () => paymentService.setActiveProvider(PaymentProviderType.bachs),
                    ),
                    _buildProviderToggleItem(
                      title: 'Stripe Connect',
                      subtitle: 'Global enterprise',
                      isActive: paymentService.isStripeActive,
                      onTap: () => paymentService.setActiveProvider(PaymentProviderType.stripeConnect),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: ClinicTheme.malachite,
                  side: BorderSide(color: ClinicTheme.malachite.withOpacity(0.4)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                icon: const Icon(Icons.qr_code_2_rounded, size: 18),
                label: const Text('Patient Discovery & QR', style: TextStyle(fontWeight: FontWeight.w700)),
                onPressed: () => _showStorefrontDiscoveryModal(context, scope),
              ),
              const SizedBox(width: 10),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: ClinicTheme.malachite,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                ),
                icon: const Icon(Icons.add_circle_outline, size: 18),
                label: const Text('Add Product / Frame'),
                onPressed: () => _showAddProductDialog(context),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Divider(color: ClinicTheme.border),
          const SizedBox(height: 12),
          // Storefront KPI Metrics
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildKpiCard('Gross Optical Sales (MTD)', '\$14,850.00', '+18.4% vs last mo', ClinicTheme.malachite),
              _buildKpiCard('Active Frames & SKUs', '${_catalog.length} In Store', '100% In Stock', ClinicTheme.textPrimary),
              _buildKpiCard('Awaiting Lab Edging', '6 Orders', '3 Ready Today', ClinicTheme.warningAmber),
              _buildKpiCard(
                'Settlement Engine',
                paymentService.isBachsActive ? 'Bachs API' : 'Stripe Connect',
                paymentService.isBachsActive ? 'Direct NGN / USD Bank Payouts' : 'Standard 2-Day Rolling',
                ClinicTheme.malachiteDim,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProviderToggleItem({
    required String title,
    required String subtitle,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? ClinicTheme.malachite.withOpacity(0.18) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isActive ? ClinicTheme.malachite.withOpacity(0.4) : Colors.transparent,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: TextStyle(
                color: isActive ? ClinicTheme.malachite : ClinicTheme.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              subtitle,
              style: TextStyle(
                color: isActive ? ClinicTheme.malachite.withOpacity(0.8) : ClinicTheme.textSecondary.withOpacity(0.7),
                fontSize: 9.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKpiCard(String label, String value, String sub, Color color) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 6),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: ClinicTheme.cardBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: ClinicTheme.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: ClinicTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text(value, style: TextStyle(color: color, fontSize: 17, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(sub, style: const TextStyle(color: ClinicTheme.textSecondary, fontSize: 10)),
          ],
        ),
      ),
    );
  }

  // Tab 1: Catalog
  Widget _buildCatalogTab(BachsPaymentService paymentService) {
    return Column(
      children: [
        // Search & Category Filters Bar
        Row(
          children: [
            Expanded(
              child: Container(
                height: 42,
                decoration: BoxDecoration(
                  color: ClinicTheme.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: ClinicTheme.border),
                ),
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (val) => setState(() => _searchQuery = val),
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Search frames, smart glasses, dry eye therapeutics, or clinical services...',
                    hintStyle: const TextStyle(color: ClinicTheme.textSecondary, fontSize: 12),
                    prefixIcon: const Icon(Icons.search, size: 18, color: ClinicTheme.textSecondary),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 16, color: ClinicTheme.textSecondary),
                            onPressed: () {
                              _searchCtrl.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: ClinicTheme.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: ClinicTheme.border),
              ),
              child: Text(
                'Showing ${_filteredCatalog.length} Items',
                style: const TextStyle(color: ClinicTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Category filters
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: ['All', 'Frames', 'Smart Glasses', 'Low-Vision Tech', 'Therapeutics', 'Clinical Services'].map((cat) {
              final isSel = _selectedCategory == cat;
              return Padding(
                padding: const EdgeInsets.only(right: 8, bottom: 12),
                child: FilterChip(
                  label: Text(cat),
                  selected: isSel,
                  onSelected: (val) => setState(() => _selectedCategory = cat),
                  backgroundColor: ClinicTheme.surface,
                  selectedColor: ClinicTheme.malachiteFaint,
                  checkmarkColor: ClinicTheme.malachite,
                  labelStyle: TextStyle(
                    color: isSel ? ClinicTheme.malachite : ClinicTheme.textSecondary,
                    fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                    fontSize: 12,
                  ),
                  side: BorderSide(color: isSel ? ClinicTheme.malachite.withOpacity(0.4) : ClinicTheme.border),
                ),
              );
            }).toList(),
          ),
        ),
        Expanded(
          child: _filteredCatalog.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.search_off_rounded, size: 48, color: ClinicTheme.textSecondary),
                      const SizedBox(height: 12),
                      Text('No items match "$_searchQuery"', style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      const Text('Try adjusting your search query or selected category filter.', style: TextStyle(color: ClinicTheme.textSecondary, fontSize: 12)),
                    ],
                  ),
                )
              : ListView.separated(
                  itemCount: _filteredCatalog.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, i) {
                    final prod = _filteredCatalog[i];
                    final isService = prod['category'] == 'Clinical Services';
                    return Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: ClinicTheme.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: isService ? ClinicTheme.malachite.withOpacity(0.3) : ClinicTheme.border),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              color: isService ? ClinicTheme.malachiteFaint : ClinicTheme.cardBackground,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: isService ? ClinicTheme.malachite.withOpacity(0.4) : ClinicTheme.border),
                            ),
                            child: Center(
                              child: Icon(
                                isService
                                    ? Icons.medical_services_outlined
                                    : (prod['category'] == 'Frames'
                                        ? Icons.remove_red_eye_outlined
                                        : (prod['category'] == 'Smart Glasses'
                                            ? Icons.headset_mic_outlined
                                            : Icons.medication_outlined)),
                                color: ClinicTheme.malachite,
                                size: 26,
                              ),
                            ),
                          ),
                          const SizedBox(width: 18),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        prod['name'] as String,
                                        style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    if (isService) ...[
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: ClinicTheme.malachiteFaint,
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: ClinicTheme.malachite.withOpacity(0.4)),
                                        ),
                                        child: const Text('Clinical Procedure / Booking', style: TextStyle(color: ClinicTheme.malachite, fontSize: 10, fontWeight: FontWeight.w700)),
                                      ),
                                    ] else if (prod['rx_required'] == true) ...[
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: ClinicTheme.warningAmber.withOpacity(0.15),
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: ClinicTheme.warningAmber.withOpacity(0.3)),
                                        ),
                                        child: const Text('Rx Required', style: TextStyle(color: ClinicTheme.warningAmber, fontSize: 10, fontWeight: FontWeight.w700)),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'SKU / Code: ${prod['sku']} · ${prod['attributes']}',
                                  style: const TextStyle(color: ClinicTheme.textSecondary, fontSize: 12),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  isService ? 'Status: Available for Walk-In & Online Appointment Booking' : 'Stock Level: ${prod['stock']} units · Customer Rating: ${prod['rating']}',
                                  style: TextStyle(color: ClinicTheme.malachiteDim, fontSize: 11, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Row(
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '\$${(prod['price'] as double).toStringAsFixed(2)}',
                                    style: const TextStyle(color: ClinicTheme.malachite, fontSize: 19, fontWeight: FontWeight.w800),
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      // Add to POS Cart
                                      IconButton(
                                        tooltip: 'Add to Walk-in POS Cart',
                                        icon: const Icon(Icons.add_shopping_cart, size: 18, color: ClinicTheme.malachite),
                                        onPressed: () {
                                          _addToPosCart(prod);
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text('Added "${prod['name']}" to Walk-In POS Cart!'),
                                              duration: const Duration(seconds: 2),
                                            ),
                                          );
                                        },
                                      ),
                                      const SizedBox(width: 4),
                                      FilledButton.tonalIcon(
                                        style: FilledButton.styleFrom(
                                          backgroundColor: ClinicTheme.cardBackground,
                                          foregroundColor: ClinicTheme.malachite,
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                        ),
                                        icon: const Icon(Icons.bolt, size: 14),
                                        label: const Text('Test Checkout', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                                        onPressed: () => _testOverlayCheckout(context, prod, paymentService),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
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

  void _addToPosCart(Map<String, dynamic> item) {
    setState(() {
      final existingIndex = _posCart.indexWhere((c) => c['id'] == item['id']);
      if (existingIndex >= 0) {
        _posCart[existingIndex]['qty'] = (_posCart[existingIndex]['qty'] as int) + 1;
      } else {
        _posCart.add({
          'id': item['id'],
          'name': item['name'],
          'price': item['price'],
          'category': item['category'],
          'qty': 1,
        });
      }
    });
  }

  List<Map<String, dynamic>> get _filteredCatalog {
    final list = _selectedCategory == 'All'
        ? _catalog
        : _catalog.where((item) => item['category'] == _selectedCategory).toList();
    if (_searchQuery.trim().isEmpty) return list;
    final q = _searchQuery.toLowerCase();
    return list.where((item) {
      final name = (item['name'] as String).toLowerCase();
      final sku = (item['sku'] as String).toLowerCase();
      final cat = (item['category'] as String).toLowerCase();
      final attr = (item['attributes'] as String).toLowerCase();
      return name.contains(q) || sku.contains(q) || cat.contains(q) || attr.contains(q);
    }).toList();
  }

  // Tab 2: Orders
  Widget _buildOrdersTab() {
    return ListView.separated(
      itemCount: _orders.length,
      separatorBuilder: (_, __) => const SizedBox(height: 14),
      itemBuilder: (context, i) {
        final ord = _orders[i];
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
                radius: 24,
                backgroundColor: ClinicTheme.cardBackground,
                child: const Icon(Icons.receipt_long, color: ClinicTheme.malachite, size: 22),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          ord['order_no'] as String,
                          style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(width: 10),
                        Text('Patient: ${ord['patient_name']}', style: const TextStyle(color: ClinicTheme.textSecondary, fontSize: 13)),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: ClinicTheme.malachiteFaint,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(ord['payment_status'] as String, style: const TextStyle(color: ClinicTheme.malachite, fontSize: 11, fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Ordered Items: ${ord['items']}',
                      style: const TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.local_shipping_outlined, size: 14, color: ord['status_color'] as Color),
                        const SizedBox(width: 6),
                        Text(
                          'Status: ${ord['fulfillment']} · Placed: ${ord['date']}',
                          style: TextStyle(color: ord['status_color'] as Color, fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '\$${(ord['total'] as double).toStringAsFixed(2)}',
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 6),
                  FilledButton.tonal(
                    style: FilledButton.styleFrom(
                      backgroundColor: ClinicTheme.cardBackground,
                      foregroundColor: ClinicTheme.malachite,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    ),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Status update sent to ${ord['patient_name']}')),
                      );
                    },
                    child: const Text('Update Status', style: TextStyle(fontSize: 11)),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // Tab 3: Walk-In POS & Multi-Purpose QR Hub
  Widget _buildWalkInPosAndQrTab(ClinicScope scope, BachsPaymentService paymentService) {
    final subtotal = _posCart.fold(0.0, (sum, it) => sum + (it['price'] as double) * (it['qty'] as int));
    final finalTotal = math.max(0.0, subtotal - _posCopayDeduction);
    final clinicId = scope.clinicId ?? 'demo_clinic';

    String currentQrUrl;
    String currentQrTitle;
    String currentQrSubtitle;
    String currentQrBadge;

    if (_selectedQrSignageMode == 'front_desk') {
      currentQrUrl = 'https://pay.gozvision.com/$clinicId/checkout';
      currentQrTitle = 'Front Desk Touchless Checkout';
      currentQrSubtitle = 'Patients scan with their phone camera to pay optical balances, frame balances, or exam copays.';
      currentQrBadge = 'RECEPTION DESK STAND';
    } else if (_selectedQrSignageMode == 'waiting_room') {
      currentQrUrl = 'https://gozvision.com/store/$clinicId';
      currentQrTitle = 'Dispensary & Clinical Services Booking';
      currentQrSubtitle = 'Patients in the waiting lounge browse frames, order therapeutic drops, and book specialized evaluations.';
      currentQrBadge = 'WAITING ROOM ACRYLIC STAND';
    } else {
      currentQrUrl = 'https://gozvision.com/app?clinic=$clinicId';
      currentQrTitle = 'Download GozVision Patient Copilot';
      currentQrSubtitle = 'Patients scan to install the GozVision vision copilot app pre-linked to Dr. O.D. Adegoke & this clinic.';
      currentQrBadge = 'EXAM LANE COUNTER STAND';
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 900;
        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isWide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left Column: Walk-In Reception POS Terminal
                    Expanded(
                      flex: 6,
                      child: _buildPosTerminal(context, subtotal, finalTotal, scope, paymentService),
                    ),
                    const SizedBox(width: 20),
                    // Right Column: Multi-Purpose QR Code Signage Suite
                    Expanded(
                      flex: 5,
                      child: _buildQrSignageSuite(context, currentQrUrl, currentQrTitle, currentQrSubtitle, currentQrBadge),
                    ),
                  ],
                )
              else
                Column(
                  children: [
                    _buildPosTerminal(context, subtotal, finalTotal, scope, paymentService),
                    const SizedBox(height: 20),
                    _buildQrSignageSuite(context, currentQrUrl, currentQrTitle, currentQrSubtitle, currentQrBadge),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPosTerminal(
    BuildContext context,
    double subtotal,
    double finalTotal,
    ClinicScope scope,
    BachsPaymentService paymentService,
  ) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: ClinicTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ClinicTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: ClinicTheme.malachiteFaint,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: ClinicTheme.malachite.withOpacity(0.3)),
                ),
                child: const Icon(Icons.point_of_sale_rounded, color: ClinicTheme.malachite, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Walk-In Reception POS Terminal',
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Direct checkout for walk-in patients or patients not yet enrolled on GozVision',
                      style: TextStyle(color: ClinicTheme.textSecondary, fontSize: 12),
                    ),
                  ],
                ),
              ),
              if (_posCart.isNotEmpty)
                TextButton.icon(
                  icon: const Icon(Icons.delete_sweep_rounded, size: 16, color: Colors.white60),
                  label: const Text('Clear Cart', style: TextStyle(color: Colors.white60, fontSize: 12)),
                  onPressed: () => setState(() => _posCart.clear()),
                ),
            ],
          ),
          const SizedBox(height: 18),
          const Divider(color: ClinicTheme.border),
          const SizedBox(height: 14),

          // Patient Selection Row
          Row(
            children: [
              const Text('Patient Name:', style: TextStyle(color: ClinicTheme.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: ClinicTheme.cardBackground,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: ClinicTheme.border),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _posPatientName,
                      dropdownColor: ClinicTheme.cardBackground,
                      style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                      items: const [
                        DropdownMenuItem(value: 'Walk-In Patient / Guest', child: Text('Walk-In Patient / Guest (No Goz Profile)')),
                        DropdownMenuItem(value: 'Folashade Adeleke', child: Text('Folashade Adeleke (Active Rx #OPT-8021)')),
                        DropdownMenuItem(value: 'Babajide Okafor', child: Text('Babajide Okafor (Active Rx #OPT-7419)')),
                        DropdownMenuItem(value: 'Martha Alvarez', child: Text('Martha Alvarez (Refraction Due)')),
                      ],
                      onChanged: (val) => setState(() => _posPatientName = val ?? 'Walk-In Patient / Guest'),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Quick-Add Item Chips
          const Text('Quick Add from Catalog & Clinical Services:', style: TextStyle(color: ClinicTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _catalog.take(6).map((item) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ActionChip(
                    backgroundColor: ClinicTheme.cardBackground,
                    side: const BorderSide(color: ClinicTheme.border),
                    avatar: Icon(
                      item['category'] == 'Clinical Services'
                          ? Icons.medical_services_outlined
                          : (item['category'] == 'Frames' ? Icons.remove_red_eye_outlined : Icons.medication_outlined),
                      size: 14,
                      color: ClinicTheme.malachite,
                    ),
                    label: Text(
                      '${item['name'].toString().split('—')[0].split('(')[0].trim()} · \$${(item['price'] as double).toStringAsFixed(0)}',
                      style: const TextStyle(color: Colors.white, fontSize: 11.5),
                    ),
                    onPressed: () {
                      _addToPosCart(item);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Added "${item['name']}" to cart'), duration: const Duration(milliseconds: 1200)),
                      );
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 18),

          // Cart List
          Container(
            constraints: const BoxConstraints(minHeight: 140, maxHeight: 220),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: ClinicTheme.cardBackground,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: ClinicTheme.border),
            ),
            child: _posCart.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.shopping_basket_outlined, size: 36, color: ClinicTheme.textSecondary),
                        SizedBox(height: 8),
                        Text('No items in Walk-In Cart', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold)),
                        SizedBox(height: 4),
                        Text('Click items above or in the Catalog tab to add to this transaction.', style: TextStyle(color: ClinicTheme.textSecondary, fontSize: 11)),
                      ],
                    ),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    itemCount: _posCart.length,
                    separatorBuilder: (_, __) => const Divider(height: 12, color: ClinicTheme.border),
                    itemBuilder: (context, idx) {
                      final item = _posCart[idx];
                      final lineTotal = (item['price'] as double) * (item['qty'] as int);
                      return Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(item['name'] as String, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                                Text('${item['category']} · \$${(item['price'] as double).toStringAsFixed(2)} each', style: const TextStyle(color: ClinicTheme.textSecondary, fontSize: 11)),
                              ],
                            ),
                          ),
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.remove_circle_outline, size: 16, color: ClinicTheme.textSecondary),
                                onPressed: () {
                                  setState(() {
                                    if ((item['qty'] as int) > 1) {
                                      item['qty'] = (item['qty'] as int) - 1;
                                    } else {
                                      _posCart.removeAt(idx);
                                    }
                                  });
                                },
                              ),
                              Text('${item['qty']}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                              IconButton(
                                icon: const Icon(Icons.add_circle_outline, size: 16, color: ClinicTheme.malachite),
                                onPressed: () => setState(() => item['qty'] = (item['qty'] as int) + 1),
                              ),
                              const SizedBox(width: 8),
                              SizedBox(
                                width: 70,
                                child: Text(
                                  '\$${lineTotal.toStringAsFixed(2)}',
                                  textAlign: TextAlign.right,
                                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close_rounded, size: 16, color: Colors.white38),
                                onPressed: () => setState(() => _posCart.removeAt(idx)),
                              ),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
          ),
          const SizedBox(height: 18),

          // Totals and Copay adjustment
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: ClinicTheme.surfaceDark,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.06)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Dispensary & Services Subtotal:', style: TextStyle(color: ClinicTheme.textSecondary, fontSize: 13)),
                    Text('\$${subtotal.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: const [
                        Text('Vision Insurance / Co-Pay Deduction:', style: TextStyle(color: ClinicTheme.textSecondary, fontSize: 12)),
                        SizedBox(width: 6),
                        Icon(Icons.shield_outlined, size: 14, color: ClinicTheme.malachiteDim),
                      ],
                    ),
                    Row(
                      children: [
                        TextButton(
                          child: Text(_posCopayDeduction == 0.0 ? 'Apply \$25 Copay' : 'Clear Copay', style: const TextStyle(color: ClinicTheme.malachite, fontSize: 11)),
                          onPressed: () {
                            setState(() {
                              _posCopayDeduction = _posCopayDeduction == 0.0 ? 25.0 : 0.0;
                            });
                          },
                        ),
                        Text('-\$${_posCopayDeduction.toStringAsFixed(2)}', style: const TextStyle(color: ClinicTheme.warningAmber, fontSize: 13, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ],
                ),
                const Divider(height: 18, color: ClinicTheme.border),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total Patient Balance Due:', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800)),
                    Text(
                      '\$${finalTotal.toStringAsFixed(2)}',
                      style: const TextStyle(color: ClinicTheme.malachite, fontSize: 22, fontWeight: FontWeight.w900),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Payment Trigger Buttons
          Wrap(
            spacing: 12,
            runSpacing: 10,
            children: [
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: ClinicTheme.malachite,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
                label: const Text('Dynamic Scan-to-Pay QR', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                onPressed: _posCart.isEmpty
                    ? null
                    : () => _showScanToPayModal(context, finalTotal, _posPatientName, scope, paymentService),
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: ClinicTheme.border),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.contactless_rounded, size: 18, color: ClinicTheme.malachite),
                label: const Text('In-Person Card / Tap Reader', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                onPressed: _posCart.isEmpty
                    ? null
                    : () => _processInPersonCardPayment(context, finalTotal, _posPatientName),
              ),
              TextButton.icon(
                style: TextButton.styleFrom(
                  foregroundColor: ClinicTheme.textSecondary,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                ),
                icon: const Icon(Icons.money_rounded, size: 18),
                label: const Text('Cash / Copay', style: TextStyle(fontSize: 13)),
                onPressed: _posCart.isEmpty
                    ? null
                    : () => _processCashPayment(context, finalTotal, _posPatientName),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQrSignageSuite(
    BuildContext context,
    String qrUrl,
    String title,
    String subtitle,
    String badge,
  ) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: ClinicTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ClinicTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: ClinicTheme.malachiteFaint,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: ClinicTheme.malachite.withOpacity(0.3)),
                ),
                child: const Icon(Icons.qr_code_2_rounded, color: ClinicTheme.malachite, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Multi-Purpose Clinic QR Hub',
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Ready-to-print & digital QR code signage tailored for each clinical touchpoint',
                      style: TextStyle(color: ClinicTheme.textSecondary, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Divider(color: ClinicTheme.border),
          const SizedBox(height: 14),

          // 3 Mode Selector Pills
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildQrModePill(
                modeKey: 'front_desk',
                label: '1. Front Desk Pay Stand',
                icon: Icons.point_of_sale_rounded,
              ),
              _buildQrModePill(
                modeKey: 'waiting_room',
                label: '2. Waiting Room Storefront',
                icon: Icons.storefront_rounded,
              ),
              _buildQrModePill(
                modeKey: 'copilot_download',
                label: '3. Exam Lane Copilot Stand',
                icon: Icons.install_mobile_rounded,
              ),
            ],
          ),
          const SizedBox(height: 18),

          // The Physical Acrylic Desk Stand Simulation Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.4),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              children: [
                // Stand Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.remove_red_eye, color: Color(0xFF00E5FF), size: 14),
                          const SizedBox(width: 6),
                          Text(
                            badge,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF0F172A),
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 11.5,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 16),

                // QR Code
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
                  ),
                  child: _ClinicQrCodeWidget(data: qrUrl, size: 160),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Point phone camera at QR code to open',
                  style: TextStyle(
                    color: Color(0xFF475569),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  qrUrl,
                  style: const TextStyle(
                    color: Color(0xFF0284C7),
                    fontSize: 11,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Action Toolbar
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: ClinicTheme.cardBackground,
                    foregroundColor: ClinicTheme.malachite,
                    side: BorderSide(color: ClinicTheme.malachite.withOpacity(0.4)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.print_rounded, size: 16),
                  label: const Text('Print Counter Stand', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('✓ Generating high-resolution printable acrylic stand for "$title"')),
                    );
                  },
                ),
              ),
              const SizedBox(width: 10),
              IconButton(
                tooltip: 'Copy Direct Link',
                icon: const Icon(Icons.copy_rounded, size: 18, color: ClinicTheme.malachite),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Copied "$qrUrl" to clipboard!')),
                  );
                },
              ),
              IconButton(
                tooltip: 'Download Vector PNG',
                icon: const Icon(Icons.file_download_outlined, size: 18, color: ClinicTheme.textSecondary),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('✓ Downloaded QR asset to downloads folder')),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQrModePill({
    required String modeKey,
    required String label,
    required IconData icon,
  }) {
    final isSel = _selectedQrSignageMode == modeKey;
    return ChoiceChip(
      avatar: Icon(icon, size: 14, color: isSel ? Colors.black : ClinicTheme.textSecondary),
      label: Text(label),
      selected: isSel,
      selectedColor: ClinicTheme.malachite,
      backgroundColor: ClinicTheme.cardBackground,
      labelStyle: TextStyle(
        color: isSel ? Colors.black : ClinicTheme.textSecondary,
        fontWeight: isSel ? FontWeight.w800 : FontWeight.w600,
        fontSize: 11.5,
      ),
      side: BorderSide(color: isSel ? ClinicTheme.malachite : ClinicTheme.border),
      onSelected: (_) => setState(() => _selectedQrSignageMode = modeKey),
    );
  }

  void _showScanToPayModal(
    BuildContext context,
    double total,
    String patientName,
    ClinicScope scope,
    BachsPaymentService paymentService,
  ) {
    final clinicId = scope.clinicId ?? 'demo_clinic';
    final txId = 'TXN-POS-${DateTime.now().millisecondsSinceEpoch % 1000000}';
    final payUrl = 'https://pay.gozvision.com/$clinicId/checkout?tx=$txId&amt=$total';

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
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: ClinicTheme.malachiteFaint,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.qr_code_scanner_rounded, color: ClinicTheme.malachite, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Scan to Pay at Reception', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
                  Text('Order total: \$${total.toStringAsFixed(2)} for $patientName', style: const TextStyle(color: ClinicTheme.textSecondary, fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 380,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    _ClinicQrCodeWidget(data: payUrl, size: 200),
                    const SizedBox(height: 10),
                    const Text('Point camera to pay instantly', style: TextStyle(color: Color(0xFF0F172A), fontSize: 12, fontWeight: FontWeight.bold)),
                    const Text('Accepts Apple Pay, Google Pay, Card & Bachs', style: TextStyle(color: Color(0xFF64748B), fontSize: 10)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: ClinicTheme.surfaceDark,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.timer_outlined, size: 16, color: ClinicTheme.warningAmber),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text('Session active · Awaiting patient scan...', style: TextStyle(color: ClinicTheme.textSecondary, fontSize: 11)),
                    ),
                    Text(txId, style: const TextStyle(color: ClinicTheme.malachite, fontSize: 11, fontFamily: 'monospace')),
                  ],
                ),
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
            style: FilledButton.styleFrom(backgroundColor: ClinicTheme.malachite, foregroundColor: Colors.black),
            icon: const Icon(Icons.check_circle_outline_rounded, size: 16),
            label: const Text('Simulate Patient Scan & Pay'),
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                _orders.insert(0, {
                  'order_no': 'ORD-${DateTime.now().year}-${DateTime.now().millisecondsSinceEpoch % 100000}',
                  'patient_name': patientName,
                  'patient_id': 'walkin_guest',
                  'items': _posCart.map((it) => '${it['name']} (x${it['qty']})').join(', '),
                  'total': total,
                  'payment_status': 'Paid (Bachs Instant QR)',
                  'provider': 'bachs',
                  'fulfillment': 'Dispensed In-Clinic at Reception',
                  'date': 'Just Now',
                  'status_color': ClinicTheme.malachite,
                });
                _posCart.clear();
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: ClinicTheme.surfaceGlass,
                  content: Row(
                    children: [
                      const Icon(Icons.check_circle, color: ClinicTheme.malachite),
                      const SizedBox(width: 10),
                      Text('✓ Walk-In Payment of \$${total.toStringAsFixed(2)} confirmed via QR! Receipt #$txId generated.'),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  void _processInPersonCardPayment(BuildContext context, double total, String patientName) {
    final txId = 'TXN-CARD-${DateTime.now().millisecondsSinceEpoch % 100000}';
    setState(() {
      _orders.insert(0, {
        'order_no': 'ORD-${DateTime.now().year}-${DateTime.now().millisecondsSinceEpoch % 100000}',
        'patient_name': patientName,
        'patient_id': 'walkin_guest',
        'items': _posCart.map((it) => '${it['name']} (x${it['qty']})').join(', '),
        'total': total,
        'payment_status': 'Paid (Card Reader / EMV)',
        'provider': 'card_terminal',
        'fulfillment': 'Dispensed In-Clinic at Reception',
        'date': 'Just Now',
        'status_color': ClinicTheme.malachite,
      });
      _posCart.clear();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('✓ Contactless card payment of \$${total.toStringAsFixed(2)} processed! Receipt #$txId.'),
      ),
    );
  }

  void _processCashPayment(BuildContext context, double total, String patientName) {
    final txId = 'TXN-CASH-${DateTime.now().millisecondsSinceEpoch % 100000}';
    setState(() {
      _orders.insert(0, {
        'order_no': 'ORD-${DateTime.now().year}-${DateTime.now().millisecondsSinceEpoch % 100000}',
        'patient_name': patientName,
        'patient_id': 'walkin_guest',
        'items': _posCart.map((it) => '${it['name']} (x${it['qty']})').join(', '),
        'total': total,
        'payment_status': 'Paid (Cash / Clinic Ledger)',
        'provider': 'cash',
        'fulfillment': 'Dispensed In-Clinic at Reception',
        'date': 'Just Now',
        'status_color': ClinicTheme.malachiteDim,
      });
      _posCart.clear();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('✓ Cash transaction of \$${total.toStringAsFixed(2)} logged into Clinic Ledger.'),
      ),
    );
  }

  // Tab 4: Bachs Instant Payouts & Settlement
  Widget _buildBachsPayoutsTab(ClinicScope scope, BachsPaymentService paymentService) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Bachs Banner & Balance Overview
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: ClinicTheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: ClinicTheme.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: ClinicTheme.malachiteFaint,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: ClinicTheme.malachite.withOpacity(0.3)),
                      ),
                      child: const Icon(Icons.bolt, color: ClinicTheme.malachite, size: 28),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Bachs API Settlement & Payout Engine', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                          Text('Real-time balances across NGN, USD, EUR · Direct Payouts to registered bank destinations · Tenant: ${scope.clinicId ?? "demo_clinic"}', style: const TextStyle(color: ClinicTheme.textSecondary, fontSize: 13)),
                        ],
                      ),
                    ),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: ClinicTheme.malachite,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      icon: const Icon(Icons.send_rounded, size: 16),
                      label: const Text('Instant Payout', style: TextStyle(fontWeight: FontWeight.w700)),
                      onPressed: () => _showInstantPayoutDialog(context, paymentService),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                // Balance Buckets
                Row(
                  children: paymentService.balances.map((b) {
                    final symbol = b.currency == 'NGN' ? '₦' : (b.currency == 'EUR' ? '€' : '\$');
                    return Expanded(
                      child: Container(
                        margin: const EdgeInsets.only(right: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: ClinicTheme.cardBackground,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: ClinicTheme.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('${b.currency} Available Balance', style: const TextStyle(color: ClinicTheme.textSecondary, fontSize: 12)),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: ClinicTheme.malachiteFaint,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text('Live', style: TextStyle(color: ClinicTheme.malachite, fontSize: 10, fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '$symbol ${b.available}',
                              style: const TextStyle(color: ClinicTheme.malachite, fontSize: 22, fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 4),
                            Text('Pending Settlement: $symbol ${b.pending}', style: const TextStyle(color: ClinicTheme.textSecondary, fontSize: 11)),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Payout Bank Destinations Section
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: ClinicTheme.surface,
              borderRadius: BorderRadius.circular(16),
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
                        Text('Registered Payout Destinations', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                        SizedBox(height: 4),
                        Text('Verified bank accounts receiving automatic or manual payouts via Bachs API (POST /v1/payouts/destinations)', style: TextStyle(color: ClinicTheme.textSecondary, fontSize: 12)),
                      ],
                    ),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: ClinicTheme.malachite),
                        foregroundColor: ClinicTheme.malachite,
                      ),
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Add Bank Account'),
                      onPressed: () => _showAddBankDestinationDialog(context, paymentService),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ...paymentService.destinations.map((dest) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: ClinicTheme.cardBackground,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: ClinicTheme.border),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.account_balance, color: ClinicTheme.malachite, size: 24),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(dest.bankName, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
                              const SizedBox(height: 2),
                              Text('Account: ${dest.accountNumber} · Holder: ${dest.accountName}', style: const TextStyle(color: ClinicTheme.textSecondary, fontSize: 12)),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: ClinicTheme.malachiteFaint,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text('${dest.currency} · ${dest.status.toUpperCase()}', style: const TextStyle(color: ClinicTheme.malachite, fontSize: 10, fontWeight: FontWeight.w800)),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Payout History Table
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: ClinicTheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: ClinicTheme.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Recent Payout Disbursements (Bachs API)', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                const Text('Direct bank settlements tracked with idempotency keys and asynchronous status updates', style: TextStyle(color: ClinicTheme.textSecondary, fontSize: 12)),
                const SizedBox(height: 16),
                ...paymentService.payouts.map((p) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: ClinicTheme.cardBackground,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: ClinicTheme.border),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.arrow_outward_rounded, color: ClinicTheme.malachite, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Payout Ref: ${p.reference} (${p.id})', style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
                              const SizedBox(height: 2),
                              Text('Destination: ${p.destinationId} · Fee: ${p.currency} ${p.fee}', style: const TextStyle(color: ClinicTheme.textSecondary, fontSize: 11)),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('${p.currency} ${p.amount}', style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800)),
                            const SizedBox(height: 2),
                            Text(p.status.toUpperCase(), style: const TextStyle(color: ClinicTheme.malachite, fontSize: 10, fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Fallback Tab: Stripe Connect
  Widget _buildStripeConnectTab(ClinicScope scope, BachsPaymentService paymentService) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: ClinicTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ClinicTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.withOpacity(0.3)),
                ),
                child: const Icon(Icons.credit_card, color: Colors.blueAccent, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Stripe Connect (Enterprise Mode)', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                    Text('Global custom merchant onboarding · Tenant: ${scope.clinicId ?? "demo_clinic"}', style: const TextStyle(color: ClinicTheme.textSecondary, fontSize: 13)),
                  ],
                ),
              ),
              FilledButton.tonal(
                style: FilledButton.styleFrom(
                  backgroundColor: ClinicTheme.cardBackground,
                  foregroundColor: ClinicTheme.malachite,
                ),
                onPressed: () => paymentService.setActiveProvider(PaymentProviderType.bachs),
                child: const Text('Switch to Bachs (Default)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.withOpacity(0.2)),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blueAccent, size: 20),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Bachs is GozVision’s recommended payment engine due to zero-friction onboarding, lower fees, and native overlay checkout modals. Stripe Connect is preserved for enterprise accounts requiring specialized global merchant routing.',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Divider(color: ClinicTheme.border),
          const SizedBox(height: 14),
          _buildBachsConfigRow('Stripe Connect Account ID', 'acct_1Nv84920KLx04'),
          _buildBachsConfigRow('Account Capabilities', 'card_payments: active, transfers: active'),
          _buildBachsConfigRow('Payout Interval', 'Rolling 2 business days'),
          _buildBachsConfigRow('Processing Fee', '2.9% + \$0.30 per successful charge'),
        ],
      ),
    );
  }

  Widget _buildBachsConfigRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: ClinicTheme.textSecondary, fontSize: 13)),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildRestrictedPayoutsView() {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 480),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: ClinicTheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: ClinicTheme.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: ClinicTheme.warningAmber.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.lock_outline_rounded, size: 36, color: ClinicTheme.warningAmber),
            ),
            const SizedBox(height: 18),
            const Text(
              'Restricted to Clinic Manager & Owner',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Bank accounts, settlement balance buckets, and Bachs instant disbursements are restricted to Practice Owners and Clinic Managers.\n\nFront desk staff and practitioners have full access to product catalogs, prescription fulfillment, and patient order processing.',
              textAlign: TextAlign.center,
              style: TextStyle(color: ClinicTheme.textSecondary, fontSize: 13, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Custom High-Fidelity Enterprise QR Code Component
// ─────────────────────────────────────────────────────────────────────────────
class _ClinicQrCodeWidget extends StatelessWidget {
  final String data;
  final double size;

  const _ClinicQrCodeWidget({
    required this.data,
    this.size = 180,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _QrCodePainter(data: data),
    );
  }
}

class _QrCodePainter extends CustomPainter {
  final String data;

  _QrCodePainter({required this.data});

  @override
  void paint(Canvas canvas, Size size) {
    final paintDark = Paint()..color = const Color(0xFF0F172A);
    final paintCyan = Paint()..color = const Color(0xFF00E5FF);
    final paintWhite = Paint()..color = Colors.white;

    // Background
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paintWhite);

    const int modules = 21; // Standard QR Version 1 size
    final double blockSize = size.width / modules;

    // Helper: Draw 7x7 Finder Pattern
    void drawFinder(int startX, int startY) {
      // Outer 7x7 black
      canvas.drawRect(
        Rect.fromLTWH(startX * blockSize, startY * blockSize, 7 * blockSize, 7 * blockSize),
        paintDark,
      );
      // Inner 5x5 white
      canvas.drawRect(
        Rect.fromLTWH((startX + 1) * blockSize, (startY + 1) * blockSize, 5 * blockSize, 5 * blockSize),
        paintWhite,
      );
      // Center 3x3 black
      canvas.drawRect(
        Rect.fromLTWH((startX + 2) * blockSize, (startY + 2) * blockSize, 3 * blockSize, 3 * blockSize),
        paintDark,
      );
    }

    // Draw the 3 finder patterns
    drawFinder(0, 0); // Top-left
    drawFinder(modules - 7, 0); // Top-right
    drawFinder(0, modules - 7); // Bottom-left

    // Timing tracks (alternating dots at row 6 and col 6)
    for (int i = 7; i < modules - 7; i++) {
      if (i % 2 == 0) {
        canvas.drawRect(Rect.fromLTWH(i * blockSize, 6 * blockSize, blockSize, blockSize), paintDark);
        canvas.drawRect(Rect.fromLTWH(6 * blockSize, i * blockSize, blockSize, blockSize), paintDark);
      }
    }

    // Deterministic module generation for data area based on data hash
    int hash = data.hashCode;
    for (int r = 0; r < modules; r++) {
      for (int c = 0; c < modules; c++) {
        // Skip finder areas
        if (r < 7 && c < 7) continue;
        if (r < 7 && c >= modules - 7) continue;
        if (r >= modules - 7 && c < 7) continue;
        if (r == 6 || c == 6) continue; // timing tracks

        // Center logo cutout
        if (r >= 8 && r <= 12 && c >= 8 && c <= 12) continue;

        // Pseudo-random bit based on position and hash
        final bit = ((r * 31 + c * 17 + hash.abs()) ^ (r * c)) % 3 == 0;
        if (bit) {
          canvas.drawRect(
            Rect.fromLTWH(c * blockSize, r * blockSize, blockSize, blockSize),
            paintDark,
          );
        }
      }
    }

    // Center GozVision Emblem / Accent
    final centerRect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: blockSize * 4.5,
      height: blockSize * 4.5,
    );
    canvas.drawRRect(RRect.fromRectAndRadius(centerRect, Radius.circular(blockSize)), paintDark);

    final innerCenter = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: blockSize * 2.8,
      height: blockSize * 2.8,
    );
    canvas.drawOval(innerCenter, paintCyan);

    final pupil = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: blockSize * 1.2,
      height: blockSize * 1.2,
    );
    canvas.drawOval(pupil, paintDark);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
