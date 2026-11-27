import 'dart:math';

/// One validated multiple-choice question.
class McqQuestion {
  const McqQuestion({
    required this.chapterTitle,
    required this.prompt,
    required this.options,
    required this.answerIndex,
    required this.explanation,
  });

  final String chapterTitle;
  final String prompt;
  final List<String> options;
  final int answerIndex;
  final String explanation;

  /// Returns null when [raw] is not a well-formed question, so malformed
  /// content is skipped instead of crashing the UI.
  static McqQuestion? tryParse(Object? raw, {required String chapterTitle}) {
    if (raw is! Map) {
      return null;
    }
    final prompt = raw['question'];
    final options = raw['options'];
    final answer = raw['answer'];
    final explanation = raw['explanation'];
    if (prompt is! String || prompt.trim().isEmpty) {
      return null;
    }
    if (options is! List ||
        options.length < 2 ||
        !options.every((option) => option is String)) {
      return null;
    }
    if (answer is! int || answer < 0 || answer >= options.length) {
      return null;
    }
    return McqQuestion(
      chapterTitle: chapterTitle,
      prompt: prompt,
      options: List<String>.unmodifiable(options.cast<String>()),
      answerIndex: answer,
      explanation: explanation is String ? explanation : '',
    );
  }
}

/// Picks up to [limit] questions spread across chapters.
///
/// Questions are shuffled inside each chapter and drawn round by round, so a
/// chapter with a large question bank cannot dominate a short session.
List<McqQuestion> selectBalancedQuestions(
  List<McqQuestion> questions, {
  required int limit,
  Random? random,
}) {
  if (limit <= 0 || questions.isEmpty) {
    return const <McqQuestion>[];
  }
  final rng = random ?? Random();
  final pools = <String, List<McqQuestion>>{};
  for (final question in questions) {
    pools.putIfAbsent(question.chapterTitle, () => <McqQuestion>[]).add(question);
  }
  final lists = pools.values.toList();
  for (final list in lists) {
    list.shuffle(rng);
  }
  final selected = <McqQuestion>[];
  for (var round = 0; selected.length < limit; round++) {
    var added = false;
    for (final pool in lists) {
      if (round < pool.length && selected.length < limit) {
        selected.add(pool[round]);
        added = true;
      }
    }
    if (!added) {
      break;
    }
  }
  selected.shuffle(rng);
  return selected;
}
