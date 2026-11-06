import 'dart:convert';

import 'package:http/http.dart' as http;

class GeminiApiException implements Exception {
  const GeminiApiException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Keeps the newest messages while ensuring Gemini receives a user-first
/// conversation. A 12-message slice can begin with an assistant message when
/// the full conversation has an odd length, so drop that unmatched prefix.
List<Map<String, String>> prepareGeminiHistory(
  List<Map<String, String>> messages, {
  int maxMessages = 12,
}) {
  if (maxMessages < 1) return <Map<String, String>>[];
  final start = messages.length > maxMessages ? messages.length - maxMessages : 0;
  final recent = messages
      .skip(start)
      .map((message) => Map<String, String>.from(message))
      .toList();

  if (recent.isNotEmpty && recent.first['role'] == 'model') {
    recent.removeAt(0);
  }
  return recent;
}

class GeminiApiService {
  GeminiApiService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<String> sendMessages({
    required String workerUrl,
    required List<Map<String, String>> messages,
  }) async {
    final base = workerUrl.trim().replaceFirst(RegExp(r'/+$'), '');
    final uri = Uri.tryParse('$base/api/chat');
    if (uri == null || !uri.hasScheme || !uri.hasAuthority ||
        !['https'].contains(uri.scheme)) {
      throw const GeminiApiException('آدرس سرور معتبر نیست؛ آدرس HTTPS را وارد کن.');
    }

    try {
      final response = await _client
          .post(
            uri,
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({'messages': messages}),
          )
          .timeout(const Duration(seconds: 45));

      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is Map<String, dynamic>) {
        if (response.statusCode >= 200 &&
            response.statusCode < 300 &&
            decoded['answer'] is String) {
          final answer = (decoded['answer'] as String).trim();
          if (answer.isNotEmpty) return answer;
        }
        final error = decoded['error'];
        if (error is String && error.isNotEmpty) {
          throw GeminiApiException(error);
        }
      }
      throw const GeminiApiException('پاسخ سرور قابل خواندن نیست.');
    } on GeminiApiException {
      rethrow;
    } catch (_) {
      throw const GeminiApiException(
        'اتصال برقرار نشد. اینترنت و آدرس Worker را بررسی کن.',
      );
    }
  }

  void dispose() => _client.close();
}
