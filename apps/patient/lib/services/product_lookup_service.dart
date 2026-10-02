import 'dart:convert';

import 'package:copilot_core/copilot_core.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Product data returned from a successful lookup.
class ProductData {
  final String name;
  final String? brand;
  final String? description;
  /// Drug-specific fields
  final String? dosage;
  final String? warnings;
  final String? activeIngredients;
  final String? storageInstructions;
  /// Food-specific fields
  final String? ingredients;
  final List<String>? allergens;
  final String? nutriScore;
  final String? calories;
  /// Source tag for Gemini rendering
  final String sourceTag; // e.g. '[PRODUCT DATA - MEDICATION]' or '[PRODUCT DATA - FOOD]'

  const ProductData({
    required this.name,
    this.brand,
    this.description,
    this.dosage,
    this.warnings,
    this.activeIngredients,
    this.storageInstructions,
    this.ingredients,
    this.allergens,
    this.nutriScore,
    this.calories,
    required this.sourceTag,
  });

  /// Formats the product data as a structured context string for Gemini.
  String toGroundingString() {
    final buf = StringBuffer();
    buf.writeln(sourceTag);
    buf.writeln('--- PRODUCT DATA ---');
    buf.writeln('Name: $name');
    if (brand != null) buf.writeln('Brand: $brand');
    if (description != null) buf.writeln('Description: $description');
    if (activeIngredients != null) buf.writeln('Active Ingredients: $activeIngredients');
    if (dosage != null) buf.writeln('Dosage: $dosage');
    if (warnings != null) buf.writeln('Warnings: $warnings');
    if (storageInstructions != null) buf.writeln('Storage: $storageInstructions');
    if (ingredients != null) buf.writeln('Ingredients: $ingredients');
    if (allergens != null && allergens!.isNotEmpty) {
      buf.writeln('ALLERGENS: ${allergens!.join(', ')}');
    }
    if (nutriScore != null) buf.writeln('Nutri-Score: $nutriScore');
    if (calories != null) buf.writeln('Calories per serving: $calories');
    buf.writeln('--- END PRODUCT DATA ---');
    return buf.toString();
  }
}

/// Tiered product/prescription lookup service.
///
/// Pipeline for any barcode:
/// 1. OpenFDA Drug API — for medications and prescriptions
/// 2. Open Food Facts API — for groceries and packaged foods
/// 3. Returns null → caller falls back to Gemini vision mode
class ProductLookupService implements CopilotProductLookup {
  static const _fdaBase = 'https://api.fda.gov/drug/label.json';
  static const _openFoodFactsBase = 'https://world.openfoodfacts.org/api/v3/product';
  static const _timeout = Duration(seconds: 5);

  /// Looks up a product by [barcode].
  /// Returns a [ProductData] object or null if no data found.
  @override
  Future<ScannedProduct?> lookup(String barcode) async {
    // Tier 1: Try OpenFDA (prescriptions & OTC drugs)
    final medication = await _lookupFda(barcode);
    if (medication != null) return ScannedProduct(medication.toGroundingString());

    // Tier 2: Try Open Food Facts (grocery products)
    final food = await _lookupOpenFoodFacts(barcode);
    if (food != null) return ScannedProduct(food.toGroundingString());

    debugPrint('ProductLookupService: No data found for barcode $barcode');
    return null;
  }

