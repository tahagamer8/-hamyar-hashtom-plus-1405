import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hamyar_hashtom_plus/app.dart';
import 'package:hamyar_hashtom_plus/core/constants/app_constants.dart';
import 'package:hamyar_hashtom_plus/features/content/presentation/screens/content_library_screen.dart';
import 'package:hamyar_hashtom_plus/features/search/presentation/screens/search_screen.dart';
import 'package:hamyar_hashtom_plus/features/quiz/presentation/screens/timed_combined_exam_screen.dart';

const _testCatalog = r'''
{
  "math": {
    "title": "ریاضی",
    "chapters": [{
      "title": "عددهای صحیح و گویا",
      "summary": "عددهای گویا را می‌توان به صورت کسر نوشت.",
      "points": ["قرینهٔ هر عدد با تغییر علامت آن به دست می‌آید."],
      "example": "مثال: ۱/۲ + ۱/۳ را حساب کن.",
      "solutionSteps": ["مخرج مشترک ۶ انتخاب می‌کنیم.", "۱/۲ = ۳/۶ و ۱/۳ = ۲/۶.", "۳/۶ + ۲/۶ = ۵/۶."],
      "questions": [{
        "question": "حاصل ۱/۲ + ۱/۴ کدام است؟",
        "options": ["۱/۶", "۲/۶", "۳/۴", "۱"],
        "answer": 2,
        "explanation": "۱/۲ برابر ۲/۴ است؛ پس ۲/۴ + ۱/۴ = ۳/۴."
      }],
      "challengeQuestions": [{
        "question": "حاصل (−۳/۴ + ۵/۶) ÷ (−۱/۱۲) کدام است؟",
        "options": ["−۱", "۱", "−۱۲", "۱۲"],
        "answer": 0,
        "explanation": "ابتدا مجموع برابر ۱/۱۲ و سپس خارج‌قسمت برابر −۱ می‌شود.",
        "difficulty": "advanced",
        "contentOrigin": "fahmino_authored_practice",
        "verificationStatus": "not_verified_against_official_textbook"
      }]
    }, {
      "title": "عددهای اول",
      "summary": "عدد اول فقط دو شمارندهٔ مثبت دارد.",
      "points": ["عدد ۱ اول نیست."],
      "example": "عدد ۷ اول است.",
      "solutionSteps": ["شمارنده‌ها را بررسی می‌کنیم."],
      "questions": [{
        "question": "کدام عدد اول است؟",
        "options": ["۴", "۶", "۷", "۹"],
        "answer": 2,
        "explanation": "۷ فقط بر ۱ و خودش بخش‌پذیر است."
      }]
    }]
  }
}
''';

class _MemoryAssetBundle extends CachingAssetBundle {
  _MemoryAssetBundle(this.catalog);

  final String catalog;

  @override
  Future<ByteData> load(String key) async {
    if (key == 'assets/content/catalog_fa.json') {
      return ByteData.sublistView(Uint8List.fromList(utf8.encode(catalog)));
    }
    if (key == 'assets/generated_pdfs/manifest.json') {
      return ByteData.sublistView(Uint8List.fromList(utf8.encode('[]')));
    }
    throw FlutterError('Unexpected test asset: $key');
  }
}

Widget _contentApp(String featureId) => ProviderScope(
      child: MaterialApp(
        home: DefaultAssetBundle(
          bundle: _MemoryAssetBundle(_testCatalog),
          child: ContentLibraryScreen(
            subjectId: 'math',
            featureId: featureId,
          ),
        ),
      ),
    );

