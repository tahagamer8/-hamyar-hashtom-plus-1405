import 'package:hamyar_hashtom_plus/features/quiz/domain/mcq_level.dart';
import 'package:hamyar_hashtom_plus/features/quiz/domain/mcq_question.dart';

/// A subject with its chapters, as stored in the bundled content packs.
class SubjectPack {
  const SubjectPack({
    required this.id,
    required this.title,
    required this.chapters,
  });

  final String id;
  final String title;
  final List<Map<String, dynamic>> chapters;

  /// Valid questions that belong to [level]; empty for levels without a
  /// question source.
  List<McqQuestion> questionsFor(McqLevel level) {
    final key = level.sourceKey;
    if (key == null) {
      return const <McqQuestion>[];
    }
    return _collect([key]);
  }

  int countFor(McqLevel level) => questionsFor(level).length;

  /// Every valid question a timed exam can draw from.
  List<McqQuestion> get examQuestions =>
      _collect(const ['questions', 'advancedQuestions']);

  List<McqQuestion> _collect(List<String> keys) {
    final result = <McqQuestion>[];
    for (final chapter in chapters) {
      final rawTitle = chapter['title'];
      final title = rawTitle is String && rawTitle.trim().isNotEmpty
          ? rawTitle
          : 'درس';
      for (final key in keys) {
        final raw = chapter[key];
        if (raw is! List) {
          continue;
        }
        for (final item in raw) {
          final question = McqQuestion.tryParse(item, chapterTitle: title);
          if (question != null) {
            result.add(question);
          }
        }
      }
    }
    return result;
  }
}
