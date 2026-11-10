import 'dart:typed_data';

import 'package:http/http.dart' as http;

/// Downloads direct HTTPS PDFs while enforcing host, redirect, time and size limits.
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

  static const Set<int> _redirectCodes = {301, 302, 303, 307, 308};

  final http.Client _client;
  final int maxBytes;
  final Duration timeout;

  bool _isAllowed(Uri uri) =>
      uri.scheme == 'https' &&
      allowedHosts.contains(uri.host) &&
      uri.userInfo.isEmpty;

  Future<http.StreamedResponse> _sendWithSafeRedirects(Uri initialUri) async {
    var uri = initialUri;

    for (var redirect = 0; redirect <= 4; redirect++) {
      if (!_isAllowed(uri)) {
        throw const FormatException('نشانی یا مسیر تغییرمسیر PDF مجاز نیست.');
      }

      final request = http.Request('GET', uri)..followRedirects = false;
      final response = await _client.send(request).timeout(timeout);

      if (!_redirectCodes.contains(response.statusCode)) {
        return response;
      }

      final location = response.headers['location'];
      await response.stream.drain<void>();
      if (location == null || location.trim().isEmpty || redirect == 4) {
        throw const FormatException('مسیر PDF بیش از حد تغییر کرد یا ناقص است.');
      }

      final nextUri = uri.resolve(location);
      if (!_isAllowed(nextUri)) {
        throw const FormatException(
          'میزبان فایل PDF به نشانی تأییدنشده تغییرمسیر داد.',
        );
      }
      uri = nextUri;
    }

    throw const FormatException('تعداد تغییرمسیرهای PDF بیش از حد مجاز است.');
  }

  Future<Uint8List> load(Uri uri) async {
    if (!_isAllowed(uri)) {
      throw const FormatException('نشانی امن و مجاز PDF معتبر نیست.');
    }

    final response = await _sendWithSafeRedirects(uri);
    if (response.statusCode != 200) {
      await response.stream.drain<void>();
      throw HttpException('دریافت PDF ناموفق بود (کد ${response.statusCode}).');
    }

    final contentType = response.headers['content-type']?.toLowerCase() ?? '';
    if (contentType.contains('text/html')) {
      await response.stream.drain<void>();
      throw const FormatException('میزبان به‌جای PDF یک صفحهٔ وب برگرداند.');
    }

    final advertisedLength = response.contentLength;
    if (advertisedLength != null && advertisedLength > maxBytes) {
      await response.stream.drain<void>();
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
