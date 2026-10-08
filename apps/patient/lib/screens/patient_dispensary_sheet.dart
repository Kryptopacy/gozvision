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
      'rx': 'Prescribed by Dr. Ada (OD: -2.50, OS: -2.25)',
      'description': 'Featherweight Japanese titanium with deep bevel for low-vision lenses.',
      'tag': 'Doctor Prescribed',
      'icon': Icons.remove_red_eye_outlined,
    },
    {
      'id': 'prod_02',
      'name': 'Solos AirGo 3 Audio Glasses',
      'category': 'Smart Glasses',
      'price': 299.00,
      'currency': 'USD',
      'rx': 'Connected to Goz Copilot via Bluetooth',
      'description': 'Directional open-ear speakers whisper AI vision scene descriptions discreetly.',
      'tag': 'AI Copilot Ready',
      'icon': Icons.headset_mic_outlined,
    },
    {
      'id': 'prod_03',
      'name': 'FL-41 Photophobia Relief Clip-On',
      'category': 'Filters',
      'price': 65.00,
      'currency': 'USD',
      'rx': 'Recommended for Light Sensitivity',
      'description': 'Blocks 480-520nm fluorescent glare and relieves digital eye strain.',
      'tag': 'Glare Relief',
      'icon': Icons.wb_sunny_outlined,
    },
    {
      'id': 'prod_04',
      'name': 'Systane Complete Preservative-Free',
      'category': 'Drops',
      'price': 34.50,
      'currency': 'USD',
      'rx': 'Daily Meibomian Gland Therapy',
      'description': 'Nano-droplet lipid formula providing all-day moisture for dry eyes.',
      'tag': 'Dry Eye Care',
      'icon': Icons.medication_outlined,
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
                'Opening Bachs Checkout for "${item['name']}"...',
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
          content: Text('Bachs Checkout opened: $checkoutUrl'),
          action: SnackBarAction(
            label: 'Open',
            textColor: GozAITheme.accentCyan,
            onPressed: () {},
          ),
        ),
      );
    }
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
                          child: const Text('Bachs Pay', style: TextStyle(color: GozAITheme.accentCyan, fontSize: 10, fontWeight: FontWeight.bold)),
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
                      SizedBox(
                        width: double.infinity,
                        height: 44,
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: GozAITheme.accentCyan,
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: const Icon(Icons.bolt, size: 18),
                          label: const Text(
                            'Order Now via Bachs Checkout',
                            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                          ),
                          onPressed: () => _purchaseProduct(context, item, bachsService),
                        ),
                      ),
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
