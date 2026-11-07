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
