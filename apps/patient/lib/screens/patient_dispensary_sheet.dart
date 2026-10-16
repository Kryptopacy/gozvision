import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/theme.dart';
import '../services/haptic_service.dart';
import '../services/bachs_payment_service.dart';

/// Patient Optical Dispensary & Rx Storefront Sheet.
///
/// Allows low-vision patients to view frames, smart glasses, and therapeutic
/// eye care prescribed by their optometrist, and purchase directly via
/// the Bachs Overlay Checkout modal.
class PatientDispensarySheet extends StatefulWidget {
  const PatientDispensarySheet({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: GozAITheme.backgroundDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => ChangeNotifierProvider(
        create: (_) => PatientBachsService(),
        child: const PatientDispensarySheet(),
      ),
    );
  }

  @override
  State<PatientDispensarySheet> createState() => _PatientDispensarySheetState();
}

class _PatientDispensarySheetState extends State<PatientDispensarySheet> {
  String _selectedCategory = 'All';

  final List<Map<String, dynamic>> _recommendedProducts = [
    {
      'id': 'prod_01',
      'name': 'Goz Titanium Vista Frame',
      'category': 'Frames',
      'price': 185.00,
      'currency': 'USD',
      'rx': 'Prescribed by Dr. Ada (Right Eye: -2.50, Left Eye: -2.25)',
      'description': 'Ultra-lightweight, durable frame custom-shaped for comfort and special lenses.',
      'tag': 'Doctor Prescribed',
      'icon': Icons.remove_red_eye_outlined,
    },
    {
      'id': 'prod_02',
      'name': 'Solos AirGo 3 Audio Glasses',
      'category': 'Smart Glasses',
      'price': 299.00,
      'currency': 'USD',
      'rx': 'Connected to your Goz Vision Copilot',
      'description': 'Lightweight glasses with built-in voice audio that gently reads signs, labels, and your surroundings to you.',
      'tag': 'Voice Copilot Ready',
      'icon': Icons.headset_mic_outlined,
    },
    {
      'id': 'prod_03',
      'name': 'FL-41 Light Sensitivity & Glare Clip-On',
      'category': 'Filters',
      'price': 65.00,
      'currency': 'USD',
      'rx': 'Recommended for Bright Lights & Screens',
      'description': 'Soothing rose-tinted lens that filters harsh indoor lights, computer screens, and fluorescent glare.',
      'tag': 'Glare & Screen Relief',
      'icon': Icons.wb_sunny_outlined,
    },
    {
      'id': 'prod_04',
      'name': 'Systane Complete Preservative-Free',
      'category': 'Drops',
      'price': 34.50,
      'currency': 'USD',
      'rx': 'Daily Soothing Eye Drops for Dryness & Itch',
      'description': 'Gentle, preservative-free drops that protect your eyes from dryness, stinging, and tiredness throughout the day.',
      'tag': 'Dry Eye Relief',
      'icon': Icons.medication_outlined,
      'isPharmacyRefillable': true,
    },
    {
      'id': 'prod_05',
      'name': 'PreserVision AREDS 2 Formula',
      'category': 'Drops',
      'price': 39.99,
      'currency': 'USD',
      'rx': 'Clinically Proven Macular Support Vitamins (AREDS 2)',
      'description': 'Patented antioxidant and carotenoid blend designed to support retinal health and slow macular degeneration.',
      'tag': 'Macular Health',
      'icon': Icons.health_and_safety_outlined,
      'isPharmacyRefillable': true,
    },
    {
      'id': 'prod_06',
      'name': 'Latanoprost 0.005% Ophthalmic Drops',
      'category': 'Drops',
      'price': 22.00,
      'currency': 'USD',
      'rx': 'Doctor Prescribed (1 drop nightly OU for IOP control)',
      'description': 'Prostaglandin analog ophthalmic solution for lowering intraocular pressure in glaucoma or ocular hypertension.',
      'tag': 'Rx Glaucoma Therapy',
      'icon': Icons.water_drop_outlined,
      'isPharmacyRefillable': true,
      'isRx': true,
    },
  ];

  Future<void> _purchaseProduct(
    BuildContext context,
    Map<String, dynamic> item,
    PatientBachsService bachsService,
  ) async {
    HapticService.tap();
    final user = Supabase.instance.client.auth.currentUser;
    final patientEmail = user?.email ?? 'eleanor.vance@example.com';
    final patientName = user?.userMetadata?['full_name'] as String? ?? 'Eleanor Vance';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: GozAITheme.surfaceGlass,
        content: Row(
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: GozAITheme.accentCyan),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Opening Secure Checkout for "${item['name']}"...',
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );

