import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import 'package:copilot_core/copilot_core.dart';

/// Offline OCR service using Google ML Kit.
///
/// Provides on-device text recognition as a fast pre-filter before
/// sending frames to Gemini for deeper understanding. Works without
/// internet for basic text reading tasks.
class OcrService extends ChangeNotifier implements CopilotOcr {
  final TextRecognizer _recognizer = TextRecognizer();
  bool _isProcessing = false;
  String _lastResult = '';

  bool get isProcessing => _isProcessing;
  String get lastResult => _lastResult;

  /// Recognize text from an image file path.
  Future<OcrResult> recognizeFromPath(String imagePath) async {
    _isProcessing = true;
    notifyListeners();

    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final recognized = await _recognizer.processImage(inputImage);

      final result = OcrResult(
        fullText: recognized.text,
        blocks: recognized.blocks.map((block) {
          return OcrBlock(
            text: block.text,
            confidence: block.lines.fold<double>(
                  0,
                  (sum, line) => sum + (line.confidence ?? 0),
                ) /
                (block.lines.isEmpty ? 1 : block.lines.length),
            boundingBox: block.boundingBox,
            lines: block.lines.map((line) => line.text).toList(),
          );
        }).toList(),
      );

      _lastResult = result.fullText;
      _isProcessing = false;
      notifyListeners();

      debugPrint('OcrService: Recognized ${result.blocks.length} blocks, '
          '${result.fullText.length} chars');
      return result;
    } catch (e) {
      debugPrint('OcrService: Recognition failed: $e');
      _isProcessing = false;
      notifyListeners();
      return OcrResult.empty();
    }
  }

  /// Recognize text from raw image bytes (JPEG/PNG).
  @override
  Future<OcrResult> recognizeFromBytes(Uint8List bytes) async {
    _isProcessing = true;
    notifyListeners();

    try {
      final inputImage = InputImage.fromBytes(
        bytes: bytes,
        metadata: InputImageMetadata(
          size: const Size(1280, 720), // Approximate, ML Kit is flexible
          rotation: InputImageRotation.rotation0deg,
          format: InputImageFormat.nv21,
          bytesPerRow: 1280,
        ),
      );
      final recognized = await _recognizer.processImage(inputImage);

      final result = OcrResult(
        fullText: recognized.text,
        blocks: recognized.blocks.map((block) {
          return OcrBlock(
            text: block.text,
            confidence: block.lines.fold<double>(
                  0,
                  (sum, line) => sum + (line.confidence ?? 0),
                ) /
                (block.lines.isEmpty ? 1 : block.lines.length),
            boundingBox: block.boundingBox,
            lines: block.lines.map((line) => line.text).toList(),
          );
        }).toList(),
      );

      _lastResult = result.fullText;
      _isProcessing = false;
      notifyListeners();
      return result;
    } catch (e) {
      debugPrint('OcrService: Byte recognition failed: $e');
      _isProcessing = false;
      notifyListeners();
      return OcrResult.empty();
    }
  }

  /// Check if recognized text looks like a medication label.
  @override
  bool isMedicationLabel(CopilotOcrRead result) {
    final keywords = [
      'mg', 'ml', 'tablet', 'capsule', 'drops', 'dose', 'dosage',
      'take', 'daily', 'twice', 'prescription', 'rx', 'refill',
      'exp', 'expir', 'pharmacy', 'ndc',
    ];
    final textLower = result.fullText.toLowerCase();
    final matches = keywords.where((kw) => textLower.contains(kw)).length;
    return matches >= 2; // At least 2 medication-related keywords
  }

  /// Check if recognized text looks like a prescription label (RX drug label).
  ///
  /// Prescriptions contain regulatory markers: NDC number, DEA number,
  /// "Rx only", refill count, prescribing doctor. When this is detected,
  /// Gemini is instructed to read the drug name letter-by-letter for safety.
  @override
  bool isPrescriptionLabel(CopilotOcrRead result) {
    final keywords = [
      'rx only', 'rx', 'ndc', 'dea', 'dispense', 'refill',
      'prescriber', 'prescribed by', 'quantity', 'days supply',
      'prior auth', 'sig:', 'take as directed',
    ];
    final textLower = result.fullText.toLowerCase();
    final matches = keywords.where((kw) => textLower.contains(kw)).length;
    return matches >= 2;
  }

  /// Check if recognized text looks like a nutrition/food label.

  @override
  bool isNutritionLabel(CopilotOcrRead result) {
    final keywords = [
      'calories', 'fat', 'protein', 'carbohydrate', 'sodium',
      'sugar', 'fiber', 'serving', 'nutrition', 'ingredients',
    ];
    final textLower = result.fullText.toLowerCase();
    final matches = keywords.where((kw) => textLower.contains(kw)).length;
    return matches >= 2;
  }

  @override
  void dispose() {
    _recognizer.close();
    super.dispose();
  }
}

/// Result of OCR processing.
class OcrResult implements CopilotOcrRead {
  @override
  final String fullText;
  final List<OcrBlock> blocks;

  OcrResult({required this.fullText, required this.blocks});

  factory OcrResult.empty() => OcrResult(fullText: '', blocks: []);

  @override
  bool get isEmpty => fullText.isEmpty;
  @override
  bool get isNotEmpty => fullText.isNotEmpty;

  /// Formats the OCR result into a structured grounding prompt for Gemini.
  /// Includes bounding box coordinates for spatial layout awareness (e.g. columns).
  @override
  String buildGroundingString({bool isMedication = false, bool isNutrition = false}) {
    if (isEmpty) return '';
    final buffer = StringBuffer();
    if (isMedication) buffer.writeln('[${SystemTags.medicationLabelTag}]');
    if (isNutrition) buffer.writeln('[${SystemTags.nutritionLabelTag}]');

    buffer.writeln('--- DOCUMENT LAYOUT START ---');
    for (final block in blocks) {
      final b = block.boundingBox;
      final cleanText = block.text.replaceAll('\n', ' ');
      if (b != null) {
        final x = b.left.toInt();
        final y = b.top.toInt();
        final w = b.width.toInt();
        final h = b.height.toInt();
        buffer.writeln('(x:$x, y:$y, w:$w, h:$h): $cleanText');
      } else {
        buffer.writeln(cleanText);
      }
    }
    buffer.writeln('--- DOCUMENT LAYOUT END ---');
    return buffer.toString();
  }
}

/// A block of recognized text with spatial information.
class OcrBlock {
  final String text;
  final double confidence;
  final Rect? boundingBox;
  final List<String> lines;

  OcrBlock({
    required this.text,
    required this.confidence,
    this.boundingBox,
    required this.lines,
  });
}
