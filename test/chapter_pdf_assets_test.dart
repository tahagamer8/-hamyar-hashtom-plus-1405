import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const subjects = [
    'arabic', 'art', 'english', 'english_workbook', 'math', 'persian',
    'quran', 'religion', 'science', 'social', 'thinking', 'work', 'writing',
  ];

  test('every chapter has separate offline notes and questions PDFs', () async {
    var chapterCount = 0;
    for (final subjectId in subjects) {
      final raw = await rootBundle.loadString(
        'assets/content/subjects/$subjectId.json',
      );
      final pack = jsonDecode(raw) as Map<String, dynamic>;
      expect(pack['subjectId'], subjectId);
      final chapters = pack['chapters'] as List<dynamic>;
      expect(chapters, isNotEmpty, reason: subjectId);

      for (var index = 0; index < chapters.length; index++) {
        final prefix = 'assets/generated_pdfs/chapters/$subjectId/'
            'Fahmino-$subjectId-Chapter-${index + 1}';
        final notes = await rootBundle.load('$prefix-Notes-FA.pdf');
        final questions = await rootBundle.load('$prefix-Questions-FA.pdf');
        expect(notes.lengthInBytes, greaterThan(500), reason: '$subjectId/$index notes');
        expect(questions.lengthInBytes, greaterThan(500), reason: '$subjectId/$index questions');
        chapterCount++;
      }
    }
    expect(chapterCount, 145);
  });
}
