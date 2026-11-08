import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:hamyar_hashtom_plus/core/router/app_routes.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _controller = TextEditingController();
  Future<Map<String, dynamic>>? _catalogFuture;
  String _query = '';
  String _selectedSubjectId = 'all';

  @override
  void initState() {
    super.initState();
    _controller.addListener(_handleQueryChange);
  }

  void _handleQueryChange() {
    if (mounted) {
      setState(() => _query = _controller.text.trim());
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _catalogFuture ??= _loadSearchCatalog(DefaultAssetBundle.of(context));
  }

  Future<Map<String, dynamic>> _loadSearchCatalog(AssetBundle bundle) async {
    final raw = await bundle.loadString('assets/content/catalog_fa.json');
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('ساختار فهرست محتوای فهمینو معتبر نیست.');
    }

    final catalog = Map<String, dynamic>.from(decoded);
    for (final id in catalog.keys.toList()) {
      try {
        final packRaw = await bundle.loadString('assets/content/subjects/$id.json');
        final pack = jsonDecode(packRaw);
        if (pack is Map<String, dynamic> &&
            pack['subjectId'] == id &&
            pack['title'] is String &&
            pack['chapters'] is List &&
            (pack['chapters'] as List).isNotEmpty) {
          catalog[id] = pack;
        }
      } on FlutterError {
        // Keep the legacy catalog entry for older installations.
      } on FormatException {
        // Ignore malformed optional packs and keep the legacy catalog.
      } on TypeError {
        // Ignore a malformed optional pack without breaking search.
      }
    }
    return catalog;
  }

  String _normaliseDigits(String value) {
    const persianDigits = '۰۱۲۳۴۵۶۷۸۹';
    const arabicDigits = '٠١٢٣٤٥٦٧٨٩';
    var result = value;
    for (var index = 0; index < 10; index++) {
      result = result
          .replaceAll(persianDigits[index], '$index')
          .replaceAll(arabicDigits[index], '$index');
    }
    return result;
  }

  String _normalise(String value) {
    var result = _normaliseDigits(value)
        .toLowerCase()
        .replaceAll('ي', 'ی')
        .replaceAll('ك', 'ک')
        .replaceAll('\u200c', ' ')
        .replaceAll('\u0640', '')
        .replaceAll(RegExp(r'[\u064B-\u065F\u0670]'), '');

    for (final punctuation in const [
      '؟', '?', '!', '،', ',', '؛', ';', ':', '(', ')', '[', ']', '{', '}',
      '٫', '٬',
    ]) {
      result = result.replaceAll(punctuation, ' ');
    }
    return result.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  bool _matchesQuery(Map<String, dynamic> chapter, String searchable) {
    final query = _normalise(_query);
    if (query.isEmpty) return true;

    final terms = query.split(' ').where((term) => term.isNotEmpty).toList();
    if (terms.length == 2 && (terms[0] == 'صفحه' || terms[0] == 'ص')) {
      final page = int.tryParse(terms[1]);
      final start = chapter['pageStart'];
      final end = chapter['pageEnd'];
      if (page == null || start is! int) return false;
      return page >= start && page <= (end is int ? end : start);
    }

    final normalizedText = _normalise(searchable);
    // Terms may be in any order, but all must match the same lesson.
    return terms.isNotEmpty &&
        terms.every((term) => normalizedText.contains(term));
  }

  String _pageLabel(Map<String, dynamic> chapter) {
    final start = chapter['pageStart'];
    final end = chapter['pageEnd'];
    if (start is! int) return '';
    if (end is int && end >= start) return 'صفحه $start تا $end';
    return 'از صفحه $start';
  }

  @override
  void dispose() {
    _controller.removeListener(_handleQueryChange);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('جست‌وجو در فهمینو')),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _catalogFuture,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            if (snapshot.hasError) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'بارگذاری جست‌وجو ناموفق بود. محتوای درس‌ها را دوباره بررسی کن.',
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }
            return const Center(child: CircularProgressIndicator());
          }

          final entries = <Map<String, dynamic>>[];
          for (final item in snapshot.data!.entries) {
            final subjectId = item.key;
            if (_selectedSubjectId != 'all' &&
                subjectId != _selectedSubjectId) {
              continue;
            }

            final subject = item.value;
            if (subject is! Map<String, dynamic>) continue;
            final subjectTitle = subject['title'] as String? ?? subjectId;
            final rawChapters = subject['chapters'];
            if (rawChapters is! List) continue;

            for (var index = 0; index < rawChapters.length; index++) {
              final chapter = rawChapters[index];
              if (chapter is! Map<String, dynamic>) continue;

              final questions = (chapter['questions'] as List<dynamic>? ?? [])
                  .whereType<Map<String, dynamic>>()
                  .map((question) => question['question'] ?? '')
                  .join(' ');
              final textbookLessons =
                  (chapter['textbookLessons'] as List<dynamic>? ?? [])
                      .whereType<Map<String, dynamic>>()
                      .map((lesson) => lesson['title'] ?? '')
                      .join(' ');

              final searchable = [
                subjectTitle,
                chapter['title'] ?? '',
                chapter['summary'] ?? '',
                (chapter['points'] as List<dynamic>? ?? []).join(' '),
                (chapter['solutionSteps'] as List<dynamic>? ?? []).join(' '),
                chapter['example'] ?? '',
                questions,
                (chapter['commonMistakes'] as List<dynamic>? ?? [])
                    .whereType<String>()
                    .join(' '),
                chapter['sourceLesson'] ?? '',
                chapter['curriculumInstruction'] ?? '',
                textbookLessons,
              ].join(' ');

              if (_matchesQuery(chapter, searchable)) {
                entries.add({
                  'subjectId': subjectId,
                  'subjectTitle': subjectTitle,
                  'chapterTitle': chapter['title'] as String? ?? 'بخش آموزشی',
                  'summary': chapter['summary'] as String? ?? '',
                  'chapterIndex': index,
                  'pageLabel': _pageLabel(chapter),
                });
              }
            }
          }

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: TextField(
                  controller: _controller,
                  textInputAction: TextInputAction.search,
                  textDirection: TextDirection.rtl,
                  decoration: InputDecoration(
                    hintText: 'نام درس، موضوع، سؤال یا شماره صفحه را بنویس...',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'پاک کردن',
                            onPressed: _controller.clear,
                            icon: const Icon(Icons.close_rounded),
                          ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: DropdownButtonFormField<String>(
                  value: _selectedSubjectId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'فیلتر بر اساس درس',
                    prefixIcon: Icon(Icons.filter_list_rounded),
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: 'all',
                      child: Text('همهٔ درس‌ها'),
                    ),
                    for (final item in snapshot.data!.entries)
                      DropdownMenuItem<String>(
                        value: item.key,
                        child: Text(
                          (item.value as Map<String, dynamic>)['title']
                                  as String? ??
                              item.key,
                        ),
                      ),
                  ],
                  onChanged: (value) => setState(
                    () => _selectedSubjectId = value ?? 'all',
                  ),
                ),
              ),
              Expanded(
                child: entries.isEmpty
                    ? const Center(
                        child: Text(
                          'مطلبی پیدا نشد. عبارت دیگری را امتحان کن.',
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                        itemCount: entries.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final entry = entries[index];
                          final pageLabel = entry['pageLabel'] as String;
                          final subtitle = [
                            entry['subjectTitle'] as String,
                            if (pageLabel.isNotEmpty) pageLabel,
                            entry['summary'] as String,
                          ].where((part) => part.isNotEmpty).join('\n');
                          final subjectId = entry['subjectId'] as String;
                          final chapterIndex = entry['chapterIndex'] as int;
                          return Card(
                            child: ListTile(
                              leading: const CircleAvatar(
                                child: Icon(Icons.menu_book_rounded),
                              ),
                              title: Text(entry['chapterTitle'] as String),
                              subtitle: Text(
                                subtitle,
                                maxLines: 4,
                                overflow: TextOverflow.ellipsis,
                              ),
                              isThreeLine: true,
                              trailing: const Icon(Icons.chevron_left_rounded),
                              onTap: () => context.go(
                                AppRoutes.subjectDetail(subjectId) +
                                    '/lessons?chapter=' +
                                    chapterIndex.toString(),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}
