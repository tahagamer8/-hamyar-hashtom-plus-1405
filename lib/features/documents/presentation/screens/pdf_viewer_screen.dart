import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:pdfx/pdfx.dart';

/// In-app PDF reader for bundled files, generated assets and verified HTTPS PDFs.
class PdfViewerScreen extends StatefulWidget {
  const PdfViewerScreen({
    super.key,
    required this.filePath,
    required this.title,
  })  : assetPath = null,
        uri = null;

  const PdfViewerScreen.asset({
    super.key,
    required this.title,
    required this.assetPath,
  })  : filePath = null,
        uri = null;

  const PdfViewerScreen.network({
    super.key,
    required this.title,
    required this.uri,
  })  : filePath = null,
        assetPath = null;

  final String? filePath;
  final String? assetPath;
  final Uri? uri;
  final String title;

  @override
  State<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen> {
  static const int _maxNetworkPdfBytes = 40 * 1024 * 1024;
  late final PdfControllerPinch _controller;

  @override
  void initState() {
    super.initState();
    _controller = PdfControllerPinch(document: _openDocument());
  }

  Future<PdfDocument> _openDocument() async {
    if (widget.filePath != null) {
      return PdfDocument.openFile(widget.filePath!);
    }
    if (widget.assetPath != null) {
      return PdfDocument.openAsset(widget.assetPath!);
    }

    final uri = widget.uri;
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
      throw const FormatException('نشانی امن PDF معتبر نیست.');
    }

    final response = await http.get(uri).timeout(
      const Duration(seconds: 35),
      onTimeout: () => throw Exception('دریافت PDF بیش از حد طول کشید.'),
    );

    if (response.statusCode != 200) {
      throw Exception('دریافت PDF ناموفق بود (کد ${response.statusCode}).');
    }

    final bytes = response.bodyBytes;
    if (bytes.length > _maxNetworkPdfBytes) {
      throw Exception('حجم این PDF بیشتر از حد مجاز ۴۰ مگابایت است.');
    }
    if (bytes.length < 5 || String.fromCharCodes(bytes.take(5)) != '%PDF-') {
      throw const FormatException(
        'نشانی انتخاب‌شده فایل PDF مستقیم برنگرداند؛ ممکن است صفحهٔ خطا یا پیوند منقضی شده باشد.',
      );
    }

    return PdfDocument.openData(bytes);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 12),
            child: Center(
              child: Text(
                'PDF',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
      body: PdfViewPinch(
        controller: _controller,
        builders: PdfViewPinchBuilders<DefaultBuilderOptions>(
          options: const DefaultBuilderOptions(),
          documentLoaderBuilder: (_) =>
              const Center(child: CircularProgressIndicator()),
          pageLoaderBuilder: (_) =>
              const Center(child: CircularProgressIndicator()),
          errorBuilder: (context, error) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.picture_as_pdf_outlined,
                      size: 44, color: theme.colorScheme.error),
                  const SizedBox(height: 12),
                  Text(
                    'نمایش این PDF ممکن نشد.',
                    style: theme.textTheme.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    error.toString(),
                    style: theme.textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
