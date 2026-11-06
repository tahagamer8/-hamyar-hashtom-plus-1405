import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

class LearningPdfsCard extends StatefulWidget {
  const LearningPdfsCard({super.key});

  @override
  State<LearningPdfsCard> createState() => _LearningPdfsCardState();
}

class _LearningPdfsCardState extends State<LearningPdfsCard> {
  String? _opening;

  Future<void> _openPdf(String fileName, String label) async {
    if (_opening != null) return;
    setState(() => _opening = fileName);
    try {
      final data = await rootBundle.load('assets/generated_pdfs/$fileName');
      final directory = await getApplicationSupportDirectory();
      final file = File('${directory.path}/$fileName');
      await file.writeAsBytes(data.buffer.asUint8List(), flush: true);
      final result = await OpenFilex.open(file.path, type: 'application/pdf');
      if (!mounted) return;
      if (result.type != ResultType.done) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('باز کردن فایل ممکن نشد: ${result.message}')),
        );
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فایل $label آمادهٔ باز شدن نیست. دوباره نسخهٔ برنامه را بررسی کن.')),
      );
    } finally {
      if (mounted) setState(() => _opening = null);
    }
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
            Row(children: [
              Icon(Icons.picture_as_pdf_rounded, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text('جزوه و نمونه‌سؤال PDF', style: theme.textTheme.titleMedium),
            ]),
            const SizedBox(height: 6),
            Text('فایل‌ها داخل برنامه قرار دارند و برای باز شدن به نمایشگر PDF نیاز است.',
                style: theme.textTheme.bodySmall),
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8, children: [
              OutlinedButton.icon(
                onPressed: _opening == null ? () => _openPdf('Fahmino-Grade8-Notes-FA.pdf', 'جزوه') : null,
                icon: _opening == 'Fahmino-Grade8-Notes-FA.pdf'
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.menu_book_rounded),
                label: const Text('باز کردن جزوه'),
              ),
              OutlinedButton.icon(
                onPressed: _opening == null ? () => _openPdf('Fahmino-Grade8-Sample-Questions-FA.pdf', 'نمونه‌سؤال') : null,
                icon: _opening == 'Fahmino-Grade8-Sample-Questions-FA.pdf'
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.assignment_rounded),
                label: const Text('باز کردن نمونه‌سؤال'),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}
