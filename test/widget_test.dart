import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hamyar_hashtom_plus/app.dart';
import 'package:hamyar_hashtom_plus/core/constants/app_constants.dart';
import 'package:hamyar_hashtom_plus/features/content/presentation/screens/content_library_screen.dart';
import 'package:hamyar_hashtom_plus/features/search/presentation/screens/search_screen.dart';

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

Widget _contentApp(String featureId) => MaterialApp(
      home: DefaultAssetBundle(
        bundle: _MemoryAssetBundle(_testCatalog),
        child: ContentLibraryScreen(
          subjectId: 'math',
          featureId: featureId,
        ),
      ),
    );

void main() {
  test('bundled catalog is valid and has content for each subject', () async {
    final file = File('assets/content/catalog_fa.json');
    expect(await file.exists(), isTrue);
    final catalog = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    expect(catalog.length, greaterThanOrEqualTo(8));
    for (final entry in catalog.entries) {
      final subject = entry.value as Map<String, dynamic>;
      expect(subject['title'], isA<String>(), reason: entry.key);
      final chapters = subject['chapters'] as List<dynamic>;
      expect(chapters, isNotEmpty, reason: entry.key);
      for (final rawChapter in chapters) {
        final chapter = rawChapter as Map<String, dynamic>;
        expect(chapter['title'], isA<String>(), reason: entry.key);
        expect(chapter['summary'], isA<String>(), reason: entry.key);
        expect(chapter['points'], isA<List<dynamic>>(), reason: entry.key);
        expect(chapter['solutionSteps'], isA<List<dynamic>>(), reason: entry.key);
        final questions = chapter['questions'] as List<dynamic>;
        for (final rawQuestion in questions) {
          final question = rawQuestion as Map<String, dynamic>;
          final options = question['options'] as List<dynamic>;
          final answer = question['answer'] as int;
          expect(options, isNotEmpty, reason: question['question'] as String);
          expect(answer, inInclusiveRange(0, options.length - 1),
              reason: question['question'] as String);
          expect(question['explanation'], isA<String>());
        }
      }
    }
  });

  testWidgets('home screen renders Fahmino branding', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: HamyarApp()));
    await tester.pumpAndSettle();
    expect(find.text(AppConstants.appName), findsWidgets);
    expect(find.text('امکانات'), findsOneWidget);
  });

  testWidgets('navigates to subjects tab', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: HamyarApp()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('دروس'));
    await tester.pumpAndSettle();
    expect(find.text('دروس پایه هشتم'), findsOneWidget);
    expect(find.text('ریاضی'), findsWidgets);
  });

  testWidgets('lesson content loads from catalog bundle', (tester) async {
    await tester.pumpWidget(_contentApp('lessons'));
    await tester.pumpAndSettle();
    expect(find.text('عددهای صحیح و گویا'), findsOneWidget);
    expect(find.textContaining('عددهای گویا را می‌توان'), findsOneWidget);
  });

  testWidgets('notes content loads from catalog bundle', (tester) async {
    await tester.pumpWidget(_contentApp('notes'));
    await tester.pumpAndSettle();
    expect(find.text('قرینهٔ هر عدد با تغییر علامت آن به دست می‌آید.'), findsOneWidget);
  });

  testWidgets('step-by-step solution loads from catalog bundle', (tester) async {
    await tester.pumpWidget(_contentApp('solutions'));
    await tester.pumpAndSettle();
    expect(find.text('مخرج مشترک ۶ انتخاب می‌کنیم.'), findsOneWidget);
  });

  testWidgets('sample questions display answer key', (tester) async {
    await tester.pumpWidget(_contentApp('sampleExams'));
    await tester.pumpAndSettle();
    expect(find.text('حاصل ۱/۲ + ۱/۴ کدام است؟'), findsOneWidget);
    expect(find.text('پاسخ: ۳/۴'), findsOneWidget);
  });

  testWidgets('quiz checks a correct answer', (tester) async {
    await tester.pumpWidget(_contentApp('quiz'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('۳/۴').first);
    await tester.pump();
    await tester.tap(find.text('بررسی پاسخ').first);
    await tester.pump();
    expect(find.textContaining('آفرین، پاسخ درست است.'), findsOneWidget);
  });

  testWidgets('search filters the learning catalog', (tester) async {
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
    await tester.enterText(find.byType(TextField), 'عددهای صحیح');
    await tester.pump();
    expect(find.text('عددهای صحیح و گویا'), findsOneWidget);
  });
}
