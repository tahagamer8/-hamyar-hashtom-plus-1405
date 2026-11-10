import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:hamyar_hashtom_plus/features/documents/data/pdf_bytes_loader.dart';

void main() {
  final pdfBytes = utf8.encode('%PDF-1.7\nFahmino test PDF');

  test('accepts a valid PDF from an approved HTTPS host', () async {
    final client = MockClient((request) async {
      expect(request.url.host, 'static.paadars.com');
      return http.Response.bytes(pdfBytes, 200);
    });
    final loader = PdfBytesLoader(client: client);

    expect(
      await loader.load(Uri.parse(
        'https://static.paadars.com/files/sample.pdf',
      )),
      orderedEquals(pdfBytes),
    );
    loader.dispose();
  });

  test('rejects non-HTTPS and unapproved hosts before making a request', () async {
    var requested = false;
    final client = MockClient((request) async {
      requested = true;
      return http.Response.bytes(pdfBytes, 200);
    });
    final loader = PdfBytesLoader(client: client);

    await expectLater(
      loader.load(Uri.parse('http://static.paadars.com/sample.pdf')),
      throwsA(isA<FormatException>()),
    );
    await expectLater(
      loader.load(Uri.parse('https://example.com/sample.pdf')),
      throwsA(isA<FormatException>()),
    );
    expect(requested, isFalse);
    loader.dispose();
  });

  test('rejects HTML error pages returned with HTTP 200', () async {
    final client = MockClient((request) async =>
        http.Response('<html>not a PDF</html>', 200));
    final loader = PdfBytesLoader(client: client);

    await expectLater(
      loader.load(Uri.parse('https://dl.hamyar.me/sample.pdf')),
      throwsA(isA<FormatException>()),
    );
    loader.dispose();
  });

  test('rejects an HTTP error status', () async {
    final client = MockClient((request) async =>
        http.Response('not found', 404));
    final loader = PdfBytesLoader(client: client);

    await expectLater(
      loader.load(Uri.parse('https://dl.hamyar.me/sample.pdf')),
      throwsA(isA<HttpException>()),
    );
    loader.dispose();
  });

  test('enforces the response size limit while streaming', () async {
    final client = MockClient((request) async =>
        http.Response.bytes(pdfBytes, 200));
    final loader = PdfBytesLoader(client: client, maxBytes: 8);

    await expectLater(
      loader.load(Uri.parse('https://dl.hamyar.me/sample.pdf')),
      throwsA(isA<FormatException>()),
    );
    loader.dispose();
  });
  test('follows redirects only within the approved PDF hosts', () async {
    var requests = 0;
    final client = MockClient((request) async {
      requests++;
      if (requests == 1) {
        return http.Response('', 302, headers: {
          'location': 'https://static.paadars.com/files/final.pdf',
        });
      }
      return http.Response.bytes(pdfBytes, 200);
    });
    final loader = PdfBytesLoader(client: client);

    expect(
      await loader.load(Uri.parse('https://dl.hamyar.me/files/start.pdf')),
      orderedEquals(pdfBytes),
    );
    expect(requests, 2);
    loader.dispose();
  });

  test('rejects redirects to unapproved hosts', () async {
    final client = MockClient((request) async => http.Response(
      '',
      302,
      headers: {'location': 'https://example.com/collect.pdf'},
    ));
    final loader = PdfBytesLoader(client: client);

    await expectLater(
      loader.load(Uri.parse('https://dl.hamyar.me/files/start.pdf')),
      throwsA(isA<FormatException>()),
    );
    loader.dispose();
  });

  test('rejects a URI containing embedded credentials', () async {
    var requested = false;
    final client = MockClient((request) async {
      requested = true;
      return http.Response.bytes(pdfBytes, 200);
    });
    final loader = PdfBytesLoader(client: client);

    await expectLater(
      loader.load(Uri.parse('https://student:secret@dl.hamyar.me/sample.pdf')),
      throwsA(isA<FormatException>()),
    );
    expect(requested, isFalse);
    loader.dispose();
  });

}
