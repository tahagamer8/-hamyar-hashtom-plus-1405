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
  final _controller = TextEditingController();
  late final Future<Map<String, dynamic>> _catalogFuture;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _catalogFuture = rootBundle.loadString('assets/content/catalog_fa.json')
        .then((raw) => jsonDecode(raw) as Map<String, dynamic>);
    _controller.addListener(() {
      if (mounted) setState(() => _query = _controller.text.trim());
    });
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
            for (final chapter in chapters) {
              final chapterTitle = chapter['title'] as String? ?? '';
              final summary = chapter['summary'] as String? ?? '';
              final searchable = '$subjectTitle $chapterTitle $summary'
                  .toLowerCase();
              if (_query.isEmpty || searchable.contains(_query.toLowerCase())) {
                entries.add({
                  'subjectId': subjectId,
                  'subjectTitle': subjectTitle,
                  'chapterTitle': chapterTitle,
                  'summary': summary,
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
