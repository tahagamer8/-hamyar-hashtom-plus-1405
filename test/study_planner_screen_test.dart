import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hamyar_hashtom_plus/features/planner/presentation/screens/study_planner_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('adds and persists a study task and tracks completion', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: StudyPlannerScreen(),
    ));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'مرور فصل اول علوم');
    await tester.tap(find.text('افزودن به برنامه'));
    await tester.pumpAndSettle();

    expect(find.text('مرور فصل اول علوم'), findsOneWidget);
    expect(find.text('۰ از ۱ کار انجام شده'), findsNothing);
    expect(find.text('0 از 1 کار انجام شده'), findsOneWidget);

    await tester.tap(find.byType(CheckboxListTile).first);
    await tester.pumpAndSettle();

    expect(find.text('1 از 1 کار انجام شده'), findsOneWidget);

    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString('fahmino.study_planner.tasks.v1');
    expect(stored, isNotNull);
    expect(stored, contains('مرور فصل اول علوم'));
    expect(stored, contains('"done":true'));
  });
}
