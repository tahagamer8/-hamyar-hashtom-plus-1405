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
    final matching = AppFeature.values.where(
      (item) => item.name == featureId && item.isSubjectSection,
    );
    if (matching.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('بخش پیدا نشد')),
        body: Center(
          child: FilledButton.icon(
            onPressed: () => context.pop(),
            icon: const Icon(Icons.arrow_back_rounded),
            label: const Text('بازگشت'),
          ),
        ),
      );
    }

    final feature = matching.first;
    final subjects = ref.watch(subjectsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(feature.title)),
      body: subjects.when(
        data: (items) => CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Container(
                margin: const EdgeInsets.fromLTRB(16, 8, 16, 18),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  gradient: LinearGradient(
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                    colors: [
                      feature.color,
                      Color.lerp(feature.color, Colors.black, 0.22)!,
                    ],
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(38),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Icon(feature.icon, color: Colors.white, size: 32),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            feature.title,
                            style: theme.textTheme.titleLarge?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'درس موردنظرت را انتخاب کن',
                            style: TextStyle(color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              sliver: SliverGrid(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final subject = items[index];
                    return SubjectCard(
                      subject: subject,
                      onTap: () => context.push(
                        '/subjects/${subject.id}/${feature.name}',
                      ),
                    );
                  },
                  childCount: items.length,
                ),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 14,
                  crossAxisSpacing: 14,
                  childAspectRatio: 0.88,
                ),
              ),
            ),
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => const Center(
          child: Text('بارگذاری فهرست درس‌ها ناموفق بود.'),
        ),
      ),
    );
  }
}
