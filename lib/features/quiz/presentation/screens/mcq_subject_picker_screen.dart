import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hamyar_hashtom_plus/core/router/app_routes.dart';
import 'package:hamyar_hashtom_plus/features/quiz/domain/mcq_level.dart';
import 'package:hamyar_hashtom_plus/features/quiz/domain/subject_pack.dart';
import 'package:hamyar_hashtom_plus/features/quiz/presentation/providers/quiz_providers.dart';
import 'package:hamyar_hashtom_plus/features/quiz/presentation/widgets/quiz_status_views.dart';

/// Second step of the MCQ flow: choose the subject for the selected level.
class McqSubjectPickerScreen extends ConsumerWidget {
  const McqSubjectPickerScreen({super.key, required this.levelId});

  final String levelId;

  static Key subjectKey(String subjectId) => ValueKey('mcq-subject-$subjectId');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final level = McqLevel.fromId(levelId);
    if (level == null || !level.hasQuestionSource) {
      return const QuizMessageScaffold(
        title: 'سطح آزمون',
        message: 'این سطح وجود ندارد یا هنوز پرسشی برای آن ثبت نشده است.',
      );
    }
    final packs = ref.watch(subjectPacksProvider);
    return Scaffold(
      appBar: AppBar(title: Text('سطح ${level.title}')),
      body: packs.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => QuizErrorView(
          onRetry: () => ref.invalidate(subjectPacksProvider),
        ),
        data: (list) {
          if (list.isEmpty) {
            return const Center(child: Text('هنوز درسی بارگذاری نشده است.'));
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              Text(
                'درس موردنظر را انتخاب کن. هر تمرین حداکثر ۱۰ سؤال دارد.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 12),
              for (final pack in list) _SubjectTile(level: level, pack: pack),
            ],
          );
        },
      ),
    );
  }
}

class _SubjectTile extends ConsumerWidget {
  const _SubjectTile({required this.level, required this.pack});

  final McqLevel level;
  final SubjectPack pack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final count = pack.countFor(level);
    final key = (level: level, subjectId: pack.id);
    final last = ref.watch(mcqHistoryProvider(key)).valueOrNull?.firstOrNull;
    final enabled = count > 0;
    final subtitle = !enabled
        ? 'بدون سؤال برای این سطح'
        : '$count سؤال${last == null ? '' : ' • آخرین نتیجه: ${last.percent}٪'}';
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          key: McqSubjectPickerScreen.subjectKey(pack.id),
          enabled: enabled,
          onTap: enabled
              ? () async {
                  await context.push<void>(
                    AppRoutes.mcqPractice(level.id, pack.id),
                  );
                  if (context.mounted) {
                    ref.invalidate(mcqHistoryProvider(key));
                  }
                }
              : null,
          leading: Opacity(
            opacity: enabled ? 1 : 0.6,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: colors.secondaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.menu_book_rounded,
                color: colors.onSecondaryContainer,
                size: 22,
              ),
            ),
          ),
          title: Text(
            pack.title,
            style: theme.textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          subtitle: Text(subtitle),
          trailing: Icon(
            enabled
                ? Icons.arrow_back_ios_new_rounded
                : Icons.lock_outline_rounded,
            size: enabled ? 14 : 18,
            color: enabled ? null : colors.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
