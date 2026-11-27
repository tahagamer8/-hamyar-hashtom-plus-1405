import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hamyar_hashtom_plus/core/router/app_routes.dart';
import 'package:hamyar_hashtom_plus/features/quiz/domain/subject_pack.dart';
import 'package:hamyar_hashtom_plus/features/quiz/presentation/providers/quiz_providers.dart';
import 'package:hamyar_hashtom_plus/features/quiz/presentation/screens/interactive_exam_screen.dart';
import 'package:hamyar_hashtom_plus/features/quiz/presentation/widgets/quiz_status_views.dart';

/// Hub of the Interactive Exams section: timed exams per subject plus one
/// mixed exam. A subject without real questions is listed but disabled.
class InteractiveExamsHomeScreen extends ConsumerWidget {
  const InteractiveExamsHomeScreen({super.key});

  static Key examKey(String examId) => ValueKey('interactive-exam-$examId');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final packs = ref.watch(subjectPacksProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('آزمون‌های تعاملی')),
      body: packs.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => QuizErrorView(
          onRetry: () => ref.invalidate(subjectPacksProvider),
        ),
        data: (list) => _content(context, list),
      ),
    );
  }

  Widget _content(BuildContext context, List<SubjectPack> list) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final counts = {for (final pack in list) pack.id: pack.examQuestions.length};
    final total = counts.values.fold<int>(0, (sum, value) => sum + value);
    if (list.isEmpty || total == 0) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'هنوز سؤالی برای آزمون ثبت نشده است.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    final mixedQuestions =
        total < mixedExamQuestionLimit ? total : mixedExamQuestionLimit;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Text(
          'آزمون زمان‌دار با کارنامه و پاسخ‌نامه. زمان از دکمهٔ شروع آغاز می‌شود و با پایان زمان، پاسخ‌های ثبت‌شده تصحیح می‌شوند.',
          style: theme.textTheme.bodyMedium
              ?.copyWith(color: colors.onSurfaceVariant),
        ),
        const SizedBox(height: 12),
        _ExamTile(
          tileKey: examKey(mixedExamId),
          icon: Icons.shuffle_rounded,
          title: 'آزمون ترکیبی همه دروس',
          subtitle:
              '$mixedQuestions سؤال • ${examMinutes(total, mixedExamQuestionLimit)} دقیقه',
          enabled: true,
          examId: mixedExamId,
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Text('آزمون هر درس', style: theme.textTheme.titleSmall),
        ),
        for (final pack in list)
          _ExamTile(
            tileKey: examKey(pack.id),
            icon: Icons.menu_book_rounded,
            title: pack.title,
            subtitle: counts[pack.id]! > 0
                ? '${counts[pack.id]! < subjectExamQuestionLimit ? counts[pack.id] : subjectExamQuestionLimit} سؤال • ${examMinutes(counts[pack.id]!, subjectExamQuestionLimit)} دقیقه'
                : 'هنوز سؤالی ثبت نشده است',
            enabled: counts[pack.id]! > 0,
            examId: pack.id,
          ),
      ],
    );
  }
}

class _ExamTile extends StatelessWidget {
  const _ExamTile({
    required this.tileKey,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.enabled,
    required this.examId,
  });

  final Key tileKey;
  final IconData icon;
  final String title;
  final String subtitle;
  final bool enabled;
  final String examId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          key: tileKey,
          enabled: enabled,
          onTap:
              enabled ? () => context.push(AppRoutes.interactiveExam(examId)) : null,
          leading: Opacity(
            opacity: enabled ? 1 : 0.6,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: colors.secondaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: colors.onSecondaryContainer, size: 22),
            ),
          ),
          title: Text(
            title,
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