    final checkoutUrl = await bachsService.createPatientOrderCheckout(
      productId: item['id'] as String,
      productName: item['name'] as String,
      price: item['price'] as double,
      currency: item['currency'] as String,
      patientId: user?.id ?? 'demo_patient_001',
      patientEmail: patientEmail,
      patientName: patientName,
    );

    final opened = await bachsService.openCheckoutOverlay(checkoutUrl);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Secure Checkout opened: $checkoutUrl'),
          action: SnackBarAction(
            label: 'Open',
            textColor: GozAITheme.accentCyan,
            onPressed: () {},
          ),
        ),
      );
    }
  }

  void _showAmazonPharmacyRefillDialog(BuildContext context, Map<String, dynamic> item) {
    HapticService.tap();
    String selectedSpeed = 'Prime Same-Day (Delivered Today by 7 PM)';
    int quantity = 1;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF131722),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final totalPrice = (item['price'] as double) * quantity;
          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(context).viewInsets.bottom + 28,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(4)),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF9900).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFFF9900).withValues(alpha: 0.4)),
                      ),
                      child: const Icon(Icons.local_shipping_rounded, color: Color(0xFFFF9900), size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text(
                                'Amazon Pharmacy',
                                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF00A8E1).withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'Prime Refill',
                                  style: TextStyle(color: Color(0xFF00A8E1), fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                          const Text(
                            'Direct Doorstep Delivery • Standalone (Zero Clinic Lock-In)',
                            style: TextStyle(color: Colors.white60, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Row(
                    children: [
                      Icon(item['icon'] as IconData, color: GozAITheme.accentCyan, size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item['name'] as String,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            Text(
                              item['rx'] as String,
                              style: const TextStyle(color: GozAITheme.accentCyan, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '\$${totalPrice.toStringAsFixed(2)}',
                        style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'DELIVERY SPEED',
                  style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: selectedSpeed,
                  dropdownColor: const Color(0xFF1E2433),
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.05),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.white12)),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'Prime Same-Day (Delivered Today by 7 PM)',
                      child: Text('Prime Same-Day (Delivered Today by 7 PM)'),
                    ),
                    DropdownMenuItem(
                      value: 'Prime One-Day (Delivered Tomorrow Morning)',
                      child: Text('Prime One-Day (Delivered Tomorrow Morning)'),
                    ),
                    DropdownMenuItem(
                      value: 'Standard Doorstep (2-3 Business Days)',
                      child: Text('Standard Doorstep (2-3 Business Days)'),
                    ),
                  ],
                  onChanged: (v) {
                    if (v != null) setModalState(() => selectedSpeed = v);
                  },
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'QUANTITY',
                      style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1),
                    ),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline, color: Colors.white70),
                          onPressed: quantity > 1 ? () => setModalState(() => quantity--) : null,
                        ),
                        Text(
                          '$quantity bottle${quantity > 1 ? 's' : ''}',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add_circle_outline, color: GozAITheme.accentCyan),
                          onPressed: quantity < 5 ? () => setModalState(() => quantity++) : null,
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00A8E1).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF00A8E1).withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: const [
                      Icon(Icons.home_outlined, color: Color(0xFF00A8E1), size: 18),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Ring Integration: When package arrives at your front door, Ring chime & Smart Glasses announce safe parcel arrival with obstacle clearance.',
                          style: TextStyle(color: Color(0xFFB0E2FF), fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFFF9900),
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.flash_on_rounded, size: 20),
                    label: Text(
                      'Confirm 1-Click Refill • \$${totalPrice.toStringAsFixed(2)}',
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                    ),
                    onPressed: () {
                      Navigator.pop(ctx);
                      HapticService.tap();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          backgroundColor: const Color(0xFF1E2433),
                          duration: const Duration(seconds: 4),
                          content: Row(
                            children: [
                              const Icon(Icons.check_circle_rounded, color: Color(0xFFFF9900), size: 22),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  '✓ Amazon Pharmacy Order AMZN-RX-${(10000 + item['name'].hashCode % 89999).abs()} confirmed! Delivering to your doorstep via Prime.',
                                  style: const TextStyle(color: Colors.white, fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bachsService = context.watch<PatientBachsService>();

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag Handle
          Center(
            child: Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 18),

          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: GozAITheme.accentCyan.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: GozAITheme.accentCyan.withOpacity(0.3)),
                ),
                child: const Icon(Icons.storefront_rounded, color: GozAITheme.accentCyan, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Optical Dispensary',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Row(
                      children: [
                        const Text(
                          'Prescribed by your eye care clinic',
                          style: TextStyle(color: GozAITheme.textSecondary, fontSize: 13),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: GozAITheme.accentCyan.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.verified_rounded, size: 10, color: GozAITheme.accentCyan),
                              SizedBox(width: 4),
                              Text('Verified Clinic Store', style: TextStyle(color: GozAITheme.accentCyan, fontSize: 10, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white70),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),

          const SizedBox(height: 16),
          // Category Selector
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: ['All', 'Frames', 'Smart Glasses', 'Filters', 'Drops'].map((cat) {
                final isSel = _selectedCategory == cat;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(cat),
                    selected: isSel,
                    onSelected: (v) => setState(() => _selectedCategory = cat),
                    backgroundColor: GozAITheme.surfaceGlass,
                    selectedColor: GozAITheme.accentCyan.withOpacity(0.2),
                    checkmarkColor: GozAITheme.accentCyan,
                    labelStyle: TextStyle(
                      color: isSel ? GozAITheme.accentCyan : GozAITheme.textSecondary,
                      fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                      fontSize: 12,
                    ),
                    side: BorderSide(
                      color: isSel ? GozAITheme.accentCyan.withOpacity(0.5) : GozAITheme.borderSubtle,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 16),
          // Direct-to-Consumer / Standalone Refill Callout
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFFFF9900).withValues(alpha: 0.12),
                  const Color(0xFF00A8E1).withValues(alpha: 0.08),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFF9900).withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.bolt_rounded, color: Color(0xFFFF9900), size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: RichText(
                    text: const TextSpan(
                      style: TextStyle(fontSize: 11.5, color: Colors.white, height: 1.3),
                      children: [
                        TextSpan(
                          text: 'Direct-to-Consumer Autonomy: ',
                          style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFFF9900)),
                        ),
                        TextSpan(
                          text: 'Patients can refill drops & ocular vitamins directly through Amazon Prime doorstep delivery without requiring a hospital storefront.',
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Product List
          Expanded(
            child: ListView.separated(
              itemCount: _filtered.length,
              separatorBuilder: (_, __) => const SizedBox(height: 14),
              itemBuilder: (context, i) {
                final item = _filtered[i];
                return Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: GozAITheme.surfaceGlass,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: GozAITheme.borderSubtle),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: GozAITheme.backgroundDark,
                            child: Icon(item['icon'] as IconData, color: GozAITheme.accentCyan, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item['name'] as String,
                                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 2),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: GozAITheme.accentCyan.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    item['tag'] as String,
                                    style: const TextStyle(color: GozAITheme.accentCyan, fontSize: 10.5, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '\$${(item['price'] as double).toStringAsFixed(2)}',
                            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        item['description'] as String,
                        style: const TextStyle(color: GozAITheme.textSecondary, fontSize: 13),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        item['rx'] as String,
                        style: const TextStyle(color: GozAITheme.accentCyan, fontSize: 11.5, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 14),
                      if (item['isPharmacyRefillable'] == true) ...[
                        Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: SizedBox(
                                height: 44,
                                child: FilledButton.icon(
                                  style: FilledButton.styleFrom(
                                    backgroundColor: const Color(0xFFFF9900),
                                    foregroundColor: Colors.black,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                  icon: const Icon(Icons.flash_on_rounded, size: 16),
                                  label: const Text(
                                    'Amazon Prime Refill',
                                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                                  ),
                                  onPressed: () => _showAmazonPharmacyRefillDialog(context, item),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 2,
                              child: SizedBox(
                                height: 44,
                                child: OutlinedButton(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: GozAITheme.accentCyan,
                                    side: const BorderSide(color: GozAITheme.accentCyan),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                  child: const Text(
                                    'Clinic Pay',
                                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                                  ),
                                  onPressed: () => _purchaseProduct(context, item, bachsService),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ] else ...[
                        SizedBox(
                          width: double.infinity,
                          height: 44,
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: GozAITheme.accentCyan,
                              foregroundColor: Colors.black,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            icon: const Icon(Icons.shopping_bag_outlined, size: 18),
                            label: const Text(
                              'Order Now (Secure Checkout)',
                              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                            ),
                            onPressed: () => _purchaseProduct(context, item, bachsService),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> get _filtered {
    if (_selectedCategory == 'All') return _recommendedProducts;
    return _recommendedProducts.where((p) => p['category'] == _selectedCategory).toList();
  }
}
