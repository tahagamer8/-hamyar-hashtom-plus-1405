import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hamyar_hashtom_plus/features/ai/presentation/screens/ai_chat_screen.dart';

void main() {
  testWidgets('offline helper shows lesson selectors and input', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: AiChatScreen()),
    );
    await tester.pumpAndSettle();

    expect(find.text('دستیار آفلاین فهمینو'), findsOneWidget);
    expect(find.text('از کجا شروع کنیم؟'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('درس'), findsOneWidget);
    expect(find.text('فصل یا درس'), findsOneWidget);
  });

  testWidgets('offline helper searches the selected local chapter', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: AiChatScreen()),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'عددهای گویا چیست؟');
    await tester.tap(find.byTooltip('جست‌وجوی محلی'));
    await tester.pumpAndSettle();

    expect(find.textContaining('راهنمای آفلاین فهمینو'), findsOneWidget);
    expect(find.textContaining('عددهای گویا'), findsWidgets);
    expect(find.textContaining('مدل هوش مصنوعی مولد نیست'), findsOneWidget);
  });
}
