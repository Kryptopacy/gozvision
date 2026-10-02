import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';

/// Native implementation: scans for a barcode in JPEG bytes using ML Kit.
Future<String?> scanBarcodeFromBytes(Uint8List bytes) async {
  final scanner = BarcodeScanner(formats: [
    BarcodeFormat.ean13,
    BarcodeFormat.ean8,
    BarcodeFormat.upca,
    BarcodeFormat.upce,
    BarcodeFormat.qrCode,
  ]);

  try {
    final inputImage = InputImage.fromBytes(
      bytes: bytes,
      metadata: InputImageMetadata(
        size: const Size(1280, 720),
        rotation: InputImageRotation.rotation0deg,
        format: InputImageFormat.nv21,
        bytesPerRow: 1280,
      ),
    );

    final barcodes = await scanner.processImage(inputImage);
    if (barcodes.isNotEmpty) {
      final code = barcodes.first.rawValue;
      debugPrint('BarcodeService: Found barcode: $code');
      return code;
    }
    return null;
  } catch (e) {
    debugPrint('BarcodeService: Scan error: $e');
    return null;
  } finally {
    await scanner.close();
  }
}
