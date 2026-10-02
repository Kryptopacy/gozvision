import 'package:flutter_test/flutter_test.dart';
import 'package:copilot_core/copilot_core.dart';
import 'package:patient_app/services/user_memory_service.dart';

/// UserMemoryService resolves Firestore lazily, so its pure logic is
/// testable without an initialized Firebase app.
void main() {
  group('UserMemoryService logic tests', () {
    test('buildMemoryContext returns null for empty facts', () {
      final service = UserMemoryService();
      expect(service.facts.isEmpty, isTrue);
      expect(service.buildMemoryContext(), isNull);
    });

    test('a fresh service holds no facts', () {
      final service = UserMemoryService();
      expect(service.facts.length, 0);
    });

    test('memory context pulses carry the canonical user-memory tag', () {
      // The tag the service writes must be the one the system prompt
      // documents (see widget_test.dart for the prompt side of the contract).
      expect(SystemTags.userMemoryTag, contains('USER MEMORY'));
    });
  });
}
