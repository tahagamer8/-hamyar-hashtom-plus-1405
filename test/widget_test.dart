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
import 'package:hamyar_hashtom_plus/features/favorites/presentation/screens/favorites_screen.dart';
import 'package:hamyar_hashtom_plus/features/ai/presentation/screens/ai_chat_screen.dart';
import 'package:hamyar_hashtom_plus/features/documents/presentation/widgets/learning_pdfs_card.dart';

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
      "commonMistakes": ["در جمع کسرها ابتدا مخرج مشترک بگیر."],
      "pageStart": 10,
      "pageEnd": 18,
      "questions": [{
        "question": "حاصل ۱/۲ + ۱/۴ کدام است؟",
        "options": ["۱/۶", "۲/۶", "۳/۴", "۱"],
        "answer": 2,
        "explanation": "۱/۲ برابر ۲/۴ است؛ پس ۲/۴ + ۱/۴ = ۳/۴."
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
    if (key != 'assets/content/catalog_fa.json') {
      throw FlutterError('Unexpected test asset: $key');
    }
    return ByteData.sublistView(Uint8List.fromList(utf8.encode(catalog)));
  }
}

class _MapAssetBundle extends CachingAssetBundle {
  _MapAssetBundle(this.assets);

  final Map<String, String> assets;

  @override
  Future<ByteData> load(String key) async {
    final value = assets[key];
    if (value == null) throw FlutterError('Unexpected test asset: $key');
    return ByteData.sublistView(Uint8List.fromList(utf8.encode(value)));
  }

