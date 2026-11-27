import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hamyar_hashtom_plus/app.dart';
import 'package:hamyar_hashtom_plus/core/router/app_router.dart';
import 'package:hamyar_hashtom_plus/core/router/app_routes.dart';
import 'package:hamyar_hashtom_plus/features/ai/presentation/screens/ai_chat_screen.dart';
import 'package:hamyar_hashtom_plus/features/content/presentation/screens/content_library_screen.dart';
import 'package:hamyar_hashtom_plus/features/home/presentation/widgets/exam_sections_card.dart';
import 'package:hamyar_hashtom_plus/features/planner/presentation/screens/study_planner_screen.dart';
import 'package:hamyar_hashtom_plus/features/quiz/domain/mcq_level.dart';
import 'package:hamyar_hashtom_plus/features/quiz/presentation/providers/quiz_providers.dart';
import 'package:hamyar_hashtom_plus/features/quiz/presentation/screens/interactive_exams_home_screen.dart';
import 'package:hamyar_hashtom_plus/features/quiz/presentation/screens/mcq_subject_picker_screen.dart';
import 'package:hamyar_hashtom_plus/features/quiz/presentation/screens/mcq_tests_home_screen.dart';
import 'package:hamyar_hashtom_plus/features/quiz/presentation/screens/timed_combined_exam_screen.dart';
import 'package:hamyar_hashtom_plus/features/subjects/presentation/screens/feature_subjects_screen.dart';
import 'package:hamyar_hashtom_plus/features/subjects/presentation/screens/subject_detail_screen.dart';

import 'helpers/quiz_fixtures.dart';

Future<void> _pumpFrames(WidgetTester tester) async {
  // Bounded frame pumping avoids hanging on repeating animations.
  await tester.pump();
  for (var i = 0; i < 7; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void _setViewSize(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

List<Override> _fixtureOverrides({bool empty = false}) => [
      subjectPacksProvider.overrideWith(
        (ref) async => empty ? [] : fixturePacks(),
      ),
    ];

/// Hosts a single screen in RTL with an adjustable text scale.
Widget _host(
  Widget home, {
  double textScale = 1,
  List<Override>? overrides,
}) =>
    ProviderScope(
      overrides: overrides ?? _fixtureOverrides(),
      child: MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: child!,
          ),
        ),
        home: home,
      ),
    );

