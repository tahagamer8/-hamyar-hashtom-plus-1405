import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:hamyar_hashtom_plus/features/documents/presentation/screens/pdf_reader_screen.dart';

class LearningPdfsCard extends StatefulWidget {
  const LearningPdfsCard({super.key});

  @override
  State<LearningPdfsCard> createState() => _LearningPdfsCardState();
}

class _LearningPdfsCardState extends State<LearningPdfsCard> {
  String? _downloading;

  Future<File> _copyAssetTo(String fileName, Directory directory) async {
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    final target = File('${directory.path}/$fileName');
    if (!await target.exists() || await target.length() == 0) {
      final data = await rootBundle.load('assets/generated_pdfs/$fileName');
      await target.writeAsBytes(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        flush: true,
      );
    }
    return target;
  }

  Future<void> _openPdf(String fileName, String label) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => PdfReaderScreen(
        assetPath: 'assets/generated_pdfs/' + fileName,
        title: label,
      ),
    ));
  }

  Future<void> _downloadPdf(String fileName, String label) async {
    if (_downloading != null) return;
    setState(() => _downloading = fileName);
    try {
      final root = await getApplicationDocumentsDirectory();
      final directory = Directory('${root.path}/Fahmino-PDFs');
      final file = await _copyAssetTo(fileName, directory);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('PDF $label ذخیره شد: ${file.path}')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('دانلود PDF $label انجام نشد؛ فایل در این نسخه موجود نیست.')),
      );
    } finally {
      if (mounted) setState(() => _downloading = null);
    }
  }

  Widget _pdfActions({
    required String fileName,
    required String label,
    required IconData icon,
  }) {
    final downloading = _downloading == fileName;
    final busy = _downloading != null;
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: busy
                ? null
                : () => _openPdf(fileName, label),
            icon: Icon(icon),
            label: const Text('نمایش داخل برنامه'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: FilledButton.tonalIcon(
            onPressed: busy ? null : () => _downloadPdf(fileName, label),
            icon: downloading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.download_rounded),
            label: const Text('دانلود PDF'),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.picture_as_pdf_rounded, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text('مرکز فایل‌های PDF پایه هشتم', style: theme.textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'جزوه، بانک پرسش‌ها، آزمون‌های دو نوبت و پرسش‌های استدلالی؛ همه داخل برنامه و بدون اینترنت.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            _pdfActions(
              fileName: 'Fahmino-Grade8-Notes-FA.pdf',
              label: 'جزوهٔ همهٔ درس‌ها',
              icon: Icons.menu_book_rounded,
            ),
            const SizedBox(height: 8),
            _pdfActions(
              fileName: 'Fahmino-Grade8-Sample-Questions-FA.pdf',
              label: 'بانک پرسش فصل‌به‌فصل',
              icon: Icons.assignment_rounded,
            ),
            const SizedBox(height: 8),
            _pdfActions(
              fileName: 'Fahmino-Grade8-First-Term-Exam-FA.pdf',
              label: 'آزمون‌های نوبت اول',
              icon: Icons.looks_one_rounded,
            ),
            const SizedBox(height: 8),
            _pdfActions(
              fileName: 'Fahmino-Grade8-Second-Term-Exam-FA.pdf',
              label: 'آزمون‌های نوبت دوم',
              icon: Icons.looks_two_rounded,
            ),
            const SizedBox(height: 8),
            _pdfActions(
              fileName: 'Fahmino-Grade8-Gifted-Questions-FA.pdf',
              label: 'پرسش‌های استدلالی آمادگی سمپاد',
              icon: Icons.psychology_alt_rounded,
            ),
          ],
        ),
      ),
    );
  }
}
