import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hamyar_hashtom_plus/features/quiz/data/mcq_history_store.dart';
import 'package:hamyar_hashtom_plus/features/quiz/domain/mcq_level.dart';
import 'package:hamyar_hashtom_plus/features/quiz/domain/mcq_question.dart';
import 'package:hamyar_hashtom_plus/features/quiz/presentation/providers/quiz_providers.dart';
import 'package:hamyar_hashtom_plus/features/quiz/presentation/screens/mcq_practice_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/quiz_fixtures.dart';

Widget _app(Widget home, {ThemeData? theme}) => ProviderScope(
      overrides: [
        subjectPacksProvider.overrideWith((ref) async => fixturePacks()),
      ],
      child: MaterialApp(
        theme: theme,
        builder: (context, child) => Directionality(
          textDirection: TextDirection.rtl,
          child: child!,
        ),
        home: home,
      ),
    );

/// Opens the practice screen as a pushed route so the back button exists.
Widget _pushedApp({Random? random, ThemeData? theme}) => _app(
      Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: FilledButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => McqPracticeScreen(
                    levelId: 'intermediate',
                    subjectId: 'math',
                    random: random,
                  ),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
      theme: theme,
    );

/// A tall surface keeps the whole question grid on screen for taps.
void _tallView(WidgetTester tester) {
  tester.view.physicalSize = const Size(600, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('answers every question, scores it and shows the review',
      (tester) async {
    _tallView(tester);
    await tester.pumpWidget(_app(McqPracticeScreen(
      levelId: 'intermediate',
      subjectId: 'math',
      random: Random(7),
    )));
    await tester.pumpAndSettle();

    // Same seed, same input: the screen draws exactly this selection.
    final picked = selectBalancedQuestions(
      fixturePacks().first.questionsFor(McqLevel.intermediate),
      limit: McqPracticeScreen.sessionSize,
      random: Random(7),
    );
    final expected = picked.where((q) => q.answerIndex == 0).length;

    expect(find.text('1 از 10'), findsOneWidget);
    for (var i = 0; i < 10; i++) {
      await tester.tap(find.byKey(McqPracticeScreen.optionKey(0)));
      await tester.pump();
      if (i < 9) {
        await tester.tap(find.byKey(McqPracticeScreen.nextKey));
        await tester.pump();
      }
    }
    await tester.tap(find.byKey(McqPracticeScreen.finishKey));
    await tester.pumpAndSettle();
    expect(find.text('پایان تمرین'), findsOneWidget);
    await tester.tap(find.text('ثبت نتیجه'));
    await tester.pumpAndSettle();

    expect(find.text('نتیجه تمرین'), findsOneWidget);
    expect(find.text('$expected پاسخ درست از 10 سؤال'), findsOneWidget);
    expect(find.text('مرور پاسخ‌ها'), findsOneWidget);

    final saved = await tester.runAsync(
      () => const McqHistoryStore().load(McqLevel.intermediate, 'math'),
    );
    expect(saved, hasLength(1));
    expect(saved!.single.score, expected);
    expect(saved.single.total, 10);
  });

  testWidgets('question navigation keeps the chosen answers', (tester) async {
    _tallView(tester);
    await tester.pumpWidget(_app(McqPracticeScreen(
      levelId: 'intermediate',
      subjectId: 'math',
      random: Random(1),
    )));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(McqPracticeScreen.optionKey(2)));
    await tester.pump();
    expect(find.text('1 پاسخ ثبت‌شده از 10'), findsOneWidget);

    await tester.tap(find.byKey(McqPracticeScreen.nextKey));
    await tester.pump();
    expect(find.text('2 از 10'), findsOneWidget);
    expect(find.text('1 پاسخ ثبت‌شده از 10'), findsOneWidget);

    await tester.tap(find.byKey(McqPracticeScreen.previousKey));
    await tester.pump();
    expect(find.text('1 از 10'), findsOneWidget);

    await tester.tap(find.byKey(McqPracticeScreen.gotoKey(5)));
    await tester.pump();
    expect(find.text('6 از 10'), findsOneWidget);
  });

  testWidgets('leaving with answers asks first and can be cancelled',
      (tester) async {
    await tester.pumpWidget(_pushedApp(random: Random(1)));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byType(McqPracticeScreen), findsOneWidget);

    await tester.tap(find.byKey(McqPracticeScreen.optionKey(0)));
    await tester.pump();
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('خروج از تمرین'), findsOneWidget);

    await tester.tap(find.text('ادامه تمرین'));
    await tester.pumpAndSettle();
    expect(find.byType(McqPracticeScreen), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('خروج'));
    await tester.pumpAndSettle();
    expect(find.byType(McqPracticeScreen), findsNothing);
  });

  testWidgets('leaving without any answer needs no confirmation',
      (tester) async {
    await tester.pumpWidget(_pushedApp(random: Random(1)));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.byType(McqPracticeScreen), findsNothing);
  });

  testWidgets('a subject without questions shows an honest empty state',
      (tester) async {
    await tester.pumpWidget(_app(const McqPracticeScreen(
      levelId: 'intermediate',
      subjectId: 'art',
    )));
    await tester.pumpAndSettle();
    expect(
      find.text('برای این سطح و درس هنوز سؤالی ثبت نشده است.'),
      findsOneWidget,
    );
    expect(find.byKey(McqPracticeScreen.nextKey), findsNothing);
  });

  testWidgets('levels without a question source never open a session',
      (tester) async {
    await tester.pumpWidget(_app(const McqPracticeScreen(
      levelId: 'sampad',
      subjectId: 'math',
    )));
    await tester.pumpAndSettle();
    expect(find.byKey(McqPracticeScreen.nextKey), findsNothing);
    expect(find.textContaining('وجود ندارد'), findsOneWidget);
  });

  testWidgets('retry starts a fresh session', (tester) async {
    _tallView(tester);
    await tester.pumpWidget(_app(McqPracticeScreen(
      levelId: 'advanced',
      subjectId: 'math',
      random: Random(5),
    )));
    await tester.pumpAndSettle();
    // The advanced fixture has only two questions.
    expect(find.text('1 از 2'), findsOneWidget);
    await tester.tap(find.byKey(McqPracticeScreen.optionKey(0)));
    await tester.pump();
    await tester.tap(find.byKey(McqPracticeScreen.nextKey));
    await tester.pump();
    await tester.tap(find.byKey(McqPracticeScreen.optionKey(1)));
    await tester.pump();
    await tester.tap(find.byKey(McqPracticeScreen.finishKey));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ثبت نتیجه'));
    await tester.pumpAndSettle();
    expect(find.text('نتیجه تمرین'), findsOneWidget);

    await tester.tap(find.byKey(McqPracticeScreen.retryKey));
    await tester.pumpAndSettle();
    expect(find.text('1 از 2'), findsOneWidget);
    expect(find.text('0 پاسخ ثبت‌شده از 2'), findsOneWidget);
  });

  for (final size in const [Size(320, 568), Size(400, 800)]) {
    for (final dark in const [false, true]) {
      testWidgets(
        'question and result fit at ${size.width.toInt()}px, ${dark ? 'dark' : 'light'}',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          await tester.pumpWidget(_app(
            McqPracticeScreen(
              levelId: 'advanced',
              subjectId: 'math',
              random: Random(2),
            ),
            theme: dark ? ThemeData.dark() : ThemeData.light(),
          ));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);

          await tester.tap(find.byKey(McqPracticeScreen.optionKey(0)));
          await tester.pump();
          await tester.tap(find.byKey(McqPracticeScreen.nextKey));
          await tester.pump();
          await tester.tap(find.byKey(McqPracticeScreen.finishKey));
          await tester.pumpAndSettle();
          await tester.tap(find.text('ثبت نتیجه'));
          await tester.pumpAndSettle();
          expect(find.text('نتیجه تمرین'), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
