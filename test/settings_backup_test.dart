import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hamyar_hashtom_plus/features/settings/presentation/screens/settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> _backup(Map<String, dynamic> data) => {
      'format': 'fahmino_local_backup',
      'schemaVersion': 1,
      'createdAt': '2026-11-10T12:00:00.000Z',
      'data': data,
    };

Future<void> _openSettings(WidgetTester tester) async {
  await tester.pumpWidget(
    const ProviderScope(
      child: MaterialApp(home: SettingsScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _pasteAndRestore(
  WidgetTester tester,
  Map<String, dynamic> backup,
) async {
  await tester.tap(find.text('بازیابی'));
  await tester.pumpAndSettle();
  await tester.enterText(
    find.byType(TextField),
    jsonEncode(backup),
  );
  await tester.tap(find.text('بررسی پشتیبان'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('بازیابی').last);
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('settings restores valid local study data from a backup',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'fahmino_favorites_v1': <String>['old::bookmark'],
    });
    final task = jsonEncode({
      'id': 'task-1',
      'title': 'مرور علوم',
      'subject': 'علوم تجربی',
      'date': '2026-11-12T00:00:00.000',
      'completed': false,
    });
    final mistake = jsonEncode({
      'date': '2026-11-10T12:00:00.000',
      'subjectTitle': 'ریاضی',
      'examTitle': 'آزمون فصل',
      'chapter': 'فصل اول',
      'question': 'حاصل چیست؟',
      'selectedAnswer': '۱/۲',
      'correctAnswer': '۳/۴',
      'explanation': 'مخرج مشترک بگیر.',
    });
    await _openSettings(tester);

    await _pasteAndRestore(tester, _backup({
      'fahmino_favorites_v1': ['math::عددهای گویا'],
      'fahmino_learning_progress_v1': ['math::عددهای گویا'],
      'fahmino_theme_mode': 'dark',
      'fahmino_next_exam_date_v1': '2026-11-20T00:00:00.000',
      'fahmino_study_tasks_v1': [task],
      'fahmino_wrong_answers_v1': [mistake],
      'fahmino_exam_history_math': [
        jsonEncode({
          'date': '2026-11-10T12:00:00.000',
          'score': 4,
          'total': 5,
          'percent': 80,
        }),
      ],
    }));

    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getStringList('fahmino_favorites_v1'),
        ['math::عددهای گویا']);
    expect(preferences.getStringList('fahmino_learning_progress_v1'),
        ['math::عددهای گویا']);
    expect(preferences.getString('fahmino_theme_mode'), 'dark');
    expect(preferences.getString('fahmino_next_exam_date_v1'),
        '2026-11-20T00:00:00.000');
    expect(preferences.getStringList('fahmino_study_tasks_v1'), [task]);
    expect(preferences.getStringList('fahmino_wrong_answers_v1'), [mistake]);
    expect(preferences.getStringList('fahmino_exam_history_math'), hasLength(1));
    expect(find.text('پشتیبان با موفقیت بازیابی شد.'), findsOneWidget);
  });

  testWidgets('settings rejects unsupported backup keys and preserves current data',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'fahmino_favorites_v1': <String>['keep::this'],
    });
    await _openSettings(tester);

    await tester.tap(find.text('بازیابی'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextField),
      jsonEncode(_backup({
        'fahmino_favorites_v1': ['replace::this'],
        'unknown_sensitive_key': ['should-not-be-imported'],
      })),
    );
    await tester.tap(find.text('بررسی پشتیبان'));
    await tester.pumpAndSettle();

    expect(find.text('تأیید بازیابی'), findsNothing);
    expect(find.textContaining('ساختار پشتیبان معتبر نیست'), findsOneWidget);
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getStringList('fahmino_favorites_v1'), ['keep::this']);
    expect(preferences.containsKey('unknown_sensitive_key'), isFalse);
  });

  testWidgets('settings rejects malformed nested study-task records',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await _openSettings(tester);

    await tester.tap(find.text('بازیابی'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextField),
      jsonEncode(_backup({
        'fahmino_study_tasks_v1': [
          jsonEncode({
            'title': 'بدون تاریخ معتبر',
            'subject': 'علوم',
            'date': 'not-a-date',
            'completed': false,
          }),
        ],
      })),
    );
    await tester.tap(find.text('بررسی پشتیبان'));
    await tester.pumpAndSettle();

    expect(find.text('تأیید بازیابی'), findsNothing);
    expect(find.textContaining('ساختار پشتیبان معتبر نیست'), findsOneWidget);
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getStringList('fahmino_study_tasks_v1'), isNull);
  });
}
