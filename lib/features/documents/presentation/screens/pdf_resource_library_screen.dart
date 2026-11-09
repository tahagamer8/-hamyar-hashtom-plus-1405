import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hamyar_hashtom_plus/features/documents/presentation/screens/pdf_viewer_screen.dart';

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
  Future<List<Map<String, dynamic>>>? _resourcesFuture;
  late int _selectedChapterIndex;

  bool get _isNotes => widget.kind == PdfResourceKind.notes;

  String get _resourceKey => _isNotes ? 'notes' : 'samples';

  String get _localAssetPath {
    final number = _selectedChapterIndex + 1;
    final kind = _isNotes ? 'Notes' : 'Questions';
    return 'assets/generated_pdfs/chapters/${widget.subjectId}/'
        'Fahmino-${widget.subjectId}-Chapter-$number-$kind-FA.pdf';
  }

  String get _localTitle => _isNotes
      ? 'جزوهٔ فصل ${_selectedChapterIndex + 1} - فهمینو'
      : 'نمونه‌سؤال فصل ${_selectedChapterIndex + 1} - فهمینو';

  @override
  void initState() {
    super.initState();
    _selectedChapterIndex = widget.initialChapterIndex
        .clamp(0, widget.chapters.isEmpty ? 0 : widget.chapters.length - 1)
        .toInt();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resourcesFuture ??= _loadResources(DefaultAssetBundle.of(context));
  }

  @override
  void didUpdateWidget(covariant PdfResourceLibraryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.subjectId != widget.subjectId ||
        oldWidget.kind != widget.kind) {
      _resourcesFuture = _loadResources(DefaultAssetBundle.of(context));
      _selectedChapterIndex = widget.initialChapterIndex
          .clamp(0, widget.chapters.isEmpty ? 0 : widget.chapters.length - 1);
    }
  }

  Future<List<Map<String, dynamic>>> _loadResources(AssetBundle bundle) async {
    final raw = await bundle.loadString('assets/content/pdf_resources.json');
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('فهرست فایل‌های PDF معتبر نیست.');
    }
    final subjects = decoded['subjects'];
    if (subjects is! Map<String, dynamic>) return const [];
    final subject = subjects[widget.subjectId];
    if (subject is! Map<String, dynamic>) return const [];
    final entries = subject[_resourceKey];
    if (entries is! List) return const [];

    return entries.whereType<Map<String, dynamic>>().where((item) {
      final value = item['url'];
      final uri = value is String ? Uri.tryParse(value) : null;
      return uri != null &&
          uri.scheme == 'https' &&
          uri.host.isNotEmpty &&
          uri.path.toLowerCase().endsWith('.pdf');
    }).toList(growable: false);
  }

  void _openLocalPdf() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PdfViewerScreen.asset(
          title: _localTitle,
          assetPath: _localAssetPath,
        ),
      ),
    );
  }

  void _openExternalPdf(Map<String, dynamic> item) {
    final url = item['url'];
    final uri = url is String ? Uri.tryParse(url) : null;
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        !uri.path.toLowerCase().endsWith('.pdf')) {
      _showMessage('نشانی فایل PDF معتبر نیست.');
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PdfViewerScreen.network(
          title: item['title'] as String? ?? 'فایل PDF',
          uri: uri,
        ),
      ),
    );
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
    final chapterTitle =
        widget.chapters[safeIndex]['title'] as String? ?? 'درس';

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _resourcesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return const Center(child: Text('فهرست فایل‌های PDF بارگذاری نشد.'));
        }

        final externalItems = (snapshot.data ?? const []).where((item) {
          return item['chapterIndex'] == safeIndex ||
              item['chapterIndex'] == -1;
        }).toList(growable: false);

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            Text(
              widget.subjectTitle,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _isNotes
                  ? 'جزوه‌های آموزشی؛ فقط فایل PDF'
                  : 'نمونه‌سؤال‌ها؛ فقط فایل PDF',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
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
            const SizedBox(height: 10),
            Text(
              chapterTitle,
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            _PdfResourceTile(
              title: _localTitle,
              description: _isNotes
                  ? 'مرور نکته‌ها، مثال و آموزش همین فصل؛ قابل مشاهده بدون اینترنت.'
                  : 'سؤال‌های همین فصل همراه با پاسخ‌نامه و توضیح؛ قابل مشاهده بدون اینترنت.',
              source: 'فهمینو · آفلاین',
              onPressed: _openLocalPdf,
              isLocal: true,
            ),
            if (externalItems.isNotEmpty) ...[
              const SizedBox(height: 18),
              Text(
                'فایل‌های تکمیلی از منابع آموزشی',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              for (final item in externalItems)
                _PdfResourceTile(
                  title: item['title'] as String? ?? 'فایل PDF',
                  description:
                      item['description'] as String? ?? 'فایل آموزشی PDF',
                  source: item['source'] as String? ?? 'منبع آموزشی',
                  onPressed: () => _openExternalPdf(item),
                ),
            ],
          ],
        );
      },
    );
  }
}

class _PdfResourceTile extends StatelessWidget {
  const _PdfResourceTile({
    required this.title,
    required this.description,
    required this.source,
    required this.onPressed,
    this.isLocal = false,
  });

  final String title;
  final String description;
  final String source;
  final VoidCallback onPressed;
  final bool isLocal;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 9),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(13),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.picture_as_pdf_rounded,
                  color: theme.colorScheme.primary,
                  size: 23,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
            Text(description, style: theme.textTheme.bodySmall),
            const SizedBox(height: 5),
            Text(
              'منبع: $source',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 9),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: FilledButton.tonalIcon(
                onPressed: onPressed,
                icon: Icon(
                  isLocal ? Icons.offline_pin_rounded : Icons.open_in_new_rounded,
                ),
                label: const Text('مشاهده PDF'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