Widget _cardHost() => const Scaffold(
      body: SingleChildScrollView(child: ExamSectionsCard()),
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('route constants', () {
    test('new exam routes are independent top-level paths', () {
      expect(AppRoutes.mcqTests, '/mcq-tests');
      expect(AppRoutes.interactiveExams, '/interactive-exams');
      expect(AppRoutes.mcqLevel('intermediate'), '/mcq-tests/intermediate');
      expect(AppRoutes.mcqPractice('advanced', 'math'), '/mcq-tests/advanced/math');
      expect(AppRoutes.interactiveExam('mixed'), '/interactive-exams/mixed');
    });

    test('existing route constants are unchanged', () {
      expect(AppRoutes.home, '/');
      expect(AppRoutes.subjects, '/subjects');
      expect(AppRoutes.ai, '/ai');
      expect(AppRoutes.planner, '/planner');
      expect(AppRoutes.search, '/search');
      expect(AppRoutes.favorites, '/favorites');
      expect(AppRoutes.settings, '/settings');
      expect(AppRoutes.featureSubjects('quiz'), '/feature/quiz');
      expect(AppRoutes.subjectDetail('math'), '/subjects/math');
    });
  });

  group('home screen', () {
    testWidgets('exam card sits between planner and PDF card', (tester) async {
      _setViewSize(tester, const Size(400, 3000));
      await tester.pumpWidget(const ProviderScope(child: HamyarApp()));
      await _pumpFrames(tester);

      final planner = find.text('برنامه‌ریز مطالعه');
      final card = find.byType(ExamSectionsCard);
      final pdfs = find.text('مرکز فایل‌های PDF پایه هشتم');
      expect(planner, findsOneWidget);
      expect(card, findsOneWidget);
      expect(pdfs, findsOneWidget);

      final plannerY = tester.getTopLeft(planner).dy;
      final cardY = tester.getTopLeft(card).dy;
      final pdfsY = tester.getTopLeft(pdfs).dy;
      expect(plannerY, lessThan(cardY));
      expect(cardY, lessThan(pdfsY));
    });

    testWidgets('opens the MCQ hub and back returns home', (tester) async {
      _setViewSize(tester, const Size(400, 3000));
      await tester.pumpWidget(const ProviderScope(child: HamyarApp()));
      await _pumpFrames(tester);

      await tester.tap(find.byKey(ExamSectionsCard.mcqKey));
      await _pumpFrames(tester);
      expect(find.byType(McqTestsHomeScreen), findsOneWidget);

      await tester.tap(find.byType(BackButton));
      await _pumpFrames(tester);
      expect(find.byType(McqTestsHomeScreen), findsNothing);
      expect(find.byType(ExamSectionsCard), findsOneWidget);
    });

    testWidgets('opens the interactive hub and back returns home',
        (tester) async {
      _setViewSize(tester, const Size(400, 3000));
      await tester.pumpWidget(const ProviderScope(child: HamyarApp()));
      await _pumpFrames(tester);

      await tester.tap(find.byKey(ExamSectionsCard.interactiveKey));
      await _pumpFrames(tester);
      expect(find.byType(InteractiveExamsHomeScreen), findsOneWidget);

      await tester.tap(find.byType(BackButton));
      await _pumpFrames(tester);
      expect(find.byType(InteractiveExamsHomeScreen), findsNothing);
      expect(find.byType(ExamSectionsCard), findsOneWidget);
    });
  });

  group('MCQ hub', () {
    testWidgets('shows four levels', (tester) async {
      await tester.pumpWidget(_host(const McqTestsHomeScreen()));
      await tester.pumpAndSettle();

      for (final level in McqLevel.values) {
        expect(find.byKey(McqTestsHomeScreen.levelKey(level)), findsOneWidget,
            reason: level.id);
      }
      expect(McqLevel.values, hasLength(4));
      expect(find.text('آسان'), findsOneWidget);
      expect(find.text('متوسط'), findsOneWidget);
      expect(find.text('پیشرفته'), findsOneWidget);
      expect(find.text('سمپاد'), findsOneWidget);
    });

    testWidgets('only Easy and SAMPAD carry the coming-soon badge',
        (tester) async {
      await tester.pumpWidget(_host(const McqTestsHomeScreen()));
      await tester.pumpAndSettle();

      expect(find.byKey(McqTestsHomeScreen.badgeKey(McqLevel.easy)),
          findsOneWidget);
      expect(find.byKey(McqTestsHomeScreen.badgeKey(McqLevel.sampad)),
          findsOneWidget);
      expect(find.byKey(McqTestsHomeScreen.badgeKey(McqLevel.intermediate)),
          findsNothing);
      expect(find.byKey(McqTestsHomeScreen.badgeKey(McqLevel.advanced)),
          findsNothing);
      expect(find.text('به‌زودی'), findsNWidgets(2));
    });

    testWidgets('Easy and SAMPAD stay disabled even when content exists',
        (tester) async {
      await tester.pumpWidget(_host(const McqTestsHomeScreen()));
      await tester.pumpAndSettle();

      for (final level in [McqLevel.easy, McqLevel.sampad]) {
        final tile = tester.widget<ListTile>(
          find.byKey(McqTestsHomeScreen.levelKey(level)),
        );
        expect(tile.enabled, isFalse, reason: level.id);
        expect(tile.onTap, isNull, reason: level.id);
      }
    });

    testWidgets('Intermediate and Advanced open only with real questions',
        (tester) async {
      await tester.pumpWidget(_host(const McqTestsHomeScreen()));
      await tester.pumpAndSettle();

      for (final level in [McqLevel.intermediate, McqLevel.advanced]) {
        final tile = tester.widget<ListTile>(
          find.byKey(McqTestsHomeScreen.levelKey(level)),
        );
        expect(tile.enabled, isTrue, reason: level.id);
        expect(tile.onTap, isNotNull, reason: level.id);
      }
      expect(find.text('12 سؤال در 1 درس'), findsOneWidget);
      expect(find.text('2 سؤال در 1 درس'), findsOneWidget);
    });

    testWidgets('all four levels are disabled when no question exists',
        (tester) async {
      await tester.pumpWidget(
        _host(const McqTestsHomeScreen(), overrides: _fixtureOverrides(empty: true)),
      );
      await tester.pumpAndSettle();

      for (final level in McqLevel.values) {
        final tile = tester.widget<ListTile>(
          find.byKey(McqTestsHomeScreen.levelKey(level)),
        );
        expect(tile.enabled, isFalse, reason: level.id);
        expect(tile.onTap, isNull, reason: level.id);
      }
      expect(find.text('هنوز سؤالی برای این سطح ثبت نشده است'), findsNWidgets(2));
    });

    testWidgets('shows a retry when the content cannot load', (tester) async {
      await tester.pumpWidget(_host(
        const McqTestsHomeScreen(),
        overrides: [
          subjectPacksProvider.overrideWith((ref) async => throw StateError('x')),
        ],
      ));
      await tester.pumpAndSettle();
      expect(find.text('تلاش دوباره'), findsOneWidget);
      final tile = tester.widget<ListTile>(
        find.byKey(McqTestsHomeScreen.levelKey(McqLevel.intermediate)),
      );
      expect(tile.enabled, isFalse);
    });

    testWidgets('level and subject selection reach the practice screen',
        (tester) async {
      _setViewSize(tester, const Size(400, 900));
      final container = ProviderContainer(overrides: _fixtureOverrides());
      addTearDown(container.dispose);
      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: const HamyarApp(),
      ));
      await _pumpFrames(tester);
      final router = container.read(appRouterProvider);

      router.go(AppRoutes.mcqTests);
      await _pumpFrames(tester);
      await tester.tap(
        find.byKey(McqTestsHomeScreen.levelKey(McqLevel.intermediate)),
      );
      await _pumpFrames(tester);
      expect(find.byType(McqSubjectPickerScreen), findsOneWidget);

      final art = tester.widget<ListTile>(
        find.byKey(McqSubjectPickerScreen.subjectKey('art')),
      );
      expect(art.enabled, isFalse);
      expect(find.text('بدون سؤال برای این سطح'), findsOneWidget);

      await tester.tap(find.byKey(McqSubjectPickerScreen.subjectKey('math')));
      await _pumpFrames(tester);
      expect(find.text('1 از 10'), findsOneWidget);
    });
  });

  group('overflow', () {
    for (final size in const [Size(320, 568), Size(360, 800)]) {
      for (final scale in const [1.0, 1.6]) {
        testWidgets(
          'card and hubs fit at ${size.width.toInt()}px, text x$scale',
          (tester) async {
            _setViewSize(tester, size);
            final screens = <String, Widget>{
              'exam card': _cardHost(),
              'MCQ hub': const McqTestsHomeScreen(),
              'MCQ subjects': const McqSubjectPickerScreen(levelId: 'intermediate'),
              'interactive hub': const InteractiveExamsHomeScreen(),
            };
            for (final entry in screens.entries) {
              await tester.pumpWidget(_host(entry.value, textScale: scale));
              await tester.pumpAndSettle();
              expect(tester.takeException(), isNull, reason: entry.key);
            }
          },
        );
      }
    }
  });

  group('existing routes stay compatible', () {
    testWidgets('old routes still resolve and new routes are top-level',
        (tester) async {
      _setViewSize(tester, const Size(400, 1200));
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: const HamyarApp(),
      ));
      await _pumpFrames(tester);
      final router = container.read(appRouterProvider);

      final expectations = <String, Type>{
        AppRoutes.planner: StudyPlannerScreen,
        AppRoutes.ai: AiChatScreen,
        AppRoutes.featureSubjects('quiz'): FeatureSubjectsScreen,
        AppRoutes.subjectDetail('math'): SubjectDetailScreen,
        '${AppRoutes.subjectDetail('math')}/lessons': ContentLibraryScreen,
        AppRoutes.mcqTests: McqTestsHomeScreen,
        AppRoutes.mcqLevel('intermediate'): McqSubjectPickerScreen,
        AppRoutes.interactiveExams: InteractiveExamsHomeScreen,
        AppRoutes.interactiveExam(mixedPlaceholder): TimedCombinedExamScreen,
      };

      for (final entry in expectations.entries) {
        router.go(entry.key);
        await _pumpFrames(tester);
        expect(find.byType(entry.value), findsOneWidget, reason: entry.key);
        expect(find.text('صفحه‌ای پیدا نشد'), findsNothing, reason: entry.key);
      }
    });
  });
}

/// Route id of the mixed exam (kept local so the test file reads on its own).
const String mixedPlaceholder = 'mixed';
