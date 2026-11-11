import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:hamyar_hashtom_plus/features/documents/presentation/screens/pdf_reader_screen.dart';

class SubjectPdfCard extends StatefulWidget {
  const SubjectPdfCard({super.key, required this.subjectId, required this.subjectTitle, this.questionsOnly = false});
  final String subjectId;
  final String subjectTitle;
  final bool questionsOnly;
  @override
  State<SubjectPdfCard> createState() => _SubjectPdfCardState();
}

class _SubjectPdfCardState extends State<SubjectPdfCard> {
  bool _busy = false;
  bool _downloaded = false;
  String get _fileName => 'Fahmino-' + widget.subjectId + (widget.questionsOnly ? '-Questions-FA.pdf' : '-Notes-FA.pdf');
  String get _documentLabel => widget.questionsOnly ? 'نمونه‌سؤال' : 'جزوه';

  Future<File> _file() async {
    final root = await getApplicationDocumentsDirectory();
    final dir = Directory('${root.path}/Fahmino-PDFs');
    if (!await dir.exists()) await dir.create(recursive: true);
    return File('${dir.path}/$_fileName');
  }

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    try {
      final f = await _file();
      final exists = await f.exists() && await f.length() > 0;
      if (mounted) setState(() => _downloaded = exists);
    } catch (_) {
      if (mounted) setState(() => _downloaded = false);
    }
  }

  Future<void> _download() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final f = await _file();
      if (!await f.exists() || await f.length() == 0) {
        final data = await rootBundle.load('assets/generated_pdfs/$_fileName');
        await f.writeAsBytes(data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes), flush: true);
      }
      if (!mounted) return;
      setState(() => _downloaded = true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_documentLabel + ' ' + widget.subjectTitle + ' برای استفادهٔ آفلاین ذخیره شد.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ذخیرهٔ PDF ممکن نشد؛ فایل در این نسخه موجود نیست.')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _open() async {
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => PdfReaderScreen(
        assetPath: 'assets/generated_pdfs/' + _fileName,
        title: _documentLabel + ' ' + widget.subjectTitle,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.picture_as_pdf_rounded, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Expanded(child: Text(_documentLabel + ' PDF ' + widget.subjectTitle, style: theme.textTheme.titleSmall)),
            if (_downloaded) const Icon(Icons.offline_pin_rounded, color: Colors.green, size: 20),
          ]),
          const SizedBox(height: 5),
          Text('فایل را داخل فهمینو بخوان یا برای استفادهٔ آفلاین ذخیره کن.',
              style: theme.textTheme.bodySmall),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: [
            FilledButton.tonalIcon(
              onPressed: _busy ? null : _download,
              icon: _busy
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : Icon(_downloaded ? Icons.download_done_rounded : Icons.download_rounded),
              label: Text(_downloaded ? 'دانلود شده' : 'دانلود PDF'),
            ),
            OutlinedButton.icon(
              onPressed: _busy ? null : _open,
              icon: const Icon(Icons.picture_as_pdf_outlined),
              label: const Text('نمایش داخل برنامه'),
            ),
          ]),
        ]),
      ),
    );
  }
}
