import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';

/// In-app PDF reader for the learning materials bundled with Fahmino.
class PdfReaderScreen extends StatefulWidget {
  const PdfReaderScreen({super.key, required this.assetPath, required this.title});

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: PdfViewPinch(controller: _controller),
    );
  }
}
