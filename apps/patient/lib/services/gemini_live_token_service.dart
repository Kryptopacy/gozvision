import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/app_config.dart';

/// Exchanges the signed-in patient's Supabase session for a one-use Gemini
/// Live WebSocket URL. The permanent Gemini key remains on the backend.
class GeminiLiveTokenService {
  const GeminiLiveTokenService._();

  static Future<String> fetchWebSocketUrl() async {
    final session = Supabase.instance.client.auth.currentSession;
    final accessToken = session?.accessToken;
    if (accessToken == null || accessToken.isEmpty) {
      throw StateError('Sign in is required to start GozAI Live.');
    }

    final response = await http.post(
      Uri.parse('${AppConfig.adkBackendUrl}/gemini/live-token'),
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      },
    ).timeout(const Duration(seconds: 20));

    if (response.statusCode != 200) {
      throw StateError(
          'GozAI Live authentication failed (${response.statusCode}).');
    }

    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final url = payload['websocket_url'] as String?;
    if (url == null || !url.startsWith('wss://')) {
      throw StateError('GozAI Live returned an invalid session endpoint.');
    }
    return url;
  }
}
