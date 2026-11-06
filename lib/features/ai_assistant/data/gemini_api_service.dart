import 'dart:convert';

import 'package:http/http.dart' as http;

class GeminiApiException implements Exception {
  const GeminiApiException(this.message);
  final String message;

  @override
  String toString() => message;
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
          return (decoded['answer'] as String).trim();
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
