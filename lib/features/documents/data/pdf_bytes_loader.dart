import 'dart:typed_data';

import 'package:http/http.dart' as http;

/// Downloads only direct HTTPS PDFs from the two benchmark resource hosts.
class PdfBytesLoader {
  PdfBytesLoader({
    http.Client? client,
    this.maxBytes = 40 * 1024 * 1024,
    this.timeout = const Duration(seconds: 35),
  }) : _client = client ?? http.Client();

  static const Set<String> allowedHosts = {
    'dl.hamyar.me',
    'static.paadars.com',
  };

  final http.Client _client;
  final int maxBytes;
  final Duration timeout;

  Future<Uint8List> load(Uri uri) async {
    if (uri.scheme != 'https' ||
        !allowedHosts.contains(uri.host) ||
        uri.userInfo.isNotEmpty) {
      throw const FormatException('نشانی امن و مجاز PDF معتبر نیست.');
    }

    final request = http.Request('GET', uri);
    final response = await _client.send(request).timeout(timeout);

    if (response.statusCode != 200) {
      throw HttpException('دریافت PDF ناموفق بود (کد ${response.statusCode}).');
    }

    final advertisedLength = response.contentLength;
    if (advertisedLength != null && advertisedLength > maxBytes) {
      throw const FormatException('حجم PDF بیشتر از حد مجاز است.');
    }

    final builder = BytesBuilder(copy: false);
    var received = 0;
    await for (final chunk in response.stream.timeout(timeout)) {
      received += chunk.length;
      if (received > maxBytes) {
        throw const FormatException('حجم PDF بیشتر از حد مجاز است.');
      }
      builder.add(chunk);
    }

    final bytes = builder.takeBytes();
    if (bytes.length < 5 ||
        String.fromCharCodes(bytes.take(5)) != '%PDF-') {
      throw const FormatException(
        'نشانی انتخاب‌شده فایل PDF مستقیم برنگرداند؛ ممکن است پیوند منقضی شده باشد.',
      );
    }
    return bytes;
  }

  void dispose() => _client.close();
}

class HttpException implements Exception {
  const HttpException(this.message);
  final String message;

  @override
  String toString() => message;
}
