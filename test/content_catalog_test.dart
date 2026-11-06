import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Persian content catalog has complete chapters and valid questions', () async {
    final raw = await rootBundle.loadString('assets/content/catalog_fa.json');
    final catalog = jsonDecode(raw) as Map<String, dynamic>;

    expect(catalog, isNotEmpty);

    var totalAdvancedQuestions = 0;
    for (final entry in catalog.entries) {
      final subject = entry.value as Map<String, dynamic>;
      expect(subject['title'], isA<String>(), reason: entry.key);
      final chapters = subject['chapters'] as List<dynamic>;
      expect(chapters, isNotEmpty, reason: entry.key);

      for (final chapterValue in chapters) {
        final chapter = chapterValue as Map<String, dynamic>;
        final challengeQuestions = chapter['challengeQuestions'] as List<dynamic>? ?? [];
        for (final rawChallenge in challengeQuestions) {
          totalAdvancedQuestions++;
          final challenge = rawChallenge as Map<String, dynamic>;
          final options = challenge['options'] as List<dynamic>;
          expect(challenge['difficulty'], 'advanced');
          expect(challenge['contentOrigin'], 'fahmino_authored_practice');
          expect(challenge['verificationStatus'], 'not_verified_against_official_textbook');
          expect(options.length, greaterThanOrEqualTo(4));
          expect(challenge['answer'], inInclusiveRange(0, options.length - 1));
          expect((challenge['explanation'] as String).trim(), isNotEmpty);
        }
        expect(chapter['title'], isA<String>());
        expect((chapter['title'] as String).trim(), isNotEmpty);
        expect(chapter['summary'], isA<String>());
        expect((chapter['summary'] as String).trim(), isNotEmpty);
        expect(chapter['points'], isA<List<dynamic>>());
        expect(chapter['example'], isA<String>());
        expect(chapter['solutionSteps'], isA<List<dynamic>>());

        final questions = chapter['questions'] as List<dynamic>;
        expect(questions, isNotEmpty);
        for (final questionValue in questions) {
          final question = questionValue as Map<String, dynamic>;
          final options = question['options'] as List<dynamic>;
          final answer = question['answer'];
          expect(question['question'], isA<String>());
          expect(options.length, greaterThanOrEqualTo(2));
          expect(options.every((option) => option is String), isTrue);
          expect(answer, isA<int>());
          expect(answer as int, inInclusiveRange(0, options.length - 1));
          expect(question['explanation'], isA<String>());
          expect((question['explanation'] as String).trim(), isNotEmpty);
        }
      }
    }
    // Structured lesson coverage is checked separately from question coverage.
    final mathChapters =
        (catalog['math'] as Map<String, dynamic>)['chapters'] as List<dynamic>;
    final scienceChapters =
        (catalog['science'] as Map<String, dynamic>)['chapters'] as List<dynamic>;
    expect(mathChapters.length, 9);
    expect(scienceChapters.length, 15);
    expect(
      mathChapters.fold<int>(
        0,
        (sum, chapter) =>
            sum + ((chapter as Map<String, dynamic>)['learningSections'] as List<dynamic>).length,
      ),
      36,
    );
    expect(
      scienceChapters.fold<int>(
        0,
        (sum, chapter) =>
            sum + ((chapter as Map<String, dynamic>)['learningSections'] as List<dynamic>).length,
      ),
      60,
    );
    for (final chapter in [...mathChapters, ...scienceChapters]) {
      final sections =
          (chapter as Map<String, dynamic>)['learningSections'] as List<dynamic>;
      expect(sections.length, 4);
      for (final sectionValue in sections) {
        final section = sectionValue as Map<String, dynamic>;
        expect((section['title'] as String).trim(), isNotEmpty);
        expect((section['content'] as String).trim().length, greaterThan(80));
        expect(section['examples'], isA<List<dynamic>>());
        expect((section['examples'] as List<dynamic>), isNotEmpty);
        expect(section['keyPoints'], isA<List<dynamic>>());
        expect((section['keyPoints'] as List<dynamic>), isNotEmpty);
      }
    }

    final arabicChapters =
        (catalog['arabic'] as Map<String, dynamic>)['chapters'] as List<dynamic>;
    final englishChapters =
        (catalog['english'] as Map<String, dynamic>)['chapters'] as List<dynamic>;
    expect(
      arabicChapters.fold<int>(
        0,
        (sum, chapter) =>
            sum + ((chapter as Map<String, dynamic>)['learningSections'] as List<dynamic>).length,
      ),
      40,
    );
    expect(
      englishChapters.fold<int>(
        0,
        (sum, chapter) =>
            sum + ((chapter as Map<String, dynamic>)['learningSections'] as List<dynamic>).length,
      ),
      28,
    );
    for (final chapter in [...arabicChapters, ...englishChapters]) {
      final sections =
          (chapter as Map<String, dynamic>)['learningSections'] as List<dynamic>;
      expect(sections.length, 4);
      for (final sectionValue in sections) {
        final section = sectionValue as Map<String, dynamic>;
        expect((section['title'] as String).trim(), isNotEmpty);
        expect((section['content'] as String).trim().length, greaterThan(50));
        expect((section['examples'] as List<dynamic>), isNotEmpty);
        expect((section['keyPoints'] as List<dynamic>), isNotEmpty);
      }
    }

    expect(totalAdvancedQuestions, greaterThanOrEqualTo(224));
    expect(
      ((catalog['math'] as Map<String, dynamic>)['chapters'] as List<dynamic>)
          .fold<int>(0, (sum, chapter) =>
              sum + ((chapter as Map<String, dynamic>)['challengeQuestions'] as List<dynamic>).length),
      45,
    );
  });
}
