import 'package:flutter/foundation.dart';
import 'package:copilot_core/copilot_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';


/// Persistent user memory service — gives Goz a companion-grade memory.
///
/// Stores and retrieves key facts about the user across sessions in the
/// `memory_facts` table (Supabase). Examples: medications, caregiver name,
/// familiar locations, preferences.
///
/// Gemini can autonomously write to this memory by calling the `rememberFact`
/// intent. On session start, the memory is loaded and injected as silent
/// system context.
class UserMemoryService extends ChangeNotifier implements CopilotMemory {
  UserMemoryService({SupabaseClient? client}) : _injectedClient = client;

  static const int _maxFacts = 50;

  // The client is resolved lazily so the service can be constructed (and
  // its pure logic tested) without an initialized Supabase connection.
  final SupabaseClient? _injectedClient;
  SupabaseClient get _client => _injectedClient ?? Supabase.instance.client;

  List<Map<String, dynamic>> _facts = [];

  /// All currently loaded facts.
  @override
  List<Map<String, dynamic>> get facts => List.unmodifiable(_facts);

  /// Loads all stored facts for [userId]. Call when the session starts.
  @override
  Future<void> loadMemory(String userId) async {
    try {
      final rows = await _client
          .from('memory_facts')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(_maxFacts);
      _facts = (rows as List)
          .map<Map<String, dynamic>>((r) => {
                'category': r['category'] ?? 'general',
                'fact': r['fact'] ?? '',
                'timestamp': r['created_at'],
                'id': r['id'],
              })
          .toList();
      debugPrint(
          'UserMemoryService: Loaded ${_facts.length} facts for user $userId');
      notifyListeners();
    } catch (e) {
      debugPrint('UserMemoryService: Failed to load memory: $e');
    }
  }

  /// Stores a new fact for [userId]. Gemini calls this via `rememberFact`.
  @override
  Future<void> storeFact({
    required String userId,
    required String category,
    required String fact,
  }) async {
    try {
      await _client.from('memory_facts').insert({
        'user_id': userId,
        'category': category,
        'fact': fact,
      });

      // Also add locally for immediate use
      _facts.insert(0, {
        'category': category,
        'fact': fact,
        'timestamp': DateTime.now().toIso8601String(),
      });

      // Cap local memory
      if (_facts.length > _maxFacts) {
        _facts = _facts.sublist(0, _maxFacts);
      }

      debugPrint('UserMemoryService: Stored fact [$category]: $fact');
      notifyListeners();
    } catch (e) {
      debugPrint('UserMemoryService: Failed to store fact: $e');
    }
  }

  /// Builds a context string for injection into Gemini's system prompt.
  /// Returns null if no facts are available.
  @override
  String? buildMemoryContext() {
    if (_facts.isEmpty) return null;

    final buffer = StringBuffer('[${SystemTags.userMemoryTag}]\n');
    buffer.writeln('The following are things you have remembered about the user:');

    for (final fact in _facts) {
      final category = fact['category'] ?? 'general';
      final content = fact['fact'] ?? '';
      buffer.writeln('- [$category] $content');
    }

    buffer.writeln('Use this knowledge naturally in conversation. Do NOT read it back as a list.');
    return buffer.toString();
  }
}
