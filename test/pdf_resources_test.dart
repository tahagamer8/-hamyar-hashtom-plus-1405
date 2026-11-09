import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('PDF resource catalog contains only direct HTTPS PDF links', () async {
    final raw = await rootBundle.loadString('assets/content/pdf_resources.json');
    final catalog = jsonDecode(raw) as Map<String, dynamic>;
    expect(catalog['schemaVersion'], 1);

    final subjects = catalog['subjects'] as Map<String, dynamic>;
    expect(subjects.keys, containsAll([
      'math', 'science', 'persian', 'writing', 'arabic', 'english',
      'social', 'religion', 'quran', 'thinking', 'work',
      'english_workbook', 'art',
    ]));

    for (final entry in subjects.entries) {
      final subject = entry.value as Map<String, dynamic>;
      for (final key in ['notes', 'samples']) {
        final resources = subject[key] as List<dynamic>;
        for (final value in resources) {
          final resource = value as Map<String, dynamic>;
          final url = resource['url'] as String;
          final uri = Uri.parse(url);
          expect(uri.scheme, 'https', reason: entry.key);
          expect(uri.host, isNotEmpty, reason: entry.key);
          expect(url.toLowerCase(), contains('.pdf'), reason: entry.key);
          expect(resource['title'], isA<String>());
          expect(resource['description'], isA<String>());
          expect(resource['source'], anyOf('همیار', 'پادرس'));
          expect(resource['chapterIndex'], isA<int>());
        }
      }
    }
  });

  test('math notes and sample PDFs map to all nine textbook chapters', () async {
    final raw = await rootBundle.loadString('assets/content/pdf_resources.json');
    final catalog = jsonDecode(raw) as Map<String, dynamic>;
    final math = (catalog['subjects'] as Map<String, dynamic>)['math']
        as Map<String, dynamic>;

    final notes = math['notes'] as List<dynamic>;
    final samples = math['samples'] as List<dynamic>;
    expect(notes, isNotEmpty);
    expect(samples, isNotEmpty);

    for (var chapterIndex = 0; chapterIndex < 9; chapterIndex++) {
      expect(
        notes.where((item) =>
            (item as Map<String, dynamic>)['chapterIndex'] == chapterIndex),
        isNotEmpty,
        reason: 'notes for math chapter ${chapterIndex + 1}',
      );
      expect(
        samples.where((item) =>
            (item as Map<String, dynamic>)['chapterIndex'] == chapterIndex),
        isNotEmpty,
        reason: 'sample PDFs for math chapter ${chapterIndex + 1}',
      );
    }
  });

  test('every PDF resource points to an existing chapter in its subject pack', () async {
    final raw = await rootBundle.loadString('assets/content/pdf_resources.json');
    final catalog = jsonDecode(raw) as Map<String, dynamic>;
    final subjects = catalog['subjects'] as Map<String, dynamic>;

    for (final entry in subjects.entries) {
      final packRaw = await rootBundle.loadString(
        'assets/content/subjects/${entry.key}.json',
      );
      final pack = jsonDecode(packRaw) as Map<String, dynamic>;
      final chapterCount = (pack['chapters'] as List<dynamic>).length;
      final subjectResources = entry.value as Map<String, dynamic>;

      for (final key in ['notes', 'samples']) {
        final resources = subjectResources[key] as List<dynamic>;
        for (final value in resources) {
          final resource = value as Map<String, dynamic>;
          expect(
            resource['chapterIndex'],
            inInclusiveRange(0, chapterCount - 1),
            reason: '${entry.key}/$key',
          );
        }
      }
    }
  });
}
