import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hamyar_hashtom_plus/core/router/app_routes.dart';
import 'package:hamyar_hashtom_plus/features/favorites/presentation/providers/favorites_provider.dart';

class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favorites = ref.watch(favoritesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('علاقه‌مندی‌ها')),
      body: FutureBuilder<String>(
        future: DefaultAssetBundle.of(context).loadString('assets/content/catalog_fa.json'),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('بارگذاری علاقه‌مندی‌ها ناموفق بود.'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final catalog = jsonDecode(snapshot.data!) as Map<String, dynamic>;
          final entries = <({String subjectId, String subjectTitle, String title})>[];
          for (final key in favorites) {
            final parts = key.split('::');
            if (parts.length != 2) continue;
            final subject = catalog[parts.first] as Map<String, dynamic>?;
            if (subject == null) continue;
            final chapters = subject['chapters'] as List<dynamic>? ?? [];
            final exists = chapters.any((item) => (item as Map<String, dynamic>)['title'] == parts.last);
            if (exists) {
              entries.add((subjectId: parts.first, subjectTitle: subject['title'] as String, title: parts.last));
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
                    Text('در صفحه آموزش هر فصل، روی نشانک بزن تا اینجا ذخیره شود.',
                        textAlign: TextAlign.center),
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
                  leading: const Icon(Icons.bookmark_rounded),
                  title: Text(entry.title),
                  subtitle: Text(entry.subjectTitle),
                  onTap: () => context.go(AppRoutes.subjectDetail(entry.subjectId)),
                  trailing: IconButton(
                    tooltip: 'حذف از علاقه‌مندی‌ها',
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => ref.read(favoritesProvider.notifier).toggle('${entry.subjectId}::${entry.title}'),
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
