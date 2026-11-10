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
        "lessonContent": "درسنامهٔ کامل عددهای گویا: عدد گویا را می‌توان به شکل a/b نوشت که a و b عدد صحیح‌اند و b صفر نیست. برای جمع و تفریق کسرها ابتدا مخرج مشترک پیدا می‌کنیم. سپس صورت‌ها را با توجه به علامت‌ها جمع یا تفریق می‌کنیم و مخرج را ثابت نگه می‌داریم. در پایان، اگر ممکن بود کسر را ساده می‌کنیم. هنگام حل مسئله، اول داده‌ها و خواسته را جدا کن و بعد روش مناسب را انتخاب کن.",
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
        "workedExamples": [
          {
            "title": "جمع کسرها",
            "problem": "۱/۲ + ۱/۴",
            "answer": "۳/۴",
            "explanation": "ابتدا ۱/۲ را به ۲/۴ تبدیل می‌کنیم و سپس صورت‌ها را جمع می‌کنیم.",
            "steps": ["مخرج مشترک ۴ انتخاب می‌کنیم.", "۱/۲ را به ۲/۴ تبدیل می‌کنیم.", "۲/۴ + ۱/۴ = ۳/۴"]
          },
          {
            "title": "تمرین همراه",
            "problem": "حاصل ۱/۲ + ۱/۴ کدام است؟",
            "answer": "۳/۴",
            "explanation": "۱/۲ برابر ۲/۴ است؛ پس ۲/۴ + ۱/۴ برابر ۳/۴ می‌شود.",
            "steps": ["مخرج‌ها را به ۴ تبدیل کن.", "صورت‌های ۲ و ۱ را جمع کن.", "پاسخ ۳/۴ است."]
          }
        ],
        "chapterExam": [
          {
            "question": "حاصل ۱/۲ + ۱/۴ کدام است؟",
            "options": ["۱/۲", "۳/۴", "۱", "۱/۴"],
            "answer": 1,
            "explanation": "۱/۲ برابر ۲/۴ است؛ پس ۲/۴ + ۱/۴ برابر ۳/۴ می‌شود."
          },
          {
            "question": "درست یا نادرست: مخرج یک کسر نباید صفر باشد.",
            "questionType": "true_false",
            "answer": "درست",
            "explanation": "تقسیم بر صفر تعریف نشده است."
          }
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

  String tutorMessages(WidgetTester tester) => tester
      .widgetList<SelectableText>(find.byType(SelectableText))
      .map((widget) => widget.data ?? '')
      .join('\n');

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

    await tester.ensureVisible(find.text('آموزش فصل'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('آموزش فصل'));
    await tester.pumpAndSettle();

    expect(tutorMessages(tester), contains('عددهای گویا به شکل کسر نوشته می‌شوند'));
    expect(tutorMessages(tester), contains('حل مرحله‌به‌مرحله'));
    expect(tutorMessages(tester), contains('مخرج مشترک ۴ انتخاب می‌کنیم.'));
    expect(tutorMessages(tester), contains('مراقب این اشتباه‌ها باش'));
    expect(tutorMessages(tester), contains('درسنامهٔ کامل عددهای گویا'));
  });

  testWidgets('private tutor runs an interactive quiz and explains the answer',
      (tester) async {
    await openTutor(tester);

    await tester.ensureVisible(find.text('آزمون کوتاه'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('آزمون کوتاه'));
    await tester.pumpAndSettle();

    expect(tutorMessages(tester), contains('حاصل ۱/۲ + ۱/۴ کدام است؟'));
    expect(tutorMessages(tester), contains('پاسخت کدام گزینه است؟'));

    await tester.enterText(find.byType(TextField), 'ب');
    await tester.tap(find.byTooltip('ارسال پرسش'));
    await tester.pumpAndSettle();

    expect(tutorMessages(tester), contains('آفرین، این پاسخ درست است.'));
    expect(
      tutorMessages(tester),
      contains('۱/۲ برابر ۲/۴ است؛ پس ۲/۴ + ۱/۴ برابر ۳/۴ می‌شود.'),
    );
    expect(tutorMessages(tester), contains('درست یا نادرست: مخرج یک کسر نباید صفر باشد.'));
    await tester.enterText(find.byType(TextField), 'الف');
    await tester.tap(find.byTooltip('ارسال پرسش'));
    await tester.pumpAndSettle();
    expect(tutorMessages(tester), contains('2 پاسخ درست از 2 سؤال'));
  });

  testWidgets('private tutor asks for a valid option before grading a quiz',
      (tester) async {
    await openTutor(tester);

    await tester.ensureVisible(find.text('آزمون کوتاه'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('آزمون کوتاه'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'شاید');
    await tester.tap(find.byTooltip('ارسال پرسش'));
    await tester.pumpAndSettle();

    expect(tutorMessages(tester), contains('با شمارهٔ گزینه یا حرف الف، ب، پ یا ت'));
    expect(tutorMessages(tester), contains('پاسخت کدام گزینه است؟'));
  });
}
