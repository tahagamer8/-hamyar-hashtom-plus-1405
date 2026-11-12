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

  test('all 145 sections include authored lessons, mixed practice and chapter exams', () async {
    const ids = <String>[
      'math', 'science', 'persian', 'writing', 'arabic', 'english',
      'social', 'religion', 'quran', 'thinking', 'work',
      'english_workbook', 'art',
    ];
    var sections = 0;
    var advancedQuestions = 0;
    var chapterExamQuestions = 0;
    var shortAnswerCount = 0;
    var trueFalseCount = 0;
    var essayQuestionCount = 0;

    for (final id in ids) {
      final raw = await rootBundle.loadString('assets/content/subjects/$id.json');
      final pack = jsonDecode(raw) as Map<String, dynamic>;
      expect(pack['sampleQuestionBankVersion'], 1, reason: id);
      expect(pack['contentVersion'], '2026.11.12.1', reason: id);
      final chapters = pack['chapters'] as List<dynamic>;
      final firstTerm = <Map<String, dynamic>>[];
      final secondTerm = <Map<String, dynamic>>[];

      for (final value in chapters) {
        final chapter = value as Map<String, dynamic>;
        sections++;
        final title = chapter['title'] as String;
        final term = chapter['examTerm'];
        expect(term, anyOf('first', 'second'), reason: title);
        if (term == 'first') firstTerm.add(chapter);
        if (term == 'second') secondTerm.add(chapter);

        final lesson = chapter['lessonContent'] as String;
        expect(lesson.trim().length, greaterThanOrEqualTo(350), reason: title);
        expect(chapter['learningObjectives'], isA<List<dynamic>>(), reason: title);
        expect(chapter['workedExamples'], isA<List<dynamic>>(), reason: title);
        final examples = chapter['workedExamples'] as List<dynamic>;
        expect(examples.length, greaterThanOrEqualTo(2), reason: title);
        for (final exampleValue in examples) {
          final example = exampleValue as Map<String, dynamic>;
          expect((example['problem'] as String).trim(), isNotEmpty, reason: title);
          expect((example['answer'] as String).trim(), isNotEmpty, reason: title);
          expect((example['explanation'] as String).trim(), isNotEmpty, reason: title);
          expect(example['steps'], isA<List<dynamic>>(), reason: title);
        }

        final questions = chapter['advancedQuestions'] as List<dynamic>;
        expect(questions, hasLength(3), reason: title);
        final shortAnswers = questions
            .where((item) => (item as Map<String, dynamic>)['questionType'] == 'short_answer')
            .toList();
        final trueFalse = questions
            .where((item) => (item as Map<String, dynamic>)['questionType'] == 'true_false')
            .toList();
        expect(shortAnswers, hasLength(2), reason: title);
        expect(trueFalse, hasLength(1), reason: title);

        for (final questionValue in questions) {
          final question = questionValue as Map<String, dynamic>;
          expect(question['source'], 'تألیفی فهمینو', reason: title);
          expect((question['question'] as String).trim(), isNotEmpty, reason: title);
          expect((question['explanation'] as String).trim(), isNotEmpty, reason: title);
          expect((question['difficulty'] as String).trim(), isNotEmpty, reason: title);
          if (question['questionType'] == 'short_answer') {
            expect((question['answer'] as String).trim(), isNotEmpty, reason: title);
            shortAnswerCount++;
          } else {
            expect(question['questionType'], 'true_false', reason: title);
            expect(question['answer'], anyOf('درست', 'نادرست'), reason: title);
            trueFalseCount++;
          }
          advancedQuestions++;
        }

        final essays = chapter['essayQuestions'] as List<dynamic>;
        expect(essays, hasLength(1), reason: title);
        final essay = essays.single as Map<String, dynamic>;
        expect(essay['questionType'], 'essay', reason: title);
        expect(essay['source'], 'تألیفی فهمینو', reason: title);
        expect((essay['question'] as String).trim(), isNotEmpty, reason: title);
        expect(essay['answerGuidelines'], isA<List<dynamic>>(), reason: title);
        expect(essay['evaluationCriteria'], hasLength(4), reason: title);
        essayQuestionCount++;

        final exam = chapter['chapterExam'] as List<dynamic>;
        expect(exam.length, greaterThanOrEqualTo(5), reason: title);
        expect(
          exam.every((item) => item is Map<String, dynamic> &&
              (item['question'] as String? ?? '').trim().isNotEmpty &&
              (item['explanation'] as String? ?? '').trim().isNotEmpty),
          isTrue,
          reason: title,
        );
        chapterExamQuestions += exam.length;
      }
      expect(firstTerm, isNotEmpty, reason: id);
      expect(secondTerm, isNotEmpty, reason: id);
    }

    expect(sections, 145);
    expect(advancedQuestions, 435);
    expect(shortAnswerCount, 290);
    expect(trueFalseCount, 145);
    expect(essayQuestionCount, 145);
    expect(chapterExamQuestions, greaterThanOrEqualTo(725));
  });

  test('all 13 subject packs reference official 1405-1406 textbook PDFs', () async {
    const expected = <String, Map<String, String>>{
      'arabic': {'code': '809', 'portalId': '14224', 'file': 'C809.pdf'},
      'art': {'code': '808', 'portalId': '14223', 'file': 'C808.pdf'},
      'english': {'code': '810', 'portalId': '14225', 'file': 'C810.pdf'},
      'english_workbook': {'code': '811', 'portalId': '14226', 'file': 'C811.pdf'},
      'math': {'code': '805', 'portalId': '14220', 'file': 'C805.pdf'},
      'persian': {'code': '803', 'portalId': '14218', 'file': 'C803.pdf'},
      'quran': {'code': '801', 'portalId': '14210', 'file': 'C801.pdf'},
      'religion': {'code': '802', 'portalId': '14217', 'file': 'C802.pdf'},
      'science': {'code': '806', 'portalId': '14221', 'file': 'C806.pdf'},
      'social': {'code': '807', 'portalId': '14222', 'file': 'C807.pdf'},
      'thinking': {'code': '812', 'portalId': '14227', 'file': 'C812.pdf'},
      'work': {'code': '817', 'portalId': '14229', 'file': 'C817.pdf'},
      'writing': {'code': '804', 'portalId': '14219', 'file': 'C804.pdf'},
    };
    for (final entry in expected.entries) {
      final raw = await rootBundle.loadString('assets/content/subjects/${entry.key}.json');
      final pack = jsonDecode(raw) as Map<String, dynamic>;
      final source = pack['textbookSource'] as Map<String, dynamic>;
      expect(source['schoolYear'], '1405-1406', reason: entry.key);
      expect(source['bookCode'], entry.value['code'], reason: entry.key);
      expect(source['portalUrl'], contains('/books/${entry.value['portalId']}'), reason: entry.key);
      expect(source['pdfUrl'], contains(entry.value['file']), reason: entry.key);
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
