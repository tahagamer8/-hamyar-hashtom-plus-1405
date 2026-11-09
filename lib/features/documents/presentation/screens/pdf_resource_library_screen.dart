import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

enum PdfResourceKind { notes, samples }

class PdfResourceLibraryScreen extends StatefulWidget {
  const PdfResourceLibraryScreen({
    super.key,
    required this.subjectId,
    required this.subjectTitle,
    required this.chapters,
    required this.kind,
    this.initialChapterIndex = 0,
  });

  final String subjectId;
  final String subjectTitle;
  final List<Map<String, dynamic>> chapters;
  final PdfResourceKind kind;
  final int initialChapterIndex;

  @override
  State<PdfResourceLibraryScreen> createState() =>
      _PdfResourceLibraryScreenState();
}

class _PdfResourceLibraryScreenState extends State<PdfResourceLibraryScreen> {
  late Future<Map<String, dynamic>> _resourcesFuture;
  late int _selectedChapterIndex;

  String get _resourceKey =>
      widget.kind == PdfResourceKind.notes ? 'notes' : 'samples';

  String get _emptyMessage => widget.kind == PdfResourceKind.notes
      ? 'برای این فصل هنوز فایل جزوهٔ PDF تأییدشده‌ای ثبت نشده است.'
      : 'برای این فصل هنوز فایل نمونه‌سؤال PDF تأییدشده‌ای ثبت نشده است.';

  @override
  void initState() {
    super.initState();
    _selectedChapterIndex = widget.initialChapterIndex;
    _resourcesFuture = _loadResources();
  }

  @override
  void didUpdateWidget(covariant PdfResourceLibraryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.subjectId != widget.subjectId ||
        oldWidget.kind != widget.kind) {
      _resourcesFuture = _loadResources();
      _selectedChapterIndex = widget.initialChapterIndex;
    }
  }

  Future<Map<String, dynamic>> _loadResources() async {
    final raw = await rootBundle.loadString('assets/content/pdf_resources.json');
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('فهرست فایل‌های PDF معتبر نیست.');
    }
    final subjects = decoded['subjects'];
    if (subjects is! Map<String, dynamic>) return const {};
    final subject = subjects[widget.subjectId];
    if (subject is! Map<String, dynamic>) return const {};
    final entries = subject[_resourceKey];
    if (entries is! List) return const {};
    return {
      'items': entries.whereType<Map<String, dynamic>>().where((item) {
        final url = item['url'];
        return url is String &&
            Uri.tryParse(url)?.scheme == 'https' &&
            url.toLowerCase().contains('.pdf');
      }).toList(growable: false),
    };
  }

  Future<void> _openPdf(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null || uri.scheme != 'https' || !url.toLowerCase().contains('.pdf')) {
      _showMessage('نشانی فایل PDF معتبر نیست.');
      return;
    }
    try {
      final opened = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!opened) _showMessage('باز کردن فایل PDF ممکن نشد.');
    } catch (_) {
      _showMessage('ارتباط با فایل PDF برقرار نشد؛ اتصال اینترنت را بررسی کن.');
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (widget.chapters.isEmpty) {
      return const Center(child: Text('فهرست درس‌های این کتاب در دسترس نیست.'));
    }

    final safeIndex = _selectedChapterIndex
        .clamp(0, widget.chapters.length - 1)
        .toInt();

    return FutureBuilder<Map<String, dynamic>>(
      future: _resourcesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return const Center(child: Text('فهرست فایل‌های PDF بارگذاری نشد.'));
        }

        final allItems =
            (snapshot.data?['items'] as List<dynamic>? ?? const []);
        final items = allItems.where((item) {
          return item is Map<String, dynamic> &&
              item['chapterIndex'] == safeIndex;
        }).cast<Map<String, dynamic>>().toList(growable: false);

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            Text(
              widget.subjectTitle,
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 5),
            Text(
              widget.kind == PdfResourceKind.notes
                  ? 'جزوه‌های آموزشی فقط به‌صورت فایل PDF'
                  : 'نمونه‌سؤال‌ها فقط به‌صورت فایل PDF',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 18),
            DropdownButtonFormField<int>(
              value: safeIndex,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'انتخاب فصل یا درس',
                prefixIcon: Icon(Icons.menu_book_rounded),
                border: OutlineInputBorder(),
              ),
              items: [
                for (var index = 0; index < widget.chapters.length; index++)
                  DropdownMenuItem<int>(
                    value: index,
                    child: Text(
                      '${index + 1}. ${widget.chapters[index]['title'] as String? ?? 'درس'}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() => _selectedChapterIndex = value);
                }
              },
            ),
            const SizedBox(height: 16),
            if (items.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.picture_as_pdf_outlined,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _emptyMessage,
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              for (final item in items)
                Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.picture_as_pdf_rounded,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(width: 9),
                            Expanded(
                              child: Text(
                                item['title'] as String? ?? 'فایل PDF',
                                style: theme.textTheme.titleSmall,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        Text(
                          item['description'] as String? ?? 'فایل آموزشی PDF',
                          style: theme.textTheme.bodySmall,
                        ),
                        if (item['source'] is String) ...[
                          const SizedBox(height: 5),
                          Text(
                            'منبع: ${item['source']}',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                        const SizedBox(height: 10),
                        Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: FilledButton.tonalIcon(
                            onPressed: () => _openPdf(item['url'] as String),
                            icon: const Icon(Icons.open_in_new_rounded),
                            label: const Text('باز کردن فایل PDF'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
          ],
        );
      },
    );
  }
}
