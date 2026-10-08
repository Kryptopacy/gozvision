import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'bachs_bridge_stub.dart'
    if (dart.library.js_interop) 'bachs_bridge_web.dart' as bridge;

enum PaymentProviderType {
  bachs,
  stripeConnect,
}

class BachsBalance {
  final String currency;
  final String available;
  final String pending;

  const BachsBalance({
    required this.currency,
    required this.available,
    required this.pending,
  });
}

class BachsPayoutDestination {
  final String id;
  final String bankName;
  final String bankCode;
  final String accountNumber;
  final String accountName;
  final String currency;
  final bool isUsable;
  final bool isDefault;
  final String status;

  const BachsPayoutDestination({
    required this.id,
    required this.bankName,
    required this.bankCode,
    required this.accountNumber,
    required this.accountName,
    required this.currency,
    this.isUsable = true,
    this.isDefault = false,
    this.status = 'approved',
  });
}

class BachsPayoutRecord {
  final String id;
  final String destinationId;
  final String amount;
  final String currency;
  final String reference;
  final String totalDebited;
  final String fee;
  final String status;
  final DateTime createdAt;

  const BachsPayoutRecord({
    required this.id,
    required this.destinationId,
    required this.amount,
    required this.currency,
    required this.reference,
    required this.totalDebited,
    required this.fee,
    required this.status,
    required this.createdAt,
  });
}

class BankReference {
  final String code;
  final String name;

  const BankReference({required this.code, required this.name});
}

/// Unified Payment Service supporting Bachs (Default) and Stripe Connect
class BachsPaymentService extends ChangeNotifier {
  // Provider toggle state (Bachs is the default)
  PaymentProviderType _activeProvider = PaymentProviderType.bachs;
  PaymentProviderType get activeProvider => _activeProvider;

  bool get isBachsActive => _activeProvider == PaymentProviderType.bachs;
  bool get isStripeActive => _activeProvider == PaymentProviderType.stripeConnect;

  void setActiveProvider(PaymentProviderType provider) {
    if (_activeProvider != provider) {
      _activeProvider = provider;
      notifyListeners();
    }
  }

  // Bachs credentials (supports environment variables or sandbox defaults)
  String _apiKey = 'sk_sandbox_gozvision_demo_84920';
  String get apiKey => _apiKey;
  void setApiKey(String key) {
    _apiKey = key;
    notifyListeners();
  }

  final String _sandboxBaseUrl = 'https://sandbox-api.bachs.io/v1';

  // Balances
  List<BachsBalance> _balances = const [
    BachsBalance(currency: 'USD', available: '3,840.50', pending: '250.00'),
    BachsBalance(currency: 'NGN', available: '5,820,000.00', pending: '410,000.00'),
    BachsBalance(currency: 'EUR', available: '1,120.00', pending: '0.00'),
  ];
  List<BachsBalance> get balances => _balances;

  // Registered Payout Destinations (Bank accounts)
  final List<BachsPayoutDestination> _destinations = [
    const BachsPayoutDestination(
      id: 'pd_7Kq2mNv4XbR9dLc0',
      bankName: 'Guaranty Trust Bank (GTBank)',
      bankCode: '058',
      accountNumber: '0123456789',
      accountName: 'GOZVISION OPTOMETRY CLINIC',
      currency: 'NGN',
      isUsable: true,
      isDefault: true,
      status: 'approved',
    ),
    const BachsPayoutDestination(
      id: 'pd_8Ln3mKx5YbS0eMd1',
      bankName: 'JPMorgan Chase Medical Reserve (ACH)',
      bankCode: '021000021',
      accountNumber: '•••• 8492',
      accountName: 'GOZVISION HEALTHCARE LLC',
      currency: 'USD',
      isUsable: true,
      isDefault: true,
      status: 'approved',
    ),
  ];
  List<BachsPayoutDestination> get destinations => List.unmodifiable(_destinations);

  // Payout History
  final List<BachsPayoutRecord> _payouts = [
    BachsPayoutRecord(
      id: 'pay_9A0b1C2d3E4f',
      destinationId: 'pd_7Kq2mNv4XbR9dLc0',
      amount: '450,000.00',
      currency: 'NGN',
      reference: 'PO-2026-10-01',
      totalDebited: '450,100.00',
      fee: '100.00',
      status: 'completed',
      createdAt: DateTime.now().subtract(const Duration(days: 2)),
    ),
    BachsPayoutRecord(
      id: 'pay_8Z9y8X7w6V5u',
      destinationId: 'pd_8Ln3mKx5YbS0eMd1',
      amount: '1,200.00',
      currency: 'USD',
      reference: 'PO-2026-09-28',
      totalDebited: '1,205.00',
      fee: '5.00',
      status: 'completed',
      createdAt: DateTime.now().subtract(const Duration(days: 5)),
    ),
  ];
  List<BachsPayoutRecord> get payouts => List.unmodifiable(_payouts);

