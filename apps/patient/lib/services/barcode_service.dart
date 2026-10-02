import 'package:flutter/foundation.dart';
import 'package:copilot_core/copilot_core.dart';

// Conditional imports for native vs web
import 'barcode_service_native.dart'
    if (dart.library.js_interop) 'barcode_service_stub.dart';

/// Barcode scanning service.
///
/// On native (iOS/Android): Uses Google ML Kit to scan EAN-13, UPC-A, and QR barcodes.
/// On web: Returns null gracefully — Gemini vision handles the label reading instead.
///
/// The result is fed directly into [ProductLookupService] to retrieve
/// structured product data from OpenFDA or Open Food Facts.
class BarcodeService implements CopilotBarcodeScanner {
  static final BarcodeService _instance = BarcodeService._internal();
  factory BarcodeService() => _instance;
  BarcodeService._internal();

  /// Scans the given JPEG [bytes] for any barcode.
  /// Returns the decoded barcode string, or null if none found.
  @override
  Future<String?> scanFromBytes(Uint8List bytes) async {
    if (kIsWeb) {
      // Web: ML Kit barcode scanning not supported, return null gracefully
      return null;
    }
    return scanBarcodeFromBytes(bytes);
  }
}
