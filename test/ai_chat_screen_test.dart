import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hamyar_hashtom_plus/features/ai/presentation/screens/ai_chat_screen.dart';

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
      "commonMistakes": ["در جمع کسرها ابتدا مخرج مشترک بگیر."],
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

class _TestAssetBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async {
    if (key != 'assets/content/catalog_fa.json') {
      throw FlutterError('Unexpected test asset: $key');
    }
    return ByteData.sublistView(
      Uint8List.fromList(utf8.encode(_testCatalog)),
    );
  }
}

Widget _testApp() => MaterialApp(
      home: DefaultAssetBundle(
        bundle: _TestAssetBundle(),
        child: const AiChatScreen(),
      ),
    );

Future<void> _pumpUiFrames(WidgetTester tester) async {
  // Bounded frame pumping avoids hanging forever on repeating animations.
  await tester.pump();
  for (var i = 0; i < 7; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  testWidgets('offline study guide shows lesson selectors and message input', (tester) async {
    await tester.pumpWidget(_testApp());
    await _pumpUiFrames(tester);

    expect(find.text('راهنمای درسی فهمینو'), findsOneWidget);
    expect(find.text('از کجا شروع کنیم؟'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.byType(DropdownButtonFormField<String>), findsOneWidget);
    expect(find.byType(DropdownButtonFormField<int>), findsOneWidget);
    expect(find.byTooltip('پاسخ از محتوای فهمینو'), findsOneWidget);
    expect(find.textContaining('پرسش‌ها از دستگاه خارج نمی‌شوند'), findsOneWidget);
  });

  testWidgets('offline guide answers from the selected chapter without a network call', (tester) async {
    await tester.pumpWidget(_testApp());
    await _pumpUiFrames(tester);

    await tester.enterText(find.byType(TextField), 'عددهای گویا چیست؟');
    await tester.tap(find.byTooltip('پاسخ از محتوای فهمینو'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.textContaining('عددهای گویا را می‌توان به صورت کسر نوشت.'), findsOneWidget);
    expect(find.textContaining('پاسخ‌ساز اینترنتی نیست'), findsOneWidget);
  });

  testWidgets('offline guide can show chapter-specific common mistakes', (tester) async {
    await tester.pumpWidget(_testApp());
    await _pumpUiFrames(tester);

    await tester.enterText(find.byType(TextField), 'اشتباهات رایج کسرها چیست؟');
    await tester.tap(find.byTooltip('پاسخ از محتوای فهمینو'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.textContaining('در جمع کسرها ابتدا مخرج مشترک بگیر.'), findsOneWidget);
  });
}
