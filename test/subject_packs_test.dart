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

  test('science chapters include chapter-specific common misconceptions', () async {
    final raw = await rootBundle.loadString('assets/content/subjects/science.json');
    final pack = jsonDecode(raw) as Map<String, dynamic>;
    final chapters = pack['chapters'] as List<dynamic>;
    expect(chapters, hasLength(15));
    for (final value in chapters) {
      final chapter = value as Map<String, dynamic>;
      final mistakes = chapter['commonMistakes'] as List<dynamic>;
      expect(mistakes, hasLength(2), reason: chapter['title'] as String);
      expect(mistakes.every((item) => item is String && item.trim().isNotEmpty), isTrue,
          reason: chapter['title'] as String);
    }
  });

  test('social studies lessons include lesson-specific common misconceptions', () async {
    final raw = await rootBundle.loadString('assets/content/subjects/social.json');
    final pack = jsonDecode(raw) as Map<String, dynamic>;
    final chapters = pack['chapters'] as List<dynamic>;
    expect(chapters, hasLength(24));
    for (final value in chapters) {
      final chapter = value as Map<String, dynamic>;
      final mistakes = chapter['commonMistakes'] as List<dynamic>;
      expect(mistakes, hasLength(2), reason: chapter['title'] as String);
      expect(mistakes.every((item) => item is String && item.trim().isNotEmpty), isTrue,
          reason: chapter['title'] as String);
    }
  });

  test('language packs include lesson-specific common misconceptions', () async {
    const packs = <String, int>{
      'english': 7,
      'english_workbook': 7,
      'arabic': 10,
    };
    for (final entry in packs.entries) {
      final raw = await rootBundle.loadString('assets/content/subjects/${entry.key}.json');
      final pack = jsonDecode(raw) as Map<String, dynamic>;
      final chapters = pack['chapters'] as List<dynamic>;
      expect(chapters, hasLength(entry.value), reason: entry.key);
      for (final value in chapters) {
        final chapter = value as Map<String, dynamic>;
        final mistakes = chapter['commonMistakes'] as List<dynamic>;
        expect(mistakes, hasLength(2), reason: '${entry.key}/${chapter['title']}');
        expect(mistakes.every((item) => item is String && item.trim().isNotEmpty), isTrue,
            reason: '${entry.key}/${chapter['title']}');
      }
    }
  });

  test('all 145 sections across 13 subjects have two common-mistake notes', () async {
    const ids = <String>[
      'math', 'science', 'persian', 'writing', 'arabic', 'english',
      'social', 'religion', 'quran', 'thinking', 'work',
      'english_workbook', 'art',
    ];
    var sectionCount = 0;
    var noteCount = 0;
    for (final id in ids) {
      final raw = await rootBundle.loadString('assets/content/subjects/$id.json');
      final pack = jsonDecode(raw) as Map<String, dynamic>;
      final chapters = pack['chapters'] as List<dynamic>;
      sectionCount += chapters.length;
      for (final value in chapters) {
        final chapter = value as Map<String, dynamic>;
        final mistakes = chapter['commonMistakes'] as List<dynamic>;
        expect(mistakes, hasLength(2), reason: '$id/${chapter['title']}');
        expect(mistakes.every((item) => item is String && item.trim().isNotEmpty), isTrue,
            reason: '$id/${chapter['title']}');
        noteCount += mistakes.length;
      }
    }
    expect(sectionCount, 145);
    expect(noteCount, 290);
  });

  test('verified 1405 textbook pages and curriculum choices match source contents', () async {
    Future<Map<String, dynamic>> load(String id) async {
      final raw = await rootBundle.loadString('assets/content/subjects/$id.json');
      return jsonDecode(raw) as Map<String, dynamic>;
    }

    final science = await load('science');
    final scienceChapters = science['chapters'] as List<dynamic>;
    expect(scienceChapters.map((c) => (c as Map<String, dynamic>)['pageEnd']).toList(),
        [8, 20, 27, 34, 46, 54, 64, 75, 88, 96, 103, 113, 121, 135, null]);

    final social = await load('social');
    final socialChapters = social['chapters'] as List<dynamic>;
    expect((socialChapters.first as Map<String, dynamic>)['pageEnd'], 6);
    expect((socialChapters.last as Map<String, dynamic>)['pageStart'], 162);
    expect((socialChapters.last as Map<String, dynamic>).containsKey('pageEnd'), isFalse);

    final arabic = await load('arabic');
    final arabicChapters = arabic['chapters'] as List<dynamic>;
    expect((arabicChapters.first as Map<String, dynamic>)['pageEnd'], 22);
    expect((arabicChapters.last as Map<String, dynamic>)['pageStart'], 127);
    expect((arabicChapters.last as Map<String, dynamic>).containsKey('pageEnd'), isFalse);

    final workbook = await load('english_workbook');
    final workbookChapters = workbook['chapters'] as List<dynamic>;
    expect((workbookChapters.first as Map<String, dynamic>)['pageEnd'], 7);
    expect((workbookChapters.last as Map<String, dynamic>)['pageStart'], 41);

    final work = await load('work');
    final workChapters = work['chapters'] as List<dynamic>;
    expect((workChapters.first as Map<String, dynamic>)['pageStart'], 3);
    for (var i = 0; i < 4; i++) {
      expect((workChapters[i] as Map<String, dynamic>)['curriculumStatus'], 'required');
    }
    for (var i = 4; i < 9; i++) {
      final chapter = workChapters[i] as Map<String, dynamic>;
      expect(chapter['curriculumStatus'], 'choice');
      expect(chapter['choiceRequiredCount'], 4);
      expect(chapter['choiceTotalCount'], 5);
    }

    final thinking = await load('thinking');
    final thinkingChapters = thinking['chapters'] as List<dynamic>;
    expect(thinkingChapters.where((c) =>
        (c as Map<String, dynamic>)['curriculumStatus'] == 'required'), hasLength(4));
    expect(thinkingChapters.where((c) =>
        (c as Map<String, dynamic>)['curriculumStatus'] == 'choice'), hasLength(2));
    expect(thinkingChapters.where((c) =>
        (c as Map<String, dynamic>)['curriculumStatus'] == 'optional'), hasLength(1));

    final art = await load('art');
    final artChapters = art['chapters'] as List<dynamic>;
    expect((artChapters[0] as Map<String, dynamic>)['requiredTopics'], ['طراحی']);
    expect((artChapters[0] as Map<String, dynamic>)['choiceTopics'], ['عکاسی', 'تصویرسازی']);
    expect((artChapters[2] as Map<String, dynamic>)['choiceTopics'], ['بافت', 'چاپ دستی']);
  });

  test('all 145 sections include an authored reasoning question and a term assignment', () async {
    const ids = <String>[
      'math', 'science', 'persian', 'writing', 'arabic', 'english',
      'social', 'religion', 'quran', 'thinking', 'work',
      'english_workbook', 'art',
    ];
    var sections = 0;
    var advancedQuestions = 0;
    for (final id in ids) {
      final raw = await rootBundle.loadString('assets/content/subjects/$id.json');
      final pack = jsonDecode(raw) as Map<String, dynamic>;
      expect(pack['sampleQuestionBankVersion'], 1, reason: id);
      final chapters = pack['chapters'] as List<dynamic>;
      final firstTerm = <Map<String, dynamic>>[];
      final secondTerm = <Map<String, dynamic>>[];
      for (final value in chapters) {
        final chapter = value as Map<String, dynamic>;
        sections++;
        final term = chapter['examTerm'];
        expect(term, anyOf('first', 'second'), reason: chapter['title'] as String);
        if (term == 'first') firstTerm.add(chapter);
        if (term == 'second') secondTerm.add(chapter);

        final questions = chapter['advancedQuestions'] as List<dynamic>;
        expect(questions, hasLength(1), reason: chapter['title'] as String);
        final question = questions.single as Map<String, dynamic>;
        final options = question['options'] as List<dynamic>;
        final answer = question['answer'] as int;
        expect(question['questionType'], 'reasoning');
        expect(question['difficulty'], 'استدلالی');
        expect(question['source'], 'تألیفی فهمینو');
        expect((question['question'] as String).trim(), isNotEmpty);
        expect(options, hasLength(4));
        expect(options.toSet().length, 4);
        expect(answer, inInclusiveRange(0, 3));
        expect((question['explanation'] as String).trim(), isNotEmpty);
        advancedQuestions += questions.length;
      }
      expect(firstTerm, isNotEmpty, reason: id);
      expect(secondTerm, isNotEmpty, reason: id);
    }
    expect(sections, 145);
    expect(advancedQuestions, 145);
  });

  test('five recovered textbook sources point to official 1405-1406 portal PDFs', () async {
    const expected = <String, String>{
      'math': 'C805.pdf',
      'persian': 'C803.pdf',
      'writing': 'C804.pdf',
      'quran': 'C801.pdf',
      'religion': 'C802.pdf',
    };
    for (final entry in expected.entries) {
      final raw = await rootBundle.loadString('assets/content/subjects/${entry.key}.json');
      final pack = jsonDecode(raw) as Map<String, dynamic>;
      final source = pack['textbookSource'] as Map<String, dynamic>;
      expect(source['schoolYear'], '1405-1406', reason: entry.key);
      expect(source['bookCode'], isA<String>(), reason: entry.key);
      expect(source['pdfUrl'], contains(entry.value), reason: entry.key);
      expect(source['verificationStatus'],
          'official_portal_record_and_pdf_link_verified_not_downloaded_or_parsed',
          reason: entry.key);
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
