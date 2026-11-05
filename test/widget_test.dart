import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hamyar_hashtom_plus/app.dart';
import 'package:hamyar_hashtom_plus/core/constants/app_constants.dart';
import 'package:hamyar_hashtom_plus/features/content/presentation/screens/content_library_screen.dart';
import 'package:hamyar_hashtom_plus/features/search/presentation/screens/search_screen.dart';

Future<void> openMathContent(WidgetTester tester, String featureId) async {
  await tester.pumpWidget(
    MaterialApp(
      home: ContentLibraryScreen(subjectId: 'math', featureId: featureId),
    ),
  );
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(seconds: 1)),
  );
  await tester.pump();
}

void main() {
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

  testWidgets('lesson content loads from bundled catalog', (tester) async {
    await openMathContent(tester, 'lessons');
    expect(find.text('عددهای صحیح و گویا'), findsOneWidget);
    expect(find.textContaining('عددهای گویا را می‌توان'), findsOneWidget);
  });

  testWidgets('notes content loads from bundled catalog', (tester) async {
    await openMathContent(tester, 'notes');
    expect(find.text('قرینهٔ هر عدد با تغییر علامت آن به دست می‌آید.'), findsOneWidget);
  });

  testWidgets('step-by-step solution loads from bundled catalog', (tester) async {
    await openMathContent(tester, 'solutions');
    expect(find.text('مخرج مشترک ۶ انتخاب می‌کنیم.'), findsOneWidget);
  });

  testWidgets('sample questions display answer key', (tester) async {
    await openMathContent(tester, 'sampleExams');
    expect(find.text('حاصل ۱/۲ + ۱/۴ کدام است؟'), findsOneWidget);
    expect(find.text('پاسخ: ۳/۴'), findsOneWidget);
  });

  testWidgets('quiz checks a correct answer', (tester) async {
    await openMathContent(tester, 'quiz');
    await tester.tap(find.text('۳/۴').first);
    await tester.pump();
    await tester.tap(find.text('بررسی پاسخ').first);
    await tester.pump();
    expect(find.textContaining('آفرین، پاسخ درست است.'), findsOneWidget);
  });

  testWidgets('search filters the learning catalog', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SearchScreen()));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(seconds: 1)),
    );
    await tester.pump();
    expect(find.byType(TextField), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'عددهای صحیح');
    await tester.pump();
    expect(find.text('عددهای صحیح و گویا'), findsOneWidget);
  });
}