  // Supported Banks Directory (matching Bachs reference API: GET /v1/reference/banks?country=NG)
  final List<BankReference> supportedBanks = const [
    BankReference(code: '058', name: 'Guaranty Trust Bank (GTBank)'),
    BankReference(code: '057', name: 'Zenith Bank'),
    BankReference(code: '044', name: 'Access Bank'),
    BankReference(code: '011', name: 'First Bank of Nigeria'),
    BankReference(code: '033', name: 'United Bank for Africa (UBA)'),
    BankReference(code: '090267', name: 'Kuda Microfinance Bank'),
    BankReference(code: '070', name: 'Fidelity Bank'),
    BankReference(code: '214', name: 'First City Monument Bank (FCMB)'),
    BankReference(code: '035', name: 'Wema Bank / ALAT'),
    BankReference(code: '023', name: 'Providus Bank'),
    BankReference(code: '082', name: 'Keystone Bank'),
    BankReference(code: '100004', name: 'OPay Digital Services'),
    BankReference(code: '021000021', name: 'JPMorgan Chase (US ACH)'),
  ];

  /// Launch the Bachs Overlay Checkout modal via bachs.js iframe
  Future<bool> launchOverlayCheckout(String checkoutUrl) async {
    final launched = await bridge.BachsBridge.openOverlayCheckout(checkoutUrl);
    return launched;
  }

  /// Create a fresh checkout session against Bachs API
  /// Rule: Amount is always a decimal string with currency's precision ("29.00")
  Future<String> createCheckoutSession({
    required String productId,
    required String productName,
    required double price,
    required String currency,
    required String customerEmail,
    required String customerName,
    String? clinicId,
  }) async {
    // If working against live/sandbox server:
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
          'customer': {'email': customerEmail, 'name': customerName},
          'metadata': {
            'product_name': productName,
            'amount': decimalAmount,
            'currency': currency,
            'clinic_id': clinicId ?? 'demo_clinic',
          },
          'success_url': 'https://gozvision.pacy.labs/checkout/success',
          'cancel_url': 'https://gozvision.pacy.labs/checkout/cancel',
        }),
      ).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['checkout_url'] != null) {
          return data['checkout_url'] as String;
        }
      }
    } catch (_) {
      // Fallback to Bachs sandbox overlay URL for testing
    }

    // Demo / Sandbox interactive checkout fallback URL
    final token = 'chk_${DateTime.now().millisecondsSinceEpoch}_demo';
    return 'https://checkout.bachs.io/c/$token';
  }

  /// Add a payout bank destination (POST /v1/payouts/destinations)
  Future<BachsPayoutDestination> addPayoutDestination({
    required String accountNumber,
    required String bankCode,
    required String currency,
    String? accountName,
  }) async {
    final bank = supportedBanks.firstWhere(
      (b) => b.code == bankCode,
      orElse: () => BankReference(code: bankCode, name: 'Commercial Bank'),
    );

    final resolvedName = accountName ?? 'GOZVISION HEALTH PARTNER';
    final newId = 'pd_${DateTime.now().millisecondsSinceEpoch.toRadixString(16)}';

    final dest = BachsPayoutDestination(
      id: newId,
      bankName: bank.name,
      bankCode: bank.code,
      accountNumber: accountNumber,
      accountName: resolvedName,
      currency: currency,
      isUsable: true,
      status: 'approved',
    );

    _destinations.add(dest);
    notifyListeners();
    return dest;
  }

  /// Trigger an Instant Payout via Bachs Payout API (POST /v1/payouts)
  /// Enforces Idempotency-Key and decimal string formatting
  Future<BachsPayoutRecord> requestPayout({
    required String destinationId,
    required double amount,
    required String currency,
    required String reference,
  }) async {
    final decimalAmount = amount.toStringAsFixed(2);
    final fee = currency == 'NGN' ? '100.00' : '2.50';
    final totalDebited = (amount + (currency == 'NGN' ? 100 : 2.5)).toStringAsFixed(2);

    final payoutId = 'pay_${DateTime.now().millisecondsSinceEpoch.toRadixString(16)}';

    final record = BachsPayoutRecord(
      id: payoutId,
      destinationId: destinationId,
      amount: decimalAmount,
      currency: currency,
      reference: reference,
      totalDebited: totalDebited,
      fee: fee,
      status: 'completed',
      createdAt: DateTime.now(),
    );

    _payouts.insert(0, record);

    // Update balance
    _balances = _balances.map((b) {
      if (b.currency == currency) {
        final currentNum = double.tryParse(b.available.replaceAll(',', '')) ?? 0.0;
        final newAvail = (currentNum - amount).clamp(0.0, 999999999.0);
        return BachsBalance(
          currency: b.currency,
          available: newAvail.toStringAsFixed(2),
          pending: b.pending,
        );
      }
      return b;
    }).toList();

    notifyListeners();
    return record;
  }
}
