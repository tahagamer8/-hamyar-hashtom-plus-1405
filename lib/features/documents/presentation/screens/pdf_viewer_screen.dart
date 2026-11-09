import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

/// Opens an offline chapter PDF asset or a verified external PDF URL in-app.
class PdfViewerScreen extends StatelessWidget {
  const PdfViewerScreen.asset({
    super.key,
    required this.title,
    required this.assetPath,
  }) : uri = null;

  const PdfViewerScreen.network({
    super.key,
    required this.title,
    required this.uri,
  }) : assetPath = null;

  final String title;
  final String? assetPath;
  final Uri? uri;

  @override
  Widget build(BuildContext context) {
    final pdf = assetPath != null
        ? PdfViewer.asset(assetPath!)
        : PdfViewer.uri(uri!);

    return Scaffold(
      appBar: AppBar(
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      body: ColoredBox(
        color: Theme.of(context).colorScheme.surface,
        child: pdf,
      ),
    );
  }
}
