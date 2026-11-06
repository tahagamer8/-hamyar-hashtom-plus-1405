import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hamyar_hashtom_plus/core/constants/app_feature.dart';
import 'package:hamyar_hashtom_plus/features/subjects/presentation/providers/subjects_providers.dart';
import 'package:hamyar_hashtom_plus/features/subjects/presentation/widgets/subject_card.dart';

class FeatureSubjectsScreen extends ConsumerWidget {
  const FeatureSubjectsScreen({super.key, required this.featureId});

  final String featureId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feature = AppFeature.values.firstWhere(
      (item) => item.name == featureId && item != AppFeature.favorites,
      orElse: () => AppFeature.lessons,
    );
    final subjects = ref.watch(subjectsProvider);
    return Scaffold(
      appBar: AppBar(title: Text(feature.title)),
      body: subjects.when(
        data: (items) => GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 0.95,
          ),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final subject = items[index];
            return SubjectCard(
              subject: subject,
              onTap: () => context.push(
                '/subjects/${subject.id}/${feature.name}',
              ),
            );
          },
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => const Center(
          child: Text('بارگذاری فهرست درس‌ها ناموفق بود.'),
        ),
      ),
    );
  }
}
