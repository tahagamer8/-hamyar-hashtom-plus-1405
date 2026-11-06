import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hamyar_hashtom_plus/features/ai/presentation/screens/ai_chat_screen.dart';

void main() {
  testWidgets('AI chat screen shows its empty state and input', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: AiChatScreen()),
    );

    expect(find.text('دستیار هوشمند فهمینو'), findsOneWidget);
    expect(find.text('از کجا شروع کنیم؟'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('سؤالت را بنوی...'), findsOneWidget);
  });

  testWidgets('AI chat can start a fresh conversation', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: AiChatScreen()),
    );

    await tester.tap(find.byTooltip('گفت‌وگوی تازه'));
    await tester.pump();

    expect(find.text('از کجا شروع کنیم؟'), findsOneWidget);
  });
}
