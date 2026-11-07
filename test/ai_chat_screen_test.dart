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

void main() {
  testWidgets('Gemini assistant shows lesson selectors and message input', (tester) async {
    await tester.pumpWidget(_testApp());
    await tester.pumpAndSettle();

    expect(find.text('هوش مصنوعی فهمینو'), findsOneWidget);
    expect(find.text('از کجا شروع کنیم؟'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.byType(DropdownButtonFormField<String>), findsOneWidget);
    expect(find.byType(DropdownButtonFormField<int>), findsOneWidget);
    expect(find.byTooltip('ارسال به هوش مصنوعی'), findsOneWidget);
  });

  testWidgets('assistant identifies its online Gemini mode honestly', (tester) async {
    await tester.pumpWidget(_testApp());
    await tester.pumpAndSettle();

    expect(find.textContaining('متصل به Gemini'), findsOneWidget);
    expect(find.textContaining('مدل مولد نیست'), findsNothing);
    expect(find.textContaining('از دستگاه خارج نمی‌شوند'), findsNothing);
  });
}
