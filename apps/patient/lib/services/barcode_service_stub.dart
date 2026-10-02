import 'dart:typed_data';

/// Web stub for barcode scanning.
/// ML Kit barcode is not available on web — returns null gracefully.
/// Gemini vision takes over for label reading on the web platform.
Future<String?> scanBarcodeFromBytes(Uint8List bytes) async {
  return null;
}
