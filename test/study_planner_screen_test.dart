import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hamyar_hashtom_plus/features/study_planner/presentation/screens/study_planner_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('planner saves a new study task and completion state offline',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      const MaterialApp(home: StudyPlannerScreen()),
    );
    await tester.pumpAndSettle();

    expect(find.text('برنامه‌ریز مطالعه'), findsOneWidget);
    expect(find.text('برنامه‌ای ثبت نشده است.'), findsOneWidget);

    await tester.tap(find.text('برنامهٔ جدید'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byType(TextField),
      'مرور فصل اول علوم',
    );
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('علوم تجربی').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('ذخیره برنامه'));
    await tester.pumpAndSettle();

    expect(find.text('مرور فصل اول علوم'), findsOneWidget);
    expect(find.textContaining('علوم تجربی •'), findsOneWidget);

    await tester.tap(find.byType(Checkbox).first);
    await tester.pumpAndSettle();

    final preferences = await SharedPreferences.getInstance();
    final stored = preferences.getStringList('fahmino_study_tasks_v1');
    expect(stored, isNotNull);
    expect(stored, hasLength(1));
    final task = jsonDecode(stored!.single) as Map<String, dynamic>;
    expect(task['title'], 'مرور فصل اول علوم');
    expect(task['subject'], 'علوم تجربی');
    expect(task['completed'], isTrue);
  });

  testWidgets('planner restores saved exam date and task after reopening',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'fahmino_next_exam_date_v1': '2026-11-20T00:00:00.000',
      'fahmino_study_tasks_v1': [
        jsonEncode({
          'id': 'task-1',
          'title': 'تمرین معادله',
          'subject': 'ریاضی',
          'date': '2026-11-12T00:00:00.000',
          'completed': false,
        }),
      ],
    });

    await tester.pumpWidget(const MaterialApp(home: StudyPlannerScreen()));
    await tester.pumpAndSettle();

    expect(find.text('تمرین معادله'), findsOneWidget);
    expect(find.textContaining('ریاضی •'), findsOneWidget);
    expect(find.text('2026/11/20'), findsOneWidget);
  });
}
