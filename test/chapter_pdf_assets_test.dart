import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const subjects = [
    'arabic', 'art', 'english', 'english_workbook', 'math', 'persian',
    'quran', 'religion', 'science', 'social', 'thinking', 'work', 'writing',
  ];

  test('every chapter PDF is a valid, loadable Flutter asset', () async {
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
          final path = '$prefix-$suffix-FA.pdf';
          final data = await rootBundle.load(path);
          expect(data.lengthInBytes, greaterThan(500), reason: path);
          final bytes = data.buffer.asUint8List(
            data.offsetInBytes,
            data.lengthInBytes,
          );
          expect(ascii.decode(bytes.take(4).toList()), '%PDF', reason: path);
        }
        chapterCount++;
      }
    }
    expect(chapterCount, 145);
  });
}
