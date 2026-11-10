import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const subjects = [
    'arabic', 'art', 'english', 'english_workbook', 'math', 'persian',
    'quran', 'religion', 'science', 'social', 'thinking', 'work', 'writing',
  ];

  test('generator creates two valid offline PDFs for every chapter', () async {
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
        for (final suffix in ['Notes', 'Questions']) {
          final file = File('$prefix-$suffix-FA.pdf');
          expect(file.existsSync(), isTrue,
              reason: '$subjectId/chapter ${index + 1}/$suffix');
          final bytes = file.readAsBytesSync();
          expect(bytes.length, greaterThan(500),
              reason: '$subjectId/chapter ${index + 1}/$suffix');
          expect(ascii.decode(bytes.take(4).toList()), '%PDF',
              reason: '$subjectId/chapter ${index + 1}/$suffix');
        }
        chapterCount++;
      }
    }
    expect(chapterCount, 145);
  });
}
