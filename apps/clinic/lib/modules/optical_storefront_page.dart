import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/clinic_theme.dart';
import '../data/clinic_scope.dart';
import '../services/bachs_payment_service.dart';

/// Optical Dispensary & Practice Storefront Module
///
/// Features:
///  - Dispensary Catalog (Frames, Smart Glasses, Low-Vision Filters, Therapeutics)
///  - Doctor/Optometrist Product & Frame management
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

  // Optical catalog
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
      'name': 'FL-41 Photophobia Glare Relief Clip-On',
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
      'attributes': 'Nano-droplet Lipid Tech · Dry Eye & Meibomian Gland Care',
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
  ];

  // Patient orders paid via Bachs / Stripe
  final List<Map<String, dynamic>> _orders = [
    {
      'order_no': 'ORD-2026-84920',
      'patient_name': 'Eleanor Vance',
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
      'patient_name': 'Robert Chen',
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
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
      customerName: 'Eleanor Vance',
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
                  icon: const Icon(Icons.remove_red_eye_outlined, size: 18),
                  text: 'Frames & Dispensary Catalog (${_catalog.length})',
                ),
                Tab(
                  icon: const Icon(Icons.receipt_long_outlined, size: 18),
                  text: 'Patient Orders (${_orders.length})',
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
                    Row(
                      children: [
                        const Text(
                          'Optical Dispensary & Practice Storefront',
                          style: TextStyle(
                            color: ClinicTheme.textPrimary,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(width: 12),
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
        // Category filters
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: ['All', 'Frames', 'Smart Glasses', 'Low-Vision Tech', 'Therapeutics'].map((cat) {
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
          child: ListView.separated(
            itemCount: _filteredCatalog.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, i) {
              final prod = _filteredCatalog[i];
              return Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: ClinicTheme.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: ClinicTheme.border),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: ClinicTheme.cardBackground,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: ClinicTheme.border),
                      ),
                      child: Center(
                        child: Icon(
                          prod['category'] == 'Frames'
                              ? Icons.remove_red_eye_outlined
                              : (prod['category'] == 'Smart Glasses' ? Icons.headset_mic_outlined : Icons.medication_outlined),
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
                              Text(
                                prod['name'] as String,
                                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(width: 10),
                              if (prod['rx_required'] == true) ...[
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
                            'SKU: ${prod['sku']} · ${prod['attributes']}',
                            style: const TextStyle(color: ClinicTheme.textSecondary, fontSize: 12),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Stock Level: ${prod['stock']} units · Customer Rating: ${prod['rating']}',
                            style: TextStyle(color: ClinicTheme.malachiteDim, fontSize: 11, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                    Row(
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '\$${(prod['price'] as double).toStringAsFixed(2)}',
                              style: const TextStyle(color: ClinicTheme.malachite, fontSize: 20, fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 6),
                            FilledButton.tonalIcon(
                              style: FilledButton.styleFrom(
                                backgroundColor: ClinicTheme.cardBackground,
                                foregroundColor: ClinicTheme.malachite,
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                              ),
                              icon: const Icon(Icons.bolt, size: 14),
                              label: const Text('Test Bachs Overlay', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                              onPressed: () => _testOverlayCheckout(context, prod, paymentService),
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

  List<Map<String, dynamic>> get _filteredCatalog {
    if (_selectedCategory == 'All') return _catalog;
    return _catalog.where((item) => item['category'] == _selectedCategory).toList();
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

  // Tab 3: Bachs Instant Payouts & Settlement
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
