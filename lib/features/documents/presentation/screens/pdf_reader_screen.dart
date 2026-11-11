import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';

/// In-app PDF reader for the learning materials bundled with Fahmino.
class PdfReaderScreen extends StatefulWidget {
  const PdfReaderScreen({
    super.key,
    required this.assetPath,
    required this.title,
  });

  final String assetPath;
  final String title;

  @override
  State<PdfReaderScreen> createState() => _PdfReaderScreenState();
}

class _PdfReaderScreenState extends State<PdfReaderScreen> {
  late final PdfControllerPinch _controller;

  @override
  void initState() {
    super.initState();
    _controller = PdfControllerPinch(
      document: PdfDocument.openAsset(widget.assetPath),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _previousPage() {
    if (_controller.page <= 1) return;
    _controller.previousPage(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  void _nextPage() {
    final pagesCount = _controller.pagesCount;
    if (pagesCount == null || _controller.page >= pagesCount) return;
    _controller.nextPage(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 16),
            child: Center(
              child: PdfPageNumber(
                controller: _controller,
                builder: (_, page, loadingState, pagesCount) => Text(
                  '$page / ${pagesCount ?? '…'}',
                  style: theme.textTheme.labelLarge,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: PdfViewPinch(
              controller: _controller,
              builders: PdfViewPinchBuilders<DefaultBuilderOptions>(
                options: const DefaultBuilderOptions(),
                documentLoaderBuilder: (_) => const Center(
                  child: CircularProgressIndicator(),
                ),
                pageLoaderBuilder: (_) => const Center(
                  child: CircularProgressIndicator(),
                ),
                errorBuilder: (_, error) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.picture_as_pdf_outlined, size: 48),
                        const SizedBox(height: 12),
                        const Text(
                          'باز کردن این فایل PDF ممکن نشد.',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          error.toString(),
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ),
                builder: _buildDocument,
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _previousPage,
                      icon: const Icon(Icons.chevron_right_rounded),
                      label: const Text('صفحهٔ قبل'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _nextPage,
                      icon: const Icon(Icons.chevron_left_rounded),
                      label: const Text('صفحهٔ بعد'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _buildDocument(
    BuildContext context,
    PdfViewPinchBuilders builders,
    PdfLoadingState state,
    WidgetBuilder loadedBuilder,
    PdfDocument? document,
    Exception? loadingError,
  ) {
    switch (state) {
      case PdfLoadingState.loading:
        return builders.documentLoaderBuilder?.call(context) ??
            const Center(child: CircularProgressIndicator());
      case PdfLoadingState.error:
        return builders.errorBuilder?.call(
              context,
              loadingError ?? Exception('PDF loading failed'),
            ) ??
            const Center(child: Text('بارگذاری PDF ناموفق بود.'));
      case PdfLoadingState.success:
        return loadedBuilder(context);
    }
  }
}
