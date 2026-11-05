import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hamyar_hashtom_plus/app.dart';
import 'package:hamyar_hashtom_plus/core/constants/app_constants.dart';

Future<void> openMathFeature(WidgetTester tester, String feature) async {
  await tester.pumpWidget(const ProviderScope(child: HamyarApp()));
  await tester.pumpAndSettle();
  await tester.tap(find.text('دروس'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('ریاضی').first);
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.text(feature));
  await tester.tap(find.text(feature));
  await tester.pumpAndSettle();
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

  testWidgets('lesson content opens', (tester) async {
    await openMathFeature(tester, 'آموزش فصل‌به‌فصل');
    expect(find.text('عددهای صحیح و گویا'), findsOneWidget);
    expect(find.textContaining('عددهای گویا را می‌توان'), findsOneWidget);
  });

  testWidgets('notes content opens', (tester) async {
    await openMathFeature(tester, 'جزوه و خلاصه');
    expect(find.text('قرینهٔ هر عدد با تغییر علامت آن به دست می‌آید.'), findsOneWidget);
  });

  testWidgets('step-by-step solution opens', (tester) async {
    await openMathFeature(tester, 'گام‌به‌گام');
    expect(find.text('مخرج مشترک ۶ انتخاب می‌کنیم.'), findsOneWidget);
  });

  testWidgets('sample questions display answer key', (tester) async {
    await openMathFeature(tester, 'نمونه‌سؤال');
    expect(find.text('حاصل ۱/۲ + ۱/۴ کدام است؟'), findsOneWidget);
    expect(find.text('پاسخ: ۳/۴'), findsOneWidget);
  });

  testWidgets('quiz checks a correct answer', (tester) async {
    await openMathFeature(tester, 'آزمون');
    await tester.tap(find.text('۳/۴').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('بررسی پاسخ').first);
    await tester.pumpAndSettle();
    expect(find.textContaining('آفرین، پاسخ درست است.'), findsOneWidget);
  });

  testWidgets('search filters the learning catalog', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: HamyarApp()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('جست‌وجو'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'عددهای صحیح');
    await tester.pumpAndSettle();
    expect(find.text('عددهای صحیح و گویا'), findsOneWidget);
  });
}
