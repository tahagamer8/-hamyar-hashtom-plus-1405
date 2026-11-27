import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hamyar_hashtom_plus/features/quiz/domain/subject_pack.dart';
import 'package:hamyar_hashtom_plus/features/quiz/presentation/providers/quiz_providers.dart';
import 'package:hamyar_hashtom_plus/features/quiz/presentation/screens/timed_combined_exam_screen.dart';
import 'package:hamyar_hashtom_plus/features/quiz/presentation/widgets/quiz_status_views.dart';

/// Route id of the exam that mixes every subject.
const String mixedExamId = 'mixed';

/// Question limits shared with the hub so its summaries match the exam.
const int subjectExamQuestionLimit = 20;
const int mixedExamQuestionLimit = 30;

/// Exam length in minutes for [questionCount] questions, matching the timer
/// of TimedCombinedExamScreen (one minute per question, at least ten).
int examMinutes(int questionCount, int limit) {
  final questions = questionCount < limit ? questionCount : limit;
  return questions < 10 ? 10 : questions;
}

/// Opens the existing timed exam for one subject or for every subject.
class InteractiveExamScreen extends ConsumerWidget {
  const InteractiveExamScreen({super.key, required this.examId});

  final String examId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final packs = ref.watch(subjectPacksProvider);
    return packs.when(
      loading: () => const QuizLoadingScaffold(title: 'آزمون تعاملی'),
      error: (error, stack) => Scaffold(
        appBar: AppBar(title: const Text('آزمون تعاملی')),
        body: QuizErrorView(
          onRetry: () => ref.invalidate(subjectPacksProvider),
        ),
      ),
      data: (list) {
        if (examId == mixedExamId) {
          final chapters = <Map<String, dynamic>>[];
          for (final pack in list) {
            for (final chapter in pack.chapters) {
              final title = chapter['title'];
              chapters.add({
                ...chapter,
                'title': '${pack.title} — ${title is String ? title : 'درس'}',
              });
            }
          }
          // Shuffled so a limited exam samples chapters from every subject.
          chapters.shuffle();
          return TimedCombinedExamScreen(
            subjectTitle: 'همه دروس',
            examTitle: 'آزمون ترکیبی',
            chapters: chapters,
            questionLimit: mixedExamQuestionLimit,
          );
        }
        SubjectPack? pack;
        for (final item in list) {
          if (item.id == examId) {
            pack = item;
          }
        }
        if (pack == null) {
          return const QuizMessageScaffold(
            title: 'آزمون تعاملی',
            message: 'این درس پیدا نشد.',
          );
        }
        return TimedCombinedExamScreen(
          subjectTitle: pack.title,
          chapters: pack.chapters,
          questionLimit: subjectExamQuestionLimit,
        );
      },
    );
  }
}
