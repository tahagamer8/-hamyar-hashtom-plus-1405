import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hamyar_hashtom_plus/app.dart';
import 'package:hamyar_hashtom_plus/core/constants/app_constants.dart';

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

  testWidgets('subject sections open learning content', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: HamyarApp()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('دروس'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ریاضی').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('آموزش فصل‌به‌فصل'));
    await tester.pumpAndSettle();
    expect(find.text('عددهای صحیح و گویا'), findsOneWidget);
  });
}
