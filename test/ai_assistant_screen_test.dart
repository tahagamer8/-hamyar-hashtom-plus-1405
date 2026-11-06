import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hamyar_hashtom_plus/features/ai_assistant/presentation/screens/ai_assistant_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('AI assistant loads the grade-eight chapter selector', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: AiAssistantScreen()),
    );
    await tester.pumpAndSettle();

    expect(find.text('پایه و فصل موردنظر را انتخاب کن'), findsOneWidget);
    expect(find.byType(DropdownButtonFormField<String>), findsOneWidget);
    expect(find.text('برای پاسخ دقیق‌تر، زمینهٔ کتاب را مشخص کن'), findsOneWidget);
  });
}
