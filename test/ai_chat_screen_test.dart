import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hamyar_hashtom_plus/features/ai/presentation/screens/ai_chat_screen.dart';

class _TutorAssetBundle extends CachingAssetBundle {
  static const _catalog = '''
  {
    "math": {
      "title": "ریاضی هشتم",
      "chapters": []
    }
  }
  ''';

  static const _mathPack = '''
  {
    "schemaVersion": 1,
    "subjectId": "math",
    "title": "ریاضی هشتم",
    "chapters": [
      {
        "title": "عددهای صحیح و گویا",
        "summary": "عددهای گویا به شکل کسر نوشته می‌شوند و مخرج آن‌ها نباید صفر باشد.",
        "points": [
          "مخرج کسر نباید صفر باشد.",
          "برای جمع کسرها ابتدا مخرج مشترک می‌گیریم."
        ],
        "example": "۱/۲ + ۱/۴ = ۳/۴",
        "solutionSteps": [
          "مخرج مشترک ۴ انتخاب می‌کنیم.",
          "۱/۲ را به ۲/۴ تبدیل می‌کنیم.",
          "۲/۴ + ۱/۴ = ۳/۴"
        ],
        "commonMistakes": [
          "صورت و مخرج را بدون مخرج مشترک با هم جمع نکن."
        ],
        "questions": [
          {
            "question": "حاصل ۱/۲ + ۱/۴ کدام است؟",
            "options": ["۱/۲", "۳/۴", "۱", "۱/۴"],
            "answer": 1,
            "explanation": "۱/۲ برابر ۲/۴ است؛ پس ۲/۴ + ۱/۴ برابر ۳/۴ می‌شود."
          }
        ],
        "advancedQuestions": []
      }
    ]
  }
  ''';

  @override
  Future<ByteData> load(String key) async {
    final String? value = switch (key) {
      'assets/content/catalog_fa.json' => _catalog,
      'assets/content/subjects/math.json' => _mathPack,
      _ => null,
    };
    if (value == null) {
      throw FlutterError('Unexpected tutor test asset: $key');
    }
    return ByteData.sublistView(Uint8List.fromList(utf8.encode(value)));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> openTutor(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: DefaultAssetBundle(
          bundle: _TutorAssetBundle(),
          child: const AiChatScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('private tutor teaches a selected chapter from local content',
      (tester) async {
    await openTutor(tester);

    expect(find.text('معلم خصوصی فهمینو'), findsOneWidget);
    expect(find.text('آموزش فصل'), findsOneWidget);

    await tester.tap(find.text('آموزش فصل'));
    await tester.pumpAndSettle();

    expect(find.textContaining('عددهای گویا به شکل کسر نوشته می‌شوند'), findsOneWidget);
    expect(find.textContaining('حل مرحله‌به‌مرحله'), findsOneWidget);
    expect(find.textContaining('مخرج مشترک ۴ انتخاب می‌کنیم.'), findsOneWidget);
    expect(find.textContaining('مراقب این اشتباه‌ها باش'), findsOneWidget);
  });

  testWidgets('private tutor runs an interactive quiz and explains the answer',
      (tester) async {
    await openTutor(tester);

    await tester.tap(find.text('آزمون کوتاه'));
    await tester.pumpAndSettle();

    expect(find.textContaining('حاصل ۱/۲ + ۱/۴ کدام است؟'), findsOneWidget);
    expect(find.textContaining('پاسخت کدام گزینه است؟'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'ب');
    await tester.tap(find.byTooltip('ارسال پرسش'));
    await tester.pumpAndSettle();

    expect(find.textContaining('آفرین، این پاسخ درست است.'), findsOneWidget);
    expect(
      find.textContaining('۱/۲ برابر ۲/۴ است؛ پس ۲/۴ + ۱/۴ برابر ۳/۴ می‌شود.'),
      findsOneWidget,
    );
    expect(find.textContaining('۱ پاسخ درست از ۱ سؤال'), findsOneWidget);
  });

  testWidgets('private tutor asks for a valid option before grading a quiz',
      (tester) async {
    await openTutor(tester);

    await tester.tap(find.text('آزمون کوتاه'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'شاید');
    await tester.tap(find.byTooltip('ارسال پرسش'));
    await tester.pumpAndSettle();

    expect(find.textContaining('با شمارهٔ گزینه یا حرف الف، ب، پ یا ت'), findsOneWidget);
    expect(find.textContaining('پاسخت کدام گزینه است؟'), findsOneWidget);
  });
}