  Future<ProductData?> _lookupFda(String barcode) async {
    try {
      final uri = Uri.parse(
        '$_fdaBase?search=openfda.upc%3A"$barcode"&limit=1',
      );
      final response = await http.get(uri).timeout(_timeout);

      if (response.statusCode != 200) return null;

      final dynamic data;
      try {
        data = jsonDecode(response.body);
      } catch (e) {
        final snippet = response.body.length > 200 
            ? response.body.substring(0, 200) 
            : response.body;
        debugPrint('ProductLookupService: FDA JSON Parse Error: $e');
        debugPrint('Response Body (first 200 chars): $snippet');
        return null;
      }
      final Map<String, dynamic> json = data as Map<String, dynamic>;
      final results = json['results'] as List<dynamic>?;
      if (results == null || results.isEmpty) return null;

      final drug = results.first as Map<String, dynamic>;
      final openfda = drug['openfda'] as Map<String, dynamic>? ?? {};

      final name = (openfda['brand_name'] as List<dynamic>?)?.first as String?
          ?? (openfda['generic_name'] as List<dynamic>?)?.first as String?
          ?? 'Unknown Drug';

      String? dosage;
      final dosageList = drug['dosage_and_administration'] as List<dynamic>?;
      if (dosageList != null && dosageList.isNotEmpty) {
        // Trim to 300 chars — Gemini will narrate it
        dosage = (dosageList.first as String).substring(
          0,
          (dosageList.first as String).length.clamp(0, 300),
        );
      }

      String? warnings;
      final warnList = drug['warnings'] as List<dynamic>?;
      if (warnList != null && warnList.isNotEmpty) {
        warnings = (warnList.first as String).substring(
          0,
          (warnList.first as String).length.clamp(0, 300),
        );
      }

      final activeIngredients = (drug['active_ingredient'] as List<dynamic>?)
              ?.first as String?;
      final storage = (drug['storage_and_handling'] as List<dynamic>?)
              ?.first as String?;

      debugPrint('ProductLookupService: FDA hit for $name');
      return ProductData(
        name: name,
        brand: (openfda['manufacturer_name'] as List<dynamic>?)?.first as String?,
        activeIngredients: activeIngredients,
        dosage: dosage,
        warnings: warnings,
        storageInstructions: storage,
        sourceTag: '[PRODUCT DATA - MEDICATION]',
      );
    } catch (e) {
      debugPrint('ProductLookupService: FDA lookup failed: $e');
      return null;
    }
  }

  Future<ProductData?> _lookupOpenFoodFacts(String barcode) async {
    try {
      final uri = Uri.parse('$_openFoodFactsBase/$barcode.json');
      final response = await http.get(
        uri,
        headers: {'User-Agent': 'GozAI/1.0 (accessibility copilot)'},
      ).timeout(_timeout);

      if (response.statusCode != 200) return null;

      final dynamic data;
      try {
        data = jsonDecode(response.body);
      } catch (e) {
        final snippet = response.body.length > 200 
            ? response.body.substring(0, 200) 
            : response.body;
        debugPrint('ProductLookupService: OpenFoodFacts JSON Parse Error: $e');
        debugPrint('Response Body (first 200 chars): $snippet');
        return null;
      }
      final Map<String, dynamic> json = data as Map<String, dynamic>;
      if (json['status'] == 0) return null; // Product not found

      final product = json['product'] as Map<String, dynamic>?;
      if (product == null) return null;

      final name = product['product_name'] as String? ?? 'Unknown Product';
      final brand = product['brands'] as String?;
      final ingredients = product['ingredients_text'] as String?;
      final nutriScore = (product['nutriscore_grade'] as String?)?.toUpperCase();
      
      // Extract allergens
      final allergensField = product['allergens_tags'] as List<dynamic>? ?? [];
      final allergens = allergensField
          .map((e) => (e as String).replaceAll('en:', ''))
          .where((e) => e.isNotEmpty)
          .toList();

      // Get calories
      final nutrients = product['nutriments'] as Map<String, dynamic>? ?? {};
      final calories = nutrients['energy-kcal_100g']?.toString();

      debugPrint('ProductLookupService: Open Food Facts hit for $name');
      return ProductData(
        name: name,
        brand: brand,
        ingredients: ingredients,
        allergens: allergens,
        nutriScore: nutriScore,
        calories: calories != null ? '$calories kcal per 100g' : null,
        sourceTag: '[PRODUCT DATA - FOOD]',
      );
    } catch (e) {
      debugPrint('ProductLookupService: Open Food Facts lookup failed: $e');
      return null;
    }
  }
}