void main() {
  setUpAll(() => SharedPreferences.setMockInitialValues({}));

  test('bundled catalog is valid and has content for each subject', () async {
    final file = File('assets/content/catalog_fa.json');
    expect(await file.exists(), isTrue);
    final catalog = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    expect(catalog.length, greaterThanOrEqualTo(14));
    expect(catalog.values.fold<int>(0, (sum, item) => sum + ((item as Map<String, dynamic>)['chapters'] as List<dynamic>).length), greaterThanOrEqualTo(150));
    expect((catalog['math'] as Map<String, dynamic>)['chapters'], hasLength(9));
    final firstMathChapter = ((catalog['math'] as Map<String, dynamic>)['chapters'] as List<dynamic>).first as Map<String, dynamic>;
    expect(firstMathChapter['learningSections'], hasLength(4));
    expect((catalog['science'] as Map<String, dynamic>)['chapters'], hasLength(15));
    expect((catalog['social'] as Map<String, dynamic>)['chapters'], hasLength(24));
    final religionChapters = (catalog['religion'] as Map<String, dynamic>)['chapters'] as List<dynamic>;
    expect(religionChapters, hasLength(16));
    expect((religionChapters.first as Map<String, dynamic>)['title'], startsWith('درس ۱:'));
    expect((religionChapters[14] as Map<String, dynamic>)['title'], startsWith('درس ۱۵:'));
    expect((religionChapters.last as Map<String, dynamic>)['title'], startsWith('مرور تکمیلی'));
    var totalQuestions = 0;
    final uniqueQuestionTexts = <String>{};
    for (final entry in catalog.entries) {
      final subject = entry.value as Map<String, dynamic>;
      expect(subject['title'], isA<String>(), reason: entry.key);
      final chapters = subject['chapters'] as List<dynamic>;
      expect(chapters, isNotEmpty, reason: entry.key);
      for (final rawChapter in chapters) {
        final chapter = rawChapter as Map<String, dynamic>;
        expect(chapter['title'], isA<String>(), reason: entry.key);
        expect(chapter['summary'], isA<String>(), reason: entry.key);
        expect((chapter['summary'] as String).trim().length, greaterThanOrEqualTo(30), reason: '${entry.key}/${chapter['title']}');
        expect(chapter['example'], isA<String>(), reason: '${entry.key}/${chapter['title']}');
        expect((chapter['example'] as String).trim(), isNotEmpty, reason: '${entry.key}/${chapter['title']}');
        expect(chapter['points'], isA<List<dynamic>>(), reason: entry.key);
        expect((chapter['points'] as List<dynamic>), isNotEmpty, reason: '${entry.key}/${chapter['title']}');
        expect(chapter['solutionSteps'], isA<List<dynamic>>(), reason: entry.key);
        expect((chapter['solutionSteps'] as List<dynamic>), isNotEmpty, reason: '${entry.key}/${chapter['title']}');
        final challengeQuestions = chapter['challengeQuestions'] as List<dynamic>? ?? [];
        expect(challengeQuestions, isNotEmpty,
            reason: 'سؤال چالشی برای ${entry.key}/${chapter['title']} ثبت نشده است');
        final questions = chapter['questions'] as List<dynamic>;
        expect(questions.length, greaterThanOrEqualTo(2), reason: '${entry.key}/${chapter['title']}');
        totalQuestions += questions.length;
        for (final rawQuestion in questions) {
          final question = rawQuestion as Map<String, dynamic>;
          final options = question['options'] as List<dynamic>;
          final answer = question['answer'] as int;
          final questionText = (question['question'] as String).trim();
          final normalizedText = questionText
              .toLowerCase()
              .replaceAll(RegExp(r'[\s\u200c\u0640؟،.!؛:]', unicode: true), '')
              .replaceAll('ي', 'ی')
              .replaceAll('ك', 'ک');
          expect(questionText, isNotEmpty, reason: entry.key);
          expect(uniqueQuestionTexts.add(normalizedText), isTrue,
              reason: 'پرسش تکراری: ${question['question']}');
          expect(options.length, greaterThanOrEqualTo(4), reason: questionText);
          expect(options.toSet().length, options.length, reason: 'گزینه تکراری: $questionText');
          expect(answer, inInclusiveRange(0, options.length - 1),
              reason: question['question'] as String);
          expect(question['explanation'], isA<String>());
          expect((question['explanation'] as String).trim(), isNotEmpty, reason: questionText);
        }
      }
    }
    expect(totalQuestions, 409);
    final answerPositionCounts = List<int>.filled(4, 0);
    for (final subjectValue in catalog.values) {
      final subject = subjectValue as Map<String, dynamic>;
      for (final rawChapter in subject['chapters'] as List<dynamic>) {
        final chapter = rawChapter as Map<String, dynamic>;
        for (final group in [
          chapter['questions'] as List<dynamic>,
          chapter['challengeQuestions'] as List<dynamic>,
        ]) {
          for (final rawQuestion in group) {
            final question = rawQuestion as Map<String, dynamic>;
            answerPositionCounts[question['answer'] as int]++;
          }
        }
      }
    }
    expect(answerPositionCounts.reduce((a, b) => a > b ? a : b) -
        answerPositionCounts.reduce((a, b) => a < b ? a : b), lessThanOrEqualTo(1));
    expect(((catalog['math'] as Map<String, dynamic>)['chapters'] as List<dynamic>)
        .fold<int>(0, (sum, chapter) => sum + ((chapter as Map<String, dynamic>)['questions'] as List<dynamic>).length), 36);
    final mathChapters = (catalog['math'] as Map<String, dynamic>)['chapters'] as List<dynamic>;
    final advancedCount = mathChapters.fold<int>(0, (sum, raw) {
      final chapter = raw as Map<String, dynamic>;
      final advanced = chapter['challengeQuestions'] as List<dynamic>? ?? [];
      expect(advanced.every((q) => (q as Map<String, dynamic>)['difficulty'] == 'advanced'), isTrue);
      return sum + advanced.length;
    });
    expect(advancedCount, 27);
    expect((catalog['culture_art'] as Map<String, dynamic>)['chapters'], hasLength(9));
    final optionalFaithPackage = catalog['from_me_to_god'] as Map<String, dynamic>;
    expect(optionalFaithPackage['curriculumApplicability'], 'pilot_in_some_provinces');
    expect(optionalFaithPackage['chapters'], hasLength(11));
    final allAdvancedCount = catalog.values.fold<int>(0, (sum, subjectValue) {
      final subject = subjectValue as Map<String, dynamic>;
      final chapters = subject['chapters'] as List<dynamic>;
      return sum + chapters.fold<int>(0, (chapterSum, rawChapter) {
        final chapter = rawChapter as Map<String, dynamic>;
        return chapterSum + ((chapter['challengeQuestions'] as List<dynamic>?)?.length ?? 0);
      });
    });
    expect(allAdvancedCount, 224);
    expect(((catalog['science'] as Map<String, dynamic>)['chapters'] as List<dynamic>)
        .fold<int>(0, (sum, chapter) => sum + ((chapter as Map<String, dynamic>)['questions'] as List<dynamic>).length), 60);
    expect((catalog['social'] as Map<String, dynamic>)['chapters'], hasLength(24));
    expect((catalog['english'] as Map<String, dynamic>)['chapters'], hasLength(7));
    expect((catalog['english_workbook'] as Map<String, dynamic>)['chapters'], hasLength(7));
    expect((catalog['arabic'] as Map<String, dynamic>)['chapters'], hasLength(10));
    for (final id in ['persian', 'writing', 'arabic', 'english', 'english_workbook', 'religion', 'quran', 'thinking', 'work']) {
      expect(((catalog[id] as Map<String, dynamic>)['chapters'] as List<dynamic>).length, greaterThanOrEqualTo(5), reason: id);
    }
  });

  testWidgets('home screen renders Fahmino branding', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: HamyarApp()));
    await tester.pumpAndSettle();
    expect(find.text(AppConstants.appName), findsWidgets);
    expect(find.text('امکانات'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('دستیار هوشمند فهمینو'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('دستیار هوشمند فهمینو'), findsOneWidget);
    expect(find.text('باز کردن جزوه'), findsNothing);
    expect(find.text('باز کردن نمونه‌سؤال'), findsNothing);
  });

  testWidgets('navigates to subjects tab', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: HamyarApp()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('دروس'));
    await tester.pumpAndSettle();
    expect(find.text('دروس پایه هشتم'), findsOneWidget);
    expect(find.text('ریاضی'), findsWidgets);
  });

  testWidgets('English workbook opens as a separate subject', (tester) async {
    const workbookCatalog = r'''
    {
      "english_workbook": {
        "title": "کتاب کار زبان انگلیسی",
        "chapters": [{
          "title": "Lesson 1: My Nationality",
          "summary": "تمرین ملیت‌ها",
          "points": ["Iranian یعنی ایرانی."],
          "example": "I am Iranian.",
          "solutionSteps": ["کشور را مشخص می‌کنیم."],
          "questions": []
        }]
      }
    }
    ''';
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: DefaultAssetBundle(
            bundle: _MemoryAssetBundle(workbookCatalog),
            child: const ContentLibraryScreen(
              subjectId: 'english_workbook',
              featureId: 'lessons',
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));
    expect(find.text('کتاب کار زبان انگلیسی'), findsOneWidget);
    expect(find.text('Lesson 1: My Nationality'), findsWidgets);
  });

  testWidgets('lesson content loads from catalog bundle', (tester) async {
    await tester.pumpWidget(_contentApp('lessons'));
    await tester.pumpAndSettle();
    expect(find.text('عددهای صحیح و گویا'), findsWidgets);
    expect(find.text('خلاصهٔ آموزشی فصل'), findsOneWidget);
    expect(find.textContaining('عددهای گویا را می‌توان به صورت کسر نوشت.'), findsOneWidget);
    expect(find.text('مثال آموزشی'), findsOneWidget);
    expect(find.text('راه‌حل مرحله‌به‌مرحله'), findsOneWidget);
    expect(find.textContaining('خلاصهٔ اولیه است'), findsOneWidget);
  });

  testWidgets('notes content loads from catalog bundle', (tester) async {
    await tester.pumpWidget(_contentApp('notes'));
    await tester.pumpAndSettle();
    expect(find.text('قرینهٔ هر عدد با تغییر علامت آن به دست می‌آید.'), findsOneWidget);
  });

  testWidgets('step-by-step solution loads from catalog bundle', (tester) async {
    await tester.pumpWidget(_contentApp('solutions'));
    await tester.pumpAndSettle();
    expect(find.textContaining('پاسخ‌های فعالیت‌ها و تمرین‌های خودِ کتاب هنوز'), findsOneWidget);
  });

  testWidgets('sample questions reveal answer key on demand', (tester) async {
    await tester.pumpWidget(_contentApp('sampleExams'));
    await tester.pumpAndSettle();
    expect(find.textContaining('حاصل ۱/۲ + ۱/۴ کدام است؟'), findsOneWidget);
    expect(find.text('سؤال‌های دشوار و ترکیبی'), findsOneWidget);
    expect(find.textContaining('حاصل (−۳/۴ + ۵/۶)'), findsOneWidget);
    expect(find.text('پاسخ: ۳/۴'), findsNothing);
    await tester.tap(find.text('نمایش پاسخ و توضیح').first);
    await tester.pump();
    expect(find.text('پاسخ: ۳/۴'), findsOneWidget);
    expect(find.textContaining('۱/۲ برابر ۲/۴ است'), findsOneWidget);
  });

  testWidgets('combined quiz has a timer and reveals answers after submission', (tester) async {
    await tester.pumpWidget(_contentApp('quiz'));
    await tester.pumpAndSettle();
    expect(find.text('آزمون جامع ریاضی'), findsOneWidget);
    expect(find.text('10:00'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('09:59'), findsOneWidget);
    expect(find.textContaining('سطح دشوار و ترکیبی'), findsOneWidget);
    await tester.tap(find.text('−۱').first);
    await tester.pump();
    expect(find.textContaining('پاسخ درست:'), findsNothing);
    await tester.tap(find.text('ثبت و پایان آزمون'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ثبت آزمون'));
    await tester.pumpAndSettle();
    expect(find.textContaining('نمره:'), findsOneWidget);
    expect(find.textContaining('پاسخ درست: −۱'), findsOneWidget);
  });

  testWidgets('quiz switches between selected chapter and whole subject', (tester) async {
    await tester.pumpWidget(_contentApp('quiz'));
    await tester.pumpAndSettle();

    var exam = tester.widget<TimedCombinedExamScreen>(
      find.byType(TimedCombinedExamScreen),
    );
    expect(exam.chapters, hasLength(1));

    await tester.tap(find.text('کل درس'));
    await tester.pumpAndSettle();
    exam = tester.widget<TimedCombinedExamScreen>(
      find.byType(TimedCombinedExamScreen),
    );
    expect(exam.chapters, hasLength(2));

    await tester.tap(find.text('فصل انتخابی'));
    await tester.pumpAndSettle();
    exam = tester.widget<TimedCombinedExamScreen>(
      find.byType(TimedCombinedExamScreen),
    );
    expect(exam.chapters, hasLength(1));
  });

  testWidgets('chapter can be added to favorites', (tester) async {
    await tester.pumpWidget(_contentApp('lessons'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('افزودن به علاقه‌مندی‌ها'), findsOneWidget);
    await tester.tap(find.byTooltip('افزودن به علاقه‌مندی‌ها'));
    await tester.pump();
    expect(find.byTooltip('حذف از علاقه‌مندی‌ها'), findsOneWidget);
  });

  testWidgets('search finds text inside a question', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: DefaultAssetBundle(
          bundle: _MemoryAssetBundle(_testCatalog),
          child: const SearchScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget);
    expect(find.textContaining('بخشی از سؤال را جست‌وجو کن'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'حاصل ۱/۲ + ۱/۴');
    await tester.pump();
    expect(find.text('عددهای صحیح و گویا'), findsOneWidget);
  });
}