  @override
  Future<String> loadString(String key, {bool cache = true}) async {
    final value = assets[key];
    if (value == null) throw FlutterError('Unexpected test asset: $key');
    return value;
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

Future<void> _pumpUiFrames(WidgetTester tester) async {
  // Bounded frame pumping avoids hanging forever on repeating animations.
  await tester.pump();
  for (var i = 0; i < 7; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  setUpAll(() => SharedPreferences.setMockInitialValues({}));

  test('bundled catalog is valid and has content for each subject', () async {
    final file = File('assets/content/catalog_fa.json');
    expect(await file.exists(), isTrue);
    final catalog = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    expect(catalog.length, greaterThanOrEqualTo(12));
    expect(catalog.values.fold<int>(0, (sum, item) => sum + ((item as Map<String, dynamic>)['chapters'] as List<dynamic>).length), greaterThanOrEqualTo(130));
    expect((catalog['math'] as Map<String, dynamic>)['chapters'], hasLength(9));
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
    expect(totalQuestions, 379);
    expect(catalog['art'], isA<Map<String, dynamic>>());
    expect((catalog['art'] as Map<String, dynamic>)['chapters'], hasLength(5));
    expect(((catalog['math'] as Map<String, dynamic>)['chapters'] as List<dynamic>)
        .fold<int>(0, (sum, chapter) => sum + ((chapter as Map<String, dynamic>)['questions'] as List<dynamic>).length), 36);
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

  test('current independent subject packs pass full structural validation', () async {
    const subjectIds = [
      'math', 'science', 'persian', 'writing', 'arabic', 'english',
      'social', 'religion', 'quran', 'thinking', 'work',
      'english_workbook', 'art',
    ];
    var totalSections = 0;
    var totalQuestions = 0;
    final uniqueQuestions = <String>{};

    for (final id in subjectIds) {
      final file = File('assets/content/subjects/$id.json');
      expect(await file.exists(), isTrue, reason: id);
      final pack = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      expect(pack['subjectId'], id);
      expect(pack['title'], isA<String>());
      final chapters = pack['chapters'] as List<dynamic>;
      expect(chapters, isNotEmpty, reason: id);
      totalSections += chapters.length;

      for (final rawChapter in chapters) {
        final chapter = rawChapter as Map<String, dynamic>;
        expect((chapter['title'] as String?)?.trim(), isNotEmpty, reason: id);
        expect((chapter['summary'] as String?)?.trim().length, greaterThanOrEqualTo(30), reason: id + '/' + chapter['title']);
        expect((chapter['points'] as List<dynamic>), isNotEmpty, reason: id);
        expect((chapter['solutionSteps'] as List<dynamic>), isNotEmpty, reason: id);
        final questions = chapter['questions'] as List<dynamic>;
        expect(questions.length, greaterThanOrEqualTo(2), reason: id + '/' + chapter['title']);
        totalQuestions += questions.length;
        for (final rawQuestion in questions) {
          final question = rawQuestion as Map<String, dynamic>;
          final text = (question['question'] as String).trim();
          final normalized = text.toLowerCase()
              .replaceAll(RegExp(r'[\s\u200c\u0640؟،.!؛:]', unicode: true), '')
              .replaceAll('ي', 'ی')
              .replaceAll('ك', 'ک');
          expect(text, isNotEmpty, reason: id);
          expect(uniqueQuestions.add(normalized), isTrue, reason: 'پرسش تکراری در بسته‌های مستقل: ' + text);
          final options = question['options'] as List<dynamic>;
          expect(options.length, greaterThanOrEqualTo(4), reason: text);
          expect(options.toSet().length, options.length, reason: text);
          final answer = question['answer'] as int;
          expect(answer, inInclusiveRange(0, options.length - 1), reason: text);
          expect((question['explanation'] as String?)?.trim(), isNotEmpty, reason: text);
        }
      }
    }

    expect(totalSections, 145);
    expect(totalQuestions, 448);
    final religion = jsonDecode(
      await File('assets/content/subjects/religion.json').readAsString(),
    ) as Map<String, dynamic>;
    expect(religion['chapters'], hasLength(15));
  });

  testWidgets('PDF card exposes separate preview and download actions', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: LearningPdfsCard())),
    );

    expect(find.text('نمایش داخل برنامه'), findsNWidgets(5));
    expect(find.text('دانلود PDF'), findsNWidgets(5));
  });

  testWidgets('home screen renders Fahmino branding', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: HamyarApp()));
    await _pumpUiFrames(tester);
    expect(find.text(AppConstants.appName), findsWidgets);
    expect(find.text('دسترسی سریع'), findsOneWidget);
    expect(find.text('راهنمای درسی فهمینو', skipOffstage: false), findsOneWidget);

  });

  testWidgets('navigates to subjects tab', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: HamyarApp()));
    await _pumpUiFrames(tester);
    await tester.tap(find.text('دروس'));
    await _pumpUiFrames(tester);
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
    expect(find.text('Lesson 1: My Nationality'), findsOneWidget);
  });

  testWidgets('lesson content loads from catalog bundle', (tester) async {
    await tester.pumpWidget(_contentApp('lessons'));
    await _pumpUiFrames(tester);
    expect(find.text('عددهای صحیح و گویا'), findsOneWidget);
    expect(find.textContaining('عددهای گویا را می‌توان'), findsOneWidget);
  });

  testWidgets('notes are presented as a PDF rather than inline text', (tester) async {
    await tester.pumpWidget(_contentApp('notes'));
    await _pumpUiFrames(tester);
    expect(find.text('جزوه PDF ریاضی'), findsOneWidget);
    expect(find.text('نمایش داخل برنامه'), findsOneWidget);
    expect(find.text('قرینهٔ هر عدد با تغییر علامت آن به دست می‌آید.'), findsNothing);
  });

  testWidgets('step-by-step solution loads from catalog bundle', (tester) async {
    await tester.pumpWidget(_contentApp('solutions'));
    await _pumpUiFrames(tester);
    expect(find.text('مخرج مشترک ۶ انتخاب می‌کنیم.'), findsOneWidget);
  });

  testWidgets('sample questions are presented only as a PDF', (tester) async {
    await tester.pumpWidget(_contentApp('sampleExams'));
    await _pumpUiFrames(tester);
    expect(find.text('نمونه‌سؤال فصل‌به‌فصل PDF ریاضی'), findsOneWidget);
    expect(find.text('نمایش داخل برنامه'), findsNWidgets(3));
    expect(find.textContaining('حاصل ۱/۲ + ۱/۴ کدام است؟'), findsNothing);
    expect(find.text('شروع آزمون تیزهوشان نوبت اول'), findsNothing);
  });

  testWidgets('combined quiz has a timer and reveals answers after submission', (tester) async {
    await tester.pumpWidget(_contentApp('quiz'));
    await _pumpUiFrames(tester);
    expect(find.text('آزمون جامع ریاضی'), findsOneWidget);
    expect(find.text('10:00'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('09:59'), findsOneWidget);
    await tester.tap(find.text('۳/۴').first);
    await tester.pump();
    expect(find.textContaining('پاسخ درست:'), findsNothing);
    await tester.tap(find.text('ثبت و پایان آزمون'));
    await _pumpUiFrames(tester);
    await tester.tap(find.text('ثبت آزمون'));
    await _pumpUiFrames(tester);
    expect(find.textContaining('نمره:'), findsOneWidget);
    expect(find.textContaining('پاسخ درست: ۳/۴'), findsOneWidget);
  });

  testWidgets('completed timed exam saves a result to local history', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(_contentApp('quiz'));
    await _pumpUiFrames(tester);

    await tester.tap(find.text('ثبت و پایان آزمون'));
    await _pumpUiFrames(tester);
    await tester.tap(find.text('ثبت آزمون'));
    await _pumpUiFrames(tester);

    expect(find.textContaining('نمره:'), findsOneWidget);
    await tester.tap(find.text('مشاهدهٔ سوابق آزمون این درس'));
    await tester.pumpAndSettle();

    expect(find.text('نمره 0٪'), findsOneWidget);
    expect(find.textContaining('0 از 1 پاسخ درست'), findsOneWidget);
  });

  testWidgets('chapter can be added to favorites', (tester) async {
    await tester.pumpWidget(_contentApp('lessons'));
    await _pumpUiFrames(tester);
    expect(find.byTooltip('افزودن به علاقه‌مندی‌ها'), findsOneWidget);
    await tester.tap(find.byTooltip('افزودن به علاقه‌مندی‌ها'));
    await tester.pump();
    expect(find.byTooltip('حذف از علاقه‌مندی‌ها'), findsOneWidget);
  });

  testWidgets('math lesson displays chapter-specific common mistakes', (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final mathPack = (await tester.runAsync(
      () => File('assets/content/subjects/math.json').readAsString(),
    ))!;
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: DefaultAssetBundle(
            bundle: _MapAssetBundle({
              'assets/content/subjects/math.json': mathPack,
            }),
            child: const ContentLibraryScreen(
              subjectId: 'math',
              featureId: 'lessons',
            ),
          ),
        ),
      ),
    );
    await _pumpUiFrames(tester);

    expect(find.text('اشتباهات رایج'), findsOneWidget);
    await tester.tap(find.text('اشتباهات رایج'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.textContaining('برای جمع یا تفریق کسرها'), findsOneWidget);
  });

  testWidgets('science lesson displays chapter-specific common misconceptions', (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final sciencePack = (await tester.runAsync(
      () => File('assets/content/subjects/science.json').readAsString(),
    ))!;
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: DefaultAssetBundle(
            bundle: _MapAssetBundle({
              'assets/content/subjects/science.json': sciencePack,
            }),
            child: const ContentLibraryScreen(
              subjectId: 'science',
              featureId: 'lessons',
            ),
          ),
        ),
      ),
    );
    await _pumpUiFrames(tester);

    expect(find.text('اشتباهات رایج'), findsOneWidget);
    await tester.tap(find.text('اشتباهات رایج'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.textContaining('نمکِ حل‌شده از صافی عبور می‌کند'), findsOneWidget);
  });

  testWidgets('social studies lesson displays lesson-specific common misconceptions', (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final socialPack = (await tester.runAsync(
      () => File('assets/content/subjects/social.json').readAsString(),
    ))!;
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: DefaultAssetBundle(
            bundle: _MapAssetBundle({
              'assets/content/subjects/social.json': socialPack,
            }),
            child: const ContentLibraryScreen(
              subjectId: 'social',
              featureId: 'lessons',
            ),
          ),
        ),
      ),
    );
    await _pumpUiFrames(tester);

    expect(find.text('اشتباهات رایج'), findsOneWidget);
    await tester.tap(find.text('اشتباهات رایج'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.textContaining('تعاون فقط تقسیم کردن'), findsOneWidget);
  });

  testWidgets('Arabic lesson displays lesson-specific common misconceptions', (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final arabicPack = (await tester.runAsync(
      () => File('assets/content/subjects/arabic.json').readAsString(),
    ))!;
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: DefaultAssetBundle(
            bundle: _MapAssetBundle({
              'assets/content/subjects/arabic.json': arabicPack,
            }),
            child: const ContentLibraryScreen(
              subjectId: 'arabic',
              featureId: 'lessons',
            ),
          ),
        ),
      ),
    );
    await _pumpUiFrames(tester);

    expect(find.text('اشتباهات رایج'), findsOneWidget);
    await tester.tap(find.text('اشتباهات رایج'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.textContaining('هذانِ برای مثنای مذکر'), findsOneWidget);
  });

  testWidgets('favorites resolve titles from the current subject packs', (tester) async {
    SharedPreferences.setMockInitialValues({
      'fahmino_favorites_v1': [
        'work::پودمان ۱: شهروند الکترونیکی (۱)؛ اتصال به شبکه و پست الکترونیکی',
      ],
    });
    const catalog = r'{"work":{"title":"کار و فناوری","chapters":[]}}';
    const workPack = r'{"schemaVersion":1,"subjectId":"work","title":"کار و فناوری","chapters":[{"title":"پودمان ۱: شهروند الکترونیکی (۱)؛ اتصال به شبکه و پست الکترونیکی","summary":"پست الکترونیکی برای ارسال پیام و سند به یک یا چند گیرنده استفاده می‌شود.","points":["صندوق دریافت و پیوست را مدیریت کن."],"example":"یک ایمیل تمرینی بنویس.","solutionSteps":["گیرنده را وارد کن."],"questions":[]}]}';
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: DefaultAssetBundle(
            bundle: _MapAssetBundle({
              'assets/content/catalog_fa.json': catalog,
              'assets/content/subjects/work.json': workPack,
            }),
            child: const FavoritesScreen(),
          ),
        ),
      ),
    );
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pump();
    expect(
      find.text('پودمان ۱: شهروند الکترونیکی (۱)؛ اتصال به شبکه و پست الکترونیکی'),
      findsOneWidget,
    );
  });


  testWidgets('PDF favorites include term and gifted exam documents', (tester) async {
    SharedPreferences.setMockInitialValues({
      'fahmino_favorites_v1': [
        'pdf::math::firstTerm',
        'pdf::math::secondTerm',
        'pdf::math::gifted',
      ],
    });
    const catalog = r'{"math":{"title":"ریاضی","chapters":[]}}';
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: DefaultAssetBundle(
            bundle: _MapAssetBundle({
              'assets/content/catalog_fa.json': catalog,
            }),
            child: const FavoritesScreen(),
          ),
        ),
      ),
    );
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pump();

    expect(find.text('آزمون نوبت اول PDF'), findsOneWidget);
    expect(find.text('آزمون نوبت دوم PDF'), findsOneWidget);
    expect(find.text('پرسش‌های استدلالی سمپاد PDF'), findsOneWidget);
  });

  testWidgets('offline study helper reads current subject packs', (tester) async {
    const catalog = r'{"work":{"title":"کار و فناوری","chapters":[{"title":"عنوان قدیمی","summary":"نسخه قدیمی","points":[],"example":"","solutionSteps":[],"questions":[]} ]}}';
    const workPack = r'{"schemaVersion":1,"subjectId":"work","title":"کار و فناوری","chapters":[{"title":"پودمان ۱: شهروند الکترونیکی (۱)؛ اتصال به شبکه و پست الکترونیکی","summary":"پست الکترونیکی برای ارسال پیام و سند به یک یا چند گیرنده استفاده می‌شود.","points":["صندوق دریافت و پیوست را مدیریت کن."],"example":"یک ایمیل تمرینی بنویس.","solutionSteps":["گیرنده را وارد کن."],"questions":[]}]}';
    await tester.pumpWidget(
      MaterialApp(
        home: DefaultAssetBundle(
          bundle: _MapAssetBundle({
            'assets/content/catalog_fa.json': catalog,
            'assets/content/subjects/work.json': workPack,
          }),
          child: const AiChatScreen(),
        ),
      ),
    );
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pump();
    await _pumpUiFrames(tester);
    expect(find.text('راهنمای درسی فهمینو'), findsOneWidget);
    expect(find.textContaining('پرسش‌ها از دستگاه خارج نمی‌شوند'), findsOneWidget);
    expect(find.text('پودمان ۱: شهروند الکترونیکی (۱)؛ اتصال به شبکه و پست الکترونیکی'), findsOneWidget);
    expect(find.byTooltip('پاسخ از محتوای فهمینو'), findsOneWidget);
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
    await _pumpUiFrames(tester);
    expect(find.byType(TextField), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'حاصل ۱/۲ + ۱/۴');
    await tester.pump();
    expect(find.text('عددهای صحیح و گویا'), findsOneWidget);
  });

  testWidgets('search matches words in any order and includes common mistakes', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: DefaultAssetBundle(
          bundle: _MemoryAssetBundle(_testCatalog),
          child: const SearchScreen(),
        ),
      ),
    );
    await _pumpUiFrames(tester);

    await tester.enterText(find.byType(TextField), 'کسر گویا');
    await tester.pump();
    expect(find.text('عددهای صحیح و گویا'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'مخرج مشترک');
    await tester.pump();
    expect(find.text('عددهای صحیح و گویا'), findsOneWidget);
  });

  testWidgets('search accepts Persian page numbers and checks verified page ranges', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: DefaultAssetBundle(
          bundle: _MemoryAssetBundle(_testCatalog),
          child: const SearchScreen(),
        ),
      ),
    );
    await _pumpUiFrames(tester);

    await tester.enterText(find.byType(TextField), 'صفحهٔ ۱۲');
    await tester.pump();
    expect(find.text('عددهای صحیح و گویا'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'صفحه ۲۰');
    await tester.pump();
    expect(find.text('عددهای صحیح و گویا'), findsNothing);
  });
}
