import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hamyar_hashtom_plus/features/quiz/presentation/screens/mistake_review_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> _mistake({
  required String subject,
  required String question,
  required String correct,
}) => {
      'date': '2026-11-10T12:00:00.000',
      'subjectTitle': subject,
      'examTitle': 'آزمون فصل',
      'chapter': 'فصل اول',
      'question': question,
      'selectedAnswer': 'بی‌پاسخ',
      'correctAnswer': correct,
      'explanation': 'این توضیح برای مرور دوبارهٔ مفهوم است.',
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('mistake review displays wrong answers and explanations',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'fahmino_wrong_answers_v1': [
        jsonEncode(_mistake(
          subject: 'ریاضی',
          question: 'حاصل ۱/۲ + ۱/۴ چیست؟',
          correct: '۳/۴',
        )),
      ],
    });

    await tester.pumpWidget(
      const MaterialApp(home: MistakeReviewScreen()),
    );
    await tester.pumpAndSettle();

    expect(find.text('مرور اشتباهات'), findsOneWidget);
    expect(find.text('حاصل ۱/۲ + ۱/۴ چیست؟'), findsOneWidget);
    expect(find.text('پاسخ انتخابی: بی‌پاسخ'), findsOneWidget);
    expect(find.text('پاسخ درست: ۳/۴'), findsOneWidget);
    expect(find.text('این توضیح برای مرور دوبارهٔ مفهوم است.'), findsOneWidget);
  });

  testWidgets('mistake review filters by subject and clears history',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'fahmino_wrong_answers_v1': [
        jsonEncode(_mistake(
          subject: 'ریاضی',
          question: 'پرسش ریاضی',
          correct: 'پاسخ ریاضی',
        )),
        jsonEncode(_mistake(
          subject: 'علوم',
          question: 'پرسش علوم',
          correct: 'پاسخ علوم',
        )),
      ],
    });

    await tester.pumpWidget(
      const MaterialApp(home: MistakeReviewScreen()),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(DropdownButtonFormField<String?>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ریاضی').last);
    await tester.pumpAndSettle();

    expect(find.text('پرسش ریاضی'), findsOneWidget);
    expect(find.text('پرسش علوم'), findsNothing);

    await tester.tap(find.byTooltip('پاک کردن سابقه'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('پاک کردن'));
    await tester.pumpAndSettle();

    expect(find.text('فعلاً اشتباهی ثبت نشده'), findsOneWidget);
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getStringList('fahmino_wrong_answers_v1'), isNull);
  });
}
