import 'package:flutter/material.dart';
import 'package:hamyar_hashtom_plus/features/documents/data/pdf_bytes_loader.dart';
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
  late final PdfControllerPinch _controller;
  PdfBytesLoader? _bytesLoader;

  @override
  void initState() {
    super.initState();
    if (widget.uri != null) _bytesLoader = PdfBytesLoader();
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
    if (uri == null) {
      throw const FormatException('نشانی امن PDF معتبر نیست.');
    }
    final bytes = await _bytesLoader!.load(uri);
    return PdfDocument.openData(bytes);
  }

  @override
  void dispose() {
    _controller.dispose();
    _bytesLoader?.dispose();
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
