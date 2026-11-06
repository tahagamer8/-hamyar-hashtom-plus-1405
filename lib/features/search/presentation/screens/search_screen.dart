import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hamyar_hashtom_plus/core/router/app_routes.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  String _normalize(String value) => value
      .toLowerCase()
      .replaceAll('ي', 'ی')
      .replaceAll('ك', 'ک')
      .replaceAll('ۀ', 'ه')
      .replaceAll('ة', 'ه')
      .replaceAll(RegExp(r'[\u064B-\u065F\u0670]'), '')
      .replaceAll(RegExp(r'[\u200c\u200f\u200e]'), ' ')
      .replaceAll(RegExp(r'[،؛؟!,:;.]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  final _controller = TextEditingController();
  Future<Map<String, dynamic>>? _catalogFuture;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      if (mounted) setState(() => _query = _controller.text.trim());
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _catalogFuture ??= DefaultAssetBundle.of(context)
        .loadString('assets/content/catalog_fa.json')
        .then((raw) => jsonDecode(raw) as Map<String, dynamic>);
  }

  @override
  void dispose() {
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
              return const Center(child: Text('بارگذاری جست‌وجو ناموفق بود.'));
            }
            return const Center(child: CircularProgressIndicator());
          }
          final entries = <Map<String, String>>[];
          final query = _normalize(_query);
          if (query.isNotEmpty) {
            for (final item in snapshot.data!.entries) {
              final subjectId = item.key;
              final subject = item.value as Map<String, dynamic>;
              final subjectTitle = subject['title'] as String? ?? subjectId;
              final chapters = (subject['chapters'] as List<dynamic>? ?? [])
                  .whereType<Map<String, dynamic>>()
                  .toList();

              for (var chapterIndex = 0; chapterIndex < chapters.length; chapterIndex++) {
                final chapter = chapters[chapterIndex];
                final chapterTitle = chapter['title'] as String? ?? '';
                final summary = chapter['summary'] as String? ?? '';
                final points = (chapter['points'] as List<dynamic>? ?? [])
                    .whereType<String>()
                    .toList();
                final steps = (chapter['solutionSteps'] as List<dynamic>? ?? [])
                    .whereType<String>()
                    .toList();
                final example = chapter['example'] as String? ?? '';
                final questions = (chapter['questions'] as List<dynamic>? ?? [])
                    .whereType<Map<String, dynamic>>()
                    .toList();

                final learningSections =
                    (chapter['learningSections'] as List<dynamic>? ?? [])
                        .whereType<Map<String, dynamic>>()
                        .toList();
                final sectionFields = <MapEntry<String, String>>[];
                for (final section in learningSections) {
                  sectionFields.add(MapEntry(
                    'بخش درسنامه',
                    section['title'] as String? ?? '',
                  ));
                  sectionFields.add(MapEntry(
                    'متن درسنامه',
                    section['content'] as String? ?? '',
                  ));
                  sectionFields.addAll(
                    (section['keyPoints'] as List<dynamic>? ?? [])
                        .whereType<String>()
                        .map((value) => MapEntry('نکتهٔ درسنامه', value)),
                  );
                  sectionFields.addAll(
                    (section['examples'] as List<dynamic>? ?? [])
                        .whereType<String>()
                        .map((value) => MapEntry('مثال درسنامه', value)),
                  );
                }
                final fields = <MapEntry<String, String>>[
                  MapEntry('نام درس', subjectTitle),
                  MapEntry('عنوان فصل', chapterTitle),
                  MapEntry('درسنامه', summary),
                  ...sectionFields,
                  ...points.map((value) => MapEntry('نکتهٔ آموزشی', value)),
                  ...steps.map((value) => MapEntry('حل مثال', value)),
                  MapEntry('مثال', example),
                  ...questions.map((value) => MapEntry(
                        'نمونه‌سؤال',
                        value['question'] as String? ?? '',
                      )),
                ];
                final matched = fields.where((field) =>
                    _normalize(field.value).contains(query)).toList();
                if (matched.isEmpty) continue;

                final bestMatch = matched.firstWhere(
                  (field) => field.key != 'نام درس' && field.key != 'عنوان فصل',
                  orElse: () => matched.first,
                );
                entries.add({
                  'subjectId': subjectId,
                  'subjectTitle': subjectTitle,
                  'chapterTitle': chapterTitle,
                  'chapterIndex': chapterIndex.toString(),
                  'summary': summary,
                  'matchType': bestMatch.key,
                  'matchedText': bestMatch.value,
                });
              }
            }
          }
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: TextField(
                  controller: _controller,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: 'نام درس یا موضوع را بنویس...',
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
              Expanded(
                child: _query.isEmpty
                    ? const Center(child: Text('نام درس، عنوان فصل یا بخشی از سؤال را جست‌وجو کن.'))
                    : entries.isEmpty
                        ? const Center(child: Text('مطلبی پیدا نشد. عبارت دیگری را امتحان کن.'))
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                        itemCount: entries.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final entry = entries[index];
                          return Card(
                            child: ListTile(
                              leading: const CircleAvatar(
                                child: Icon(Icons.menu_book_rounded),
                              ),
                              title: Text(entry['chapterTitle']!),
                              subtitle: Text(
                                '${entry['subjectTitle']} • ${entry['matchType']}\n${entry['matchedText']}',
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                              ),
                              isThreeLine: true,
                              trailing: const Icon(Icons.chevron_left_rounded),
                              onTap: () => context.go(
                                '${AppRoutes.subjectDetail(entry['subjectId']!)}/lessons'
                                '?chapter=${entry['chapterIndex']}',
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
