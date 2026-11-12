import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hamyar_hashtom_plus/features/quiz/presentation/screens/sample_question_library_screen.dart';

void main() {
  const chapters = <Map<String, dynamic>>[
    {
      'title': 'تمرین ترکیبی',
      'questions': [
        {
          'question': 'چرا برای جمع کسرها مخرج مشترک می‌گیریم؟',
          'questionType': 'short_answer',
          'answer': 'برای هم‌اندازه کردن واحدها و جمع صورت‌ها.',
          'explanation': 'مخرج مشترک نشان می‌دهد قسمت‌های کسر هم‌اندازه شده‌اند.',
        },
        {
          'question': 'درست یا نادرست: مخرج کسر می‌تواند صفر باشد.',
          'questionType': 'true_false',
          'answer': 'نادرست',
          'explanation': 'تقسیم بر صفر تعریف نشده است.',
        },
      ],
      'essayQuestions': [
        {
          'question': 'توضیح بده چرا برای جمع کسرها باید واحدهای هم‌اندازه داشته باشیم و یک مثال بساز.',
          'questionType': 'essay',
          'answerGuidelines': ['مخرج مشترک واحدها را هم‌اندازه می‌کند.'],
          'evaluationCriteria': ['توضیح مفهوم', 'ارائهٔ مثال', 'نتیجه‌گیری'],
        },
      ],
    },
  ];

  testWidgets('sample question library checks written answers', (tester) async {
    tester.view.physicalSize = const Size(900, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SampleQuestionLibraryScreen(
            subjectId: 'math',
            subjectTitle: 'ریاضی',
            chapters: chapters,
          ),
        ),
      ),
    );

    final response = find.byKey(const ValueKey('sample-short-answer-1'));
    await tester.ensureVisible(response);
    await tester.enterText(response, 'برای هم‌اندازه کردن واحدها');
    await tester.pump();

    final checkWritten = find.byKey(const ValueKey('sample-check-1'));
    expect(tester.widget<FilledButton>(checkWritten).onPressed, isNotNull);
    await tester.tap(checkWritten);
    await tester.pump();

    expect(find.textContaining('پاسخ پیشنهادی: برای هم‌اندازه کردن واحدها و جمع صورت‌ها.'), findsOneWidget);
    expect(find.textContaining('مخرج مشترک نشان می‌دهد'), findsOneWidget);
  });

  testWidgets('sample question library supports essay answers and rubric', (tester) async {
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SampleQuestionLibraryScreen(
            subjectId: 'math',
            subjectTitle: 'ریاضی',
            chapters: chapters,
          ),
        ),
      ),
    );

    final response = find.byKey(const ValueKey('sample-essay-answer-3'));
    await tester.ensureVisible(response);
    await tester.enterText(response, 'چون باید قسمت‌ها هم‌اندازه باشند؛ مثلاً...');
    await tester.pump();

    final submit = find.byKey(const ValueKey('sample-check-3'));
    expect(tester.widget<FilledButton>(submit).onPressed, isNotNull);
    await tester.tap(submit);
    await tester.pump();

    expect(find.textContaining('این پرسش پاسخ یکتای کوتاه ندارد'), findsOneWidget);
    expect(find.text('مخرج مشترک واحدها را هم‌اندازه می‌کند.'), findsOneWidget);
    expect(find.text('ارائهٔ مثال'), findsOneWidget);
  });

  testWidgets('sample question library checks true-false answers', (tester) async {
    tester.view.physicalSize = const Size(900, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SampleQuestionLibraryScreen(
            subjectId: 'math',
            subjectTitle: 'ریاضی',
            chapters: chapters,
          ),
        ),
      ),
    );

    final falseChoice = find.widgetWithText(ChoiceChip, 'نادرست');
    await tester.ensureVisible(falseChoice);
    await tester.tap(falseChoice);
    await tester.pump();

    final check = find.byKey(const ValueKey('sample-check-2'));
    expect(tester.widget<FilledButton>(check).onPressed, isNotNull);
    await tester.tap(check);
    await tester.pump();

    expect(find.text('آفرین، پاسخ درست است.'), findsOneWidget);
    expect(find.textContaining('تقسیم بر صفر تعریف نشده است.'), findsOneWidget);
  });
}
