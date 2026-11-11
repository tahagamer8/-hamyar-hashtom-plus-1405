import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hamyar_hashtom_plus/core/router/app_routes.dart';
import 'package:hamyar_hashtom_plus/features/favorites/presentation/providers/favorites_provider.dart';

class FavoritesScreen extends ConsumerStatefulWidget {
  const FavoritesScreen({super.key});

  @override
  ConsumerState<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends ConsumerState<FavoritesScreen> {
  Future<Map<String, dynamic>>? _catalogFuture;
  Map<String, dynamic> _legacyCatalog = {};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _catalogFuture ??= _loadCatalog(DefaultAssetBundle.of(context));
  }

  Future<Map<String, dynamic>> _loadCatalog(AssetBundle bundle) async {
    final raw = await bundle.loadString('assets/content/catalog_fa.json');
    final catalog = jsonDecode(raw) as Map<String, dynamic>;
    _legacyCatalog = Map<String, dynamic>.from(catalog);

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
        // Keep the legacy catalog entry for older subject packs.
      } on FormatException {
        // Keep the legacy catalog entry when an optional pack is malformed.
      } on TypeError {
        // Ignore invalid pack shapes and keep the legacy entry.
      }
    }
    return catalog;
  }

  @override
  Widget build(BuildContext context) {
    final favorites = ref.watch(favoritesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('علاقه‌مندی‌ها')),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _catalogFuture,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('بارگذاری علاقه‌مندی‌ها ناموفق بود.'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final catalog = snapshot.data!;
          final entries = <
              ({
                String subjectId,
                String subjectTitle,
                String title,
                String destination,
                String favoriteKey,
                bool isPdf,
              })>[];

          for (final key in favorites) {
            final parts = key.split('::');

            // New document favorites: pdf::<subjectId>::<notes|questions>.
            if (parts.length == 3 && parts[0] == 'pdf') {
              final subjectId = parts[1];
              final kind = parts[2];
              const titles = {
                'notes': 'جزوه PDF',
                'questions': 'نمونه‌سؤال فصل‌به‌فصل PDF',
                'firstTerm': 'آزمون نوبت اول PDF',
                'secondTerm': 'آزمون نوبت دوم PDF',
                'gifted': 'پرسش‌های استدلالی سمپاد PDF',
              };
              final title = titles[kind];
              if (title == null) continue;
              final subject = catalog[subjectId] as Map<String, dynamic>?;
              if (subject == null) continue;
              final featureId = kind == 'notes' ? 'notes' : 'sampleExams';
              entries.add((
                subjectId: subjectId,
                subjectTitle: subject['title'] as String? ?? subjectId,
                title: title,
                destination: '${AppRoutes.subjectDetail(subjectId)}/$featureId',
                favoriteKey: key,
                isPdf: true,
              ));
              continue;
            }

            // Existing chapter favorites keep their original key format.
            if (parts.length != 2) continue;
            final subjectId = parts.first;
            final title = parts.last;
            final subject = catalog[subjectId] as Map<String, dynamic>?;
            if (subject == null) continue;
            final chapters = subject['chapters'] as List<dynamic>? ?? [];
            final index = chapters.indexWhere(
              (item) => item is Map<String, dynamic> && item['title'] == title,
            );
            if (index >= 0) {
              entries.add((
                subjectId: subjectId,
                subjectTitle: subject['title'] as String? ?? subjectId,
                title: title,
                destination:
                    '${AppRoutes.subjectDetail(subjectId)}/lessons?chapter=$index',
                favoriteKey: key,
                isPdf: false,
              ));
              continue;
            }

            final legacy = _legacyCatalog[subjectId] as Map<String, dynamic>?;
            final legacyChapters = legacy?['chapters'] as List<dynamic>? ?? [];
            if (legacyChapters.any((item) =>
                item is Map<String, dynamic> && item['title'] == title)) {
              entries.add((
                subjectId: subjectId,
                subjectTitle: subject['title'] as String? ?? subjectId,
                title: title,
                destination: AppRoutes.subjectDetail(subjectId),
                favoriteKey: key,
                isPdf: false,
              ));
            }
          }

          if (entries.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.bookmark_border_rounded, size: 52),
                    SizedBox(height: 12),
                    Text('هنوز مطلبی نشان نکرده‌ای.'),
                    SizedBox(height: 6),
                    Text(
                      'در صفحهٔ هر فصل یا کنار PDF جزوه و نمونه‌سؤال، روی نشانک بزن تا اینجا ذخیره شود.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: entries.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final entry = entries[index];
              return Card(
                child: ListTile(
                  leading: Icon(
                    entry.isPdf
                        ? Icons.picture_as_pdf_rounded
                        : Icons.bookmark_rounded,
                  ),
                  title: Text(entry.title),
                  subtitle: Text(entry.subjectTitle),
                  onTap: () => context.go(entry.destination),
                  trailing: IconButton(
                    tooltip: 'حذف از علاقه‌مندی‌ها',
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => ref
                        .read(favoritesProvider.notifier)
                        .toggle(entry.favoriteKey),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
