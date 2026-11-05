import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hamyar_hashtom_plus/core/constants/app_feature.dart';
import 'package:hamyar_hashtom_plus/core/theme/app_colors.dart';
import 'package:hamyar_hashtom_plus/features/subjects/domain/entities/subject.dart';
import 'package:hamyar_hashtom_plus/features/subjects/presentation/providers/subjects_providers.dart';
import 'package:hamyar_hashtom_plus/features/subjects/presentation/utils/subject_style.dart';

class SubjectDetailScreen extends ConsumerWidget {
  const SubjectDetailScreen({super.key, required this.subjectId});

  final String subjectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subjectAsync = ref.watch(subjectProvider(subjectId));
    return Scaffold(
      appBar: AppBar(title: Text(subjectAsync.value?.title ?? 'درس')),
      body: subjectAsync.when(
        data: (subject) => subject == null
            ? const Center(child: Text('درس موردنظر پیدا نشد'))
            : _SubjectBody(subject: subject),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) =>
            const Center(child: Text('خطا در بارگذاری درس')),
      ),
    );
  }
}

class _SubjectBody extends StatelessWidget {
  const _SubjectBody({required this.subject});
  final Subject subject;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = styleForSubject(subject.id);
    final sections =
        AppFeature.values.where((feature) => feature.isSubjectSection);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: [style.color, style.color.withAlpha(180)],
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(50),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(style.icon, color: Colors.white, size: 32),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(subject.title,
                        style: theme.textTheme.titleLarge
                            ?.copyWith(color: Colors.white)),
                    Text(subject.description,
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(color: Colors.white.withAlpha(220))),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Text('محتوای درس', style: theme.textTheme.titleMedium),
        const SizedBox(height: 12),
        for (final feature in sections)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _SectionTile(feature: feature, subjectId: subject.id),
          ),
      ],
    );
  }
}

class _SectionTile extends StatelessWidget {
  const _SectionTile({required this.feature, required this.subjectId});
  final AppFeature feature;
  final String subjectId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final radius = BorderRadius.circular(18);
    return Material(
      color: AppColors.card(context),
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(color: theme.colorScheme.outlineVariant.withAlpha(90)),
      ),
      child: InkWell(
        borderRadius: radius,
        onTap: () => context.push('/subjects/$subjectId/${feature.name}'),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: feature.color.withAlpha(30),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(feature.icon, color: feature.color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(feature.title,
                  style: theme.textTheme.titleSmall)),
              Icon(Icons.chevron_left_rounded,
                  color: theme.colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
