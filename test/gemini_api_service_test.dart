import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:hamyar_hashtom_plus/features/ai_assistant/data/gemini_api_service.dart';

void main() {
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
