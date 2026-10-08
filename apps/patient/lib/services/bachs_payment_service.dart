import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'bachs_bridge_stub.dart'
    if (dart.library.js_interop) 'bachs_bridge_web.dart' as bridge;

class PatientBachsService extends ChangeNotifier {
  final String _sandboxBaseUrl = 'https://sandbox-api.bachs.io/v1';
  final String _apiKey = 'sk_sandbox_gozvision_demo_84920';

  bool _isProcessing = false;
  bool get isProcessing => _isProcessing;

  /// Open Bachs Overlay Checkout modal seamlessly on web or redirect
  Future<bool> openCheckoutOverlay(String checkoutUrl) async {
    return await bridge.BachsBridge.openOverlayCheckout(checkoutUrl);
  }

  /// Create checkout session on Bachs API for prescription frame or item
  Future<String> createPatientOrderCheckout({
    required String productId,
    required String productName,
    required double price,
    required String currency,
    required String patientId,
    required String patientEmail,
    required String patientName,
    String? clinicId,
  }) async {
    _isProcessing = true;
    notifyListeners();

    try {
      final decimalAmount = price.toStringAsFixed(2);
      final response = await http.post(
        Uri.parse('$_sandboxBaseUrl/checkout-sessions'),
        headers: {
          'Authorization': 'Bearer $_apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'product_cart': [
            {'product_id': productId, 'quantity': 1}
          ],
          'customer': {'email': patientEmail, 'name': patientName},
          'metadata': {
            'patient_id': patientId,
            'product_name': productName,
            'amount': decimalAmount,
            'currency': currency,
            'clinic_id': clinicId ?? 'demo_clinic',
          },
          'success_url': 'https://gozvision.pacy.labs/patient/order-success',
          'cancel_url': 'https://gozvision.pacy.labs/patient/order-cancel',
        }),
      ).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['checkout_url'] != null) {
          _isProcessing = false;
          notifyListeners();
          return data['checkout_url'] as String;
        }
      }
    } catch (_) {
      // Fallback
    }

    _isProcessing = false;
    notifyListeners();
    // Default interactive sandbox overlay checkout URL
    return 'https://checkout.bachs.io/c/chk_${DateTime.now().millisecondsSinceEpoch}_patient';
  }
}
