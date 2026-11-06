import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:hamyar_hashtom_plus/features/ai_assistant/data/gemini_api_service.dart';

void main() {
  test('keeps Gemini history user-first when the 12-message window is odd', () {
    final messages = <Map<String, String>>[];
    for (var i = 0; i < 6; i++) {
      messages.add({'role': 'user', 'text': 'پرسش $i'});
      messages.add({'role': 'model', 'text': 'پاسخ $i'});
    }
    messages.add({'role': 'user', 'text': 'پرسش تازه'});

    final history = prepareGeminiHistory(messages);

    expect(history, hasLength(11));
    expect(history.first['role'], 'user');
    expect(history.last['role'], 'user');
    expect(history[0]['text'], 'پرسش 1');
  });

  test('retains a valid recent user-first history when no prefix is needed', () {
    final history = prepareGeminiHistory([
      {'role': 'user', 'text': 'سلام'},
      {'role': 'model', 'text': 'سلام!'},
      {'role': 'user', 'text': 'سؤال دوم'},
    ]);

    expect(history.map((message) => message['role']).toList(),
        ['user', 'model', 'user']);
  });

  test('checks the Worker health endpoint without sending a chat request', () async {
    Uri? requestedUri;
    final service = GeminiApiService(
      client: MockClient((request) async {
        requestedUri = request.url;
        return http.Response(
          jsonEncode({
            'ok': true,
            'service': 'fahmino-api',
            'geminiSecretConfigured': true,
            'rateLimiterConfigured': true,
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    final health = await service.checkHealth(
      workerUrl: 'https://fahmino.example.workers.dev/',
    );

    expect(requestedUri.toString(), 'https://fahmino.example.workers.dev/health');
    expect(health['geminiSecretConfigured'], true);
    expect(health['rateLimiterConfigured'], true);
    service.dispose();
  });

  test('sends chat history to the Worker endpoint and returns the answer', () async {
    Uri? requestedUri;
    Map<String, dynamic>? requestedBody;
    final client = MockClient((request) async {
      requestedUri = request.url;
      requestedBody = jsonDecode(request.body) as Map<String, dynamic>;
      return http.Response(
        jsonEncode({'answer': 'عدد گویا را می‌توان به صورت کسر نوشت.'}),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });
    final service = GeminiApiService(client: client);

    final answer = await service.sendMessages(
      workerUrl: 'https://fahmino.example.workers.dev/',
      messages: [
        {'role': 'user', 'text': 'عدد گویا چیست؟'},
      ],
    );

    expect(requestedUri!.toString(),
        'https://fahmino.example.workers.dev/api/chat');
    expect(requestedBody!['messages'], [
      {'role': 'user', 'text': 'عدد گویا چیست؟'},
    ]);
    expect(answer, 'عدد گویا را می‌توان به صورت کسر نوشت.');
    service.dispose();
  });

  test('rejects non-HTTPS Worker addresses', () async {
    final service = GeminiApiService(client: MockClient((_) async {
      fail('No request should be sent for an insecure URL.');
    }));

    expect(
      () => service.sendMessages(
        workerUrl: 'http://example.workers.dev',
        messages: [
          {'role': 'user', 'text': 'سلام'},
        ],
      ),
      throwsA(isA<GeminiApiException>()),
    );
    service.dispose();
  });

  test('shows a readable API error returned by the Worker', () async {
    final service = GeminiApiService(
      client: MockClient((_) async => http.Response(
            jsonEncode({'error': 'سهمیه تمام شده است.'}),
            429,
            headers: {'content-type': 'application/json'},
          )),
    );

    expect(
      () => service.sendMessages(
        workerUrl: 'https://fahmino.example.workers.dev',
        messages: [
          {'role': 'user', 'text': 'سلام'},
        ],
      ),
      throwsA(
        isA<GeminiApiException>().having(
          (error) => error.message,
          'message',
          'سهمیه تمام شده است.',
        ),
      ),
    );
    service.dispose();
  });
}
