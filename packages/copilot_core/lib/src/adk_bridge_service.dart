import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'session_config.dart';
import 'service_contracts.dart';

/// Service to bridge the Flutter app's Gemini Live session with the Python ADK Backend.
///
/// Employs Agent-to-Agent delegation: The conversational Gemini Live agent routes
/// specialized medical and statistical queries to the ADK agent, which performs RAG.
///
/// Speaks the ADK API server contract (google-adk >= 1.0):
/// 1. `POST /apps/{app}/users/{userId}/sessions` — create a throwaway session.
/// 2. `POST /run` with `{appName, userId, sessionId, newMessage}` — invoke the agent.
///
/// The userId doubles as the safety context: the backend's `send_sos_alert` tool
/// reads the patient id from the ADK session, so alerts always land on the right
/// patient's document for the caregiver dashboard to pick up.
class AdkBridgeService {
  static const _timeout = Duration(seconds: 15);

  final CopilotIdentity identity;
  final SessionConfig config;

  AdkBridgeService({required this.identity, required this.config});

  /// Delegates a query to the Python ADK backend.
  /// Handles errors gracefully so the conversational agent can inform the user
  /// rather than the app crashing.
  Future<String> consultBackendAgent(String query) async {
    final userId = identity.userId;
    debugPrint('AdkBridgeService: Delegating to ADK Agent (user $userId): "$query"');

    try {
      final sessionId = await _createSession(userId);
      if (sessionId == null) {
        return 'The specialized backend agent is unavailable right now. '
            'Please try again shortly.';
      }
      return await _runAgent(query, userId, sessionId);
    } on TimeoutException {
      debugPrint('AdkBridgeService: Request timed out.');
      return 'The specialized backend agent took too long to respond. The service might be sleeping or unreachable.';
    } catch (e) {
      debugPrint('AdkBridgeService: Network error: $e');
      return 'I am currently unable to reach the specialized medical backend. Local network error or the server is not running.';
    }
  }

  /// Creates a short-lived ADK session for this consultation and returns its id.
  Future<String?> _createSession(String userId) async {
    final url =
        '${config.adkBackendUrl}/apps/${config.adkAgentName}/users/$userId/sessions';
    final response = await http.post(
      Uri.parse(url),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(<String, dynamic>{}),
    ).timeout(_timeout);

    if (response.statusCode != 200) {
      debugPrint('AdkBridgeService: Session creation failed '
          'HTTP ${response.statusCode} - ${response.body}');
      return null;
    }
    final json = jsonDecode(response.body);
    final id = json['id'] as String?;
    if (id == null) {
      debugPrint('AdkBridgeService: Session response missing id: ${response.body}');
    }
    return id;
  }

  /// Runs one agent turn and returns the model's text output.
  Future<String> _runAgent(String query, String userId, String sessionId) async {
    final url = '${config.adkBackendUrl}/run';
    final response = await http.post(
      Uri.parse(url),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'appName': config.adkAgentName,
        'userId': userId,
        'sessionId': sessionId,
        'newMessage': {
          'role': 'user',
          'parts': [
            {'text': query},
          ],
        },
      }),
    ).timeout(_timeout);

    if (response.statusCode != 200) {
      debugPrint('AdkBridgeService: HTTP ${response.statusCode} - ${response.body}');
      return 'The specialized backend agent returned an error (Code: ${response.statusCode}).';
    }
    return _extractModelText(response.body);
  }

  /// Concatenates the model's text parts from the ADK event list response.
  static String _extractModelText(String body) {
    try {
      final events = jsonDecode(body) as List<dynamic>;
      final buffer = StringBuffer();
      for (final event in events) {
        if (event is! Map<String, dynamic>) continue;
        final content = event['content'] as Map<String, dynamic>?;
        if (content?['role'] != 'model') continue;
        final parts = content?['parts'] as List<dynamic>?;
        if (parts == null) continue;
        for (final part in parts) {
          final text = (part as Map<String, dynamic>)['text'] as String?;
          if (text != null && text.isNotEmpty) buffer.writeln(text);
        }
      }
      final output = buffer.toString().trim();
      return output.isEmpty
          ? 'The backend specialized agent returned an empty response.'
          : output;
    } catch (e) {
      debugPrint('AdkBridgeService: Failed to parse ADK events: $e');
      return 'The backend specialized agent returned an unreadable response.';
    }
  }
}
