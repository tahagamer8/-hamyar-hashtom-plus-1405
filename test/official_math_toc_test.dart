import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('math chapters carry verified printed-TOC lesson mappings without invented PDF-page mapping', () async {
    final raw = await rootBundle.loadString('assets/content/subjects/math.json');
    final pack = jsonDecode(raw) as Map<String, dynamic>;
    final chapters = pack['chapters'] as List<dynamic>;
    expect(chapters, hasLength(9));

    for (final value in chapters) {
      final chapter = value as Map<String, dynamic>;
      final lessons = chapter['textbookLessons'] as List<dynamic>;
      expect(lessons, isNotEmpty, reason: chapter['title'] as String);

      final evidence = chapter['officialTocEvidence'] as Map<String, dynamic>;
      expect(evidence['status'], 'printed_toc_title_and_page_verified');
      expect(evidence['physicalPdfPageStart'], isNull);
      expect(evidence['physicalPdfPageEnd'], isNull);

      final start = chapter['pageStart'] as int;
      final end = chapter['pageEnd'] as int;
      for (final item in lessons) {
        final lesson = item as Map<String, dynamic>;
        expect(lesson['verifiedAgainstOfficialToc'], isTrue);
        expect(lesson['pageStart'], inInclusiveRange(start, end));
      }
    }
  });
}
