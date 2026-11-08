import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const subjects = <String>[
    'math', 'science', 'persian', 'writing', 'arabic', 'english',
    'social', 'religion', 'quran', 'thinking', 'work',
    'english_workbook', 'art',
  ];

  test('math pack maps all nine chapters to the official 1405 textbook pages', () async {
    final raw = await rootBundle.loadString('assets/content/subjects/math.json');
    final pack = jsonDecode(raw) as Map<String, dynamic>;
    final chapters = pack['chapters'] as List<dynamic>;

    expect(pack['textbookEdition'], 'چاپ سیزدهم، ۱۴۰۵');
    expect(chapters, hasLength(9));
    for (final value in chapters) {
      final chapter = value as Map<String, dynamic>;
      final start = chapter['pageStart'] as int;
      final end = chapter['pageEnd'] as int;
      final lessons = chapter['textbookLessons'] as List<dynamic>;
      expect(start, lessThanOrEqualTo(end));
      expect(lessons, isNotEmpty);
      for (final lessonValue in lessons) {
        final lesson = lessonValue as Map<String, dynamic>;
        expect(lesson['title'], isA<String>());
        expect(lesson['pageStart'], inInclusiveRange(start, end));
      }
    }
  });

  test('math chapters include at least two chapter-specific common mistakes', () async {
    final raw = await rootBundle.loadString('assets/content/subjects/math.json');
    final pack = jsonDecode(raw) as Map<String, dynamic>;
    final chapters = pack['chapters'] as List<dynamic>;
    expect(chapters, hasLength(9));
    for (final value in chapters) {
      final chapter = value as Map<String, dynamic>;
      final mistakes = chapter['commonMistakes'] as List<dynamic>;
      expect(mistakes, hasLength(2), reason: chapter['title'] as String);
      expect(mistakes.every((item) => item is String && item.trim().isNotEmpty), isTrue,
          reason: chapter['title'] as String);
    }
  });

  test('every subject has an independently loadable, valid content pack', () async {
    for (final id in subjects) {
      final raw = await rootBundle.loadString('assets/content/subjects/$id.json');
      final pack = jsonDecode(raw) as Map<String, dynamic>;
      expect(pack['schemaVersion'], 1, reason: id);
      expect(pack['subjectId'], id, reason: id);
      expect(pack['title'], isA<String>(), reason: id);
      final chapters = pack['chapters'] as List<dynamic>;
      expect(chapters, isNotEmpty, reason: id);

      for (final chapterValue in chapters) {
        final chapter = chapterValue as Map<String, dynamic>;
        expect(chapter['title'], isA<String>(), reason: id);
        expect(chapter['summary'], isA<String>(), reason: id);
        expect(chapter['points'], isA<List<dynamic>>(), reason: id);
        expect(chapter['example'], isA<String>(), reason: id);
        expect(chapter['solutionSteps'], isA<List<dynamic>>(), reason: id);
        final questions = chapter['questions'] as List<dynamic>;
        expect(questions, isNotEmpty, reason: id);
        for (final questionValue in questions) {
          final question = questionValue as Map<String, dynamic>;
          final options = question['options'] as List<dynamic>;
          final answer = question['answer'] as int;
          expect(question['question'], isA<String>(), reason: id);
          expect(options.length, greaterThanOrEqualTo(2), reason: id);
          expect(answer, inInclusiveRange(0, options.length - 1), reason: id);
          expect(question['explanation'], isA<String>(), reason: id);
        }
      }
    }
  });
}
