import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hamyar_hashtom_plus/core/router/app_routes.dart';
import 'package:hamyar_hashtom_plus/features/quiz/presentation/providers/quiz_providers.dart';
import 'package:hamyar_hashtom_plus/features/quiz/presentation/screens/interactive_exam_screen.dart';
import 'package:hamyar_hashtom_plus/features/quiz/presentation/screens/interactive_exams_home_screen.dart';
import 'package:hamyar_hashtom_plus/features/quiz/presentation/screens/timed_combined_exam_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/quiz_fixtures.dart';

GoRouter _router() => GoRouter(
      initialLocation: AppRoutes.interactiveExams,
      routes: [
        GoRoute(
          path: AppRoutes.interactiveExams,
          builder: (context, state) => const InteractiveExamsHomeScreen(),
          routes: [
            GoRoute(
              path: ':examId',
              builder: (context, state) =>
                  InteractiveExamScreen(examId: state.pathParameters['examId']!),
            ),
          ],
        ),
      ],
    );

Widget _routerApp(GoRouter router) => ProviderScope(
      overrides: [
        subjectPacksProvider.overrideWith((ref) async => fixturePacks()),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        builder: (context, child) => Directionality(
          textDirection: TextDirection.rtl,
          child: child!,
        ),
      ),
    );

Future<void> _pumpFrames(WidgetTester tester) async {
  // Bounded pumping: a running exam timer would never let pumpAndSettle end.
  await tester.pump();
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// A tall surface keeps the whole question grid on screen for taps.
void _tallView(WidgetTester tester) {
  tester.view.physicalSize = const Size(600, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('exam length matches the exam timer rule', () {
    expect(examMinutes(3, 20), 10);
    expect(examMinutes(14, 20), 14);
    expect(examMinutes(80, 20), 20);
    expect(examMinutes(80, 30), 30);
  });

  testWidgets('hub lists a mixed exam and each subject with real counts',
      (tester) async {
    final router = _router();
    addTearDown(router.dispose);
    await tester.pumpWidget(_routerApp(router));
    await tester.pumpAndSettle();

    expect(find.byKey(InteractiveExamsHomeScreen.examKey(mixedExamId)),
        findsOneWidget);
    expect(find.text('آزمون ترکیبی همه دروس'), findsOneWidget);
    // Math: 14 questions, 14 minutes. Mixed: the same 14 questions overall.
    expect(find.text('14 سؤال • 14 دقیقه'), findsNWidgets(2));

    final art = tester.widget<ListTile>(
      find.byKey(InteractiveExamsHomeScreen.examKey('art')),
    );
    expect(art.enabled, isFalse);
    expect(art.onTap, isNull);
    expect(find.text('هنوز سؤالی ثبت نشده است'), findsOneWidget);
  });

  testWidgets('hub shows an honest empty state without any question',
      (tester) async {
    final router = _router();
    addTearDown(router.dispose);
    await tester.pumpWidget(ProviderScope(
      overrides: [subjectPacksProvider.overrideWith((ref) async => [])],
      child: MaterialApp.router(routerConfig: router),
    ));
    await tester.pumpAndSettle();
    expect(find.text('هنوز سؤالی برای آزمون ثبت نشده است.'), findsOneWidget);
  });

  testWidgets('hub offers a retry when the content cannot load',
      (tester) async {
    final router = _router();
    addTearDown(router.dispose);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        subjectPacksProvider.overrideWith((ref) async => throw StateError('x')),
      ],
      child: MaterialApp.router(routerConfig: router),
    ));
    await tester.pumpAndSettle();
    expect(find.text('تلاش دوباره'), findsOneWidget);
  });

  testWidgets('opens a subject exam and guards leaving a running exam',
      (tester) async {
    final router = _router();
    addTearDown(router.dispose);
    await tester.pumpWidget(_routerApp(router));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(InteractiveExamsHomeScreen.examKey('math')));
    await tester.pumpAndSettle();
    expect(find.byType(TimedCombinedExamScreen), findsOneWidget);
    expect(find.text('شروع آزمون'), findsOneWidget);

    // Before the exam starts, leaving needs no confirmation.
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.byType(TimedCombinedExamScreen), findsNothing);

    await tester.tap(find.byKey(InteractiveExamsHomeScreen.examKey('math')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('شروع آزمون'));
    await tester.pump(const Duration(seconds: 2));
    expect(find.byType(Chip), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await _pumpFrames(tester);
    expect(find.text('خروج از آزمون'), findsOneWidget);

    await tester.tap(find.text('ادامه آزمون'));
    await _pumpFrames(tester);
    expect(find.byType(TimedCombinedExamScreen), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await _pumpFrames(tester);
    await tester.tap(find.text('خروج'));
    await _pumpFrames(tester);
    expect(find.byType(TimedCombinedExamScreen), findsNothing);
    expect(find.byType(InteractiveExamsHomeScreen), findsOneWidget);
  });

  testWidgets('time expiry submits the exam and flags it', (tester) async {
    final router = _router();
    addTearDown(router.dispose);
    await tester.pumpWidget(_routerApp(router));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(InteractiveExamsHomeScreen.examKey('math')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('شروع آزمون'));
    await tester.pump(const Duration(seconds: 1));

    // 14 questions give 14 minutes; run past the end of the exam.
    await tester.pump(const Duration(minutes: 15));
    await tester.pump();

    expect(find.text('نتیجه آزمون'), findsOneWidget);
    expect(find.text('زمان آزمون تمام شد'), findsOneWidget);
    expect(find.text('0 پاسخ ثبت‌شده'), findsOneWidget);
  });

  testWidgets('submitting by hand shows no time-out notice', (tester) async {
    _tallView(tester);
    final router = _router();
    addTearDown(router.dispose);
    await tester.pumpWidget(_routerApp(router));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(InteractiveExamsHomeScreen.examKey('math')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('شروع آزمون'));
    await tester.pump(const Duration(seconds: 1));

    // Jump to the last question, then finish and confirm.
    await tester.tap(find.text('14').last);
    await tester.pump();
    await tester.tap(find.text('ثبت و پایان آزمون'));
    await _pumpFrames(tester);
    await tester.tap(find.text('ثبت آزمون'));
    await _pumpFrames(tester);

    expect(find.text('نتیجه آزمون'), findsOneWidget);
    expect(find.text('زمان آزمون تمام شد'), findsNothing);
    expect(find.text('پاسخ‌نامه و توضیحات'), findsOneWidget);
  });

  testWidgets('mixed exam opens with questions from several subjects',
      (tester) async {
    final router = _router();
    addTearDown(router.dispose);
    await tester.pumpWidget(_routerApp(router));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(InteractiveExamsHomeScreen.examKey(mixedExamId)));
    await tester.pumpAndSettle();
    expect(find.byType(TimedCombinedExamScreen), findsOneWidget);
    expect(find.text('آزمون ترکیبی'), findsWidgets);
  });
}
