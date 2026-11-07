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
      .replaceAll(RegExp(r'[\u064B-\u065F\u0670]'), '')
      .replaceAll(RegExp(r'\s+'), ' ');
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
    _catalogFuture ??= _loadSearchCatalog(DefaultAssetBundle.of(context));
  }

  Future<Map<String, dynamic>> _loadSearchCatalog(AssetBundle bundle) async {
    final raw = await bundle.loadString('assets/content/catalog_fa.json');
    final catalog = jsonDecode(raw) as Map<String, dynamic>;
    // Independently versioned packs are the source of truth when available.
    for (final id in catalog.keys.toList()) {
      try {
        final packRaw = await bundle.loadString('assets/content/subjects/$id.json');
        final value = jsonDecode(packRaw);
        if (value is Map<String, dynamic> &&
            value['subjectId'] == id &&
            value['title'] is String &&
            value['chapters'] is List &&
            (value['chapters'] as List).isNotEmpty) {
          catalog[id] = value;
        }
      } on FlutterError {
        // Keep the legacy catalog for subjects not yet migrated.
      } on FormatException {
        // Ignore malformed optional packs; the catalog remains available.
      } on TypeError {
        // Ignore invalid JSON shape rather than crashing search.
      }
    }
    return catalog;
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
          for (final item in snapshot.data!.entries) {
            final subjectId = item.key;
            final subject = item.value as Map<String, dynamic>;
            final subjectTitle = subject['title'] as String? ?? subjectId;
            final chapters = (subject['chapters'] as List<dynamic>? ?? [])
                .cast<Map<String, dynamic>>();
            for (var chapterIndex = 0; chapterIndex < chapters.length; chapterIndex++) {\n              final chapter = chapters[chapterIndex];
              final chapterTitle = chapter['title'] as String? ?? '';
              final summary = chapter['summary'] as String? ?? '';
              final points = (chapter['points'] as List<dynamic>? ?? []).join(' ');
              final steps = (chapter['solutionSteps'] as List<dynamic>? ?? []).join(' ');
              final example = chapter['example'] as String? ?? '';
              final questions = (chapter['questions'] as List<dynamic>? ?? [])
                  .map((item) => (item as Map<String, dynamic>)['question'] ?? '')
                  .join(' ');
              final searchable = _normalize('$subjectTitle $chapterTitle $summary $points $steps $example $questions');
              if (_query.isEmpty || searchable.contains(_normalize(_query))) {
                entries.add({
                  'subjectId': subjectId,
                  'subjectTitle': subjectTitle,
                  'chapterTitle': chapterTitle,
                  'summary': summary,\n                  'chapterIndex': '$chapterIndex',
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
                child: entries.isEmpty
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
                                '${entry['subjectTitle']}\n${entry['summary']}',
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                              ),
                              isThreeLine: true,
                              trailing: const Icon(Icons.chevron_left_rounded),
                              onTap: () => context.go(
                                AppRoutes.subjectDetail(entry['subjectId']!),
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
