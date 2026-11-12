import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:hamyar_hashtom_plus/features/quiz/presentation/screens/timed_combined_exam_screen.dart';

Map<String, dynamic> _question(String prompt, {int answer = 0}) => {
  'question': prompt,
  'options': ['گزینه اول', 'گزینه دوم', 'گزینه سوم', 'گزینه چهارم'],
  'answer': answer,
  'explanation': 'توضیح پاسخ',
};

void main() {
  test('limited term exam samples questions evenly across chapters', () {
    final chapters = List.generate(
      4,
      (chapter) => {
        'title': 'درس ${chapter + 1}',
        'questions': List.generate(
          5,
          (question) => _question('پرسش ${chapter + 1}-${question + 1}'),
        ),
      },
    );

    final selected = buildBalancedExamQuestions(
      chapters: chapters,
      questionLimit: 8,
      random: Random(7),
    );
    final perChapter = <String, int>{};
    for (final question in selected) {
      final name = question['chapter'] as String;
      perChapter[name] = (perChapter[name] ?? 0) + 1;
    }

    expect(selected, hasLength(8));
    expect(perChapter.keys, containsAll(['درس 1', 'درس 2', 'درس 3', 'درس 4']));
    expect(perChapter.values.every((count) => count == 2), isTrue);
  });

  test('exam builder includes advanced questions and ignores malformed ones', () {
    final chapters = [
      {
        'title': 'ریاضی',
        'questions': [
          _question('پرسش پایه'),
          {'question': 'سؤال بدون گزینه', 'answer': 0},
        ],
        'advancedQuestions': [_question('پرسش استدلالی')],
      },
      {
        'title': 'علوم',
        'questions': [_question('پرسش علوم')],
      },
    ];

    final selected = buildBalancedExamQuestions(
      chapters: chapters,
      random: Random(3),
    );

    expect(selected, hasLength(3));
    expect(selected.map((item) => item['question']),
        containsAll(['پرسش پایه', 'پرسش استدلالی', 'پرسش علوم']));
    expect(selected.first['chapter'], isA<String>());
  });

  test('exam builder normalizes true-false and skips open-answer questions', () {
    final chapters = [
      {
        'title': 'عددهای گویا',
        'chapterExam': [
          _question('پرسش چهارگزینه‌ای'),
          {
            'question': 'مخرج کسر نباید صفر باشد.',
            'questionType': 'true_false',
            'answer': 'درست',
            'explanation': 'تقسیم بر صفر تعریف نشده است.',
          },
          {
            'question': 'یک تعریف را با بیان خودت بنویس.',
            'questionType': 'short_answer',
            'answer': 'پاسخ تشریحی',
            'explanation': 'این پاسخ باید با معیار مقایسه شود.',
          },
        ],
      },
    ];

    final selected = buildBalancedExamQuestions(
      chapters: chapters,
      random: Random(9),
    );

    expect(selected, hasLength(2));
    final trueFalse = selected.singleWhere(
      (item) => item['questionType'] == 'true_false',
    );
    expect(trueFalse['options'], ['درست', 'نادرست']);
    expect(trueFalse['answer'], 0);
    expect(selected.map((item) => item['question']),
        contains('پرسش چهارگزینه‌ای'));
  });

  test('exam builder respects the limit and caps it at available questions', () {
    final chapters = [
      {'title': 'فصل اول', 'questions': [_question('۱'), _question('۲')]},
      {'title': 'فصل دوم', 'questions': [_question('۳')]},
    ];

    final tooMany = buildBalancedExamQuestions(
      chapters: chapters,
      questionLimit: 20,
      random: Random(1),
    );
    final fewer = buildBalancedExamQuestions(
      chapters: chapters,
      questionLimit: 2,
      random: Random(1),
    );

    expect(tooMany, hasLength(3));
    expect(fewer, hasLength(2));
  });
}