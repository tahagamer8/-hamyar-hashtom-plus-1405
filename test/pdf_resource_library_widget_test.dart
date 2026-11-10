import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hamyar_hashtom_plus/features/documents/presentation/screens/pdf_resource_library_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<List<Map<String, dynamic>>> loadMathChapters() async {
    final raw = await rootBundle.loadString('assets/content/subjects/math.json');
    final pack = jsonDecode(raw) as Map<String, dynamic>;
    return (pack['chapters'] as List<dynamic>)
        .cast<Map<String, dynamic>>();
  }

  testWidgets('notes library shows offline PDF and brief description', (tester) async {
    final chapters = await loadMathChapters();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: PdfResourceLibraryScreen(
          subjectId: 'math',
          subjectTitle: 'ریاضی هشتم',
          chapters: chapters,
          kind: PdfResourceKind.notes,
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('جزوه‌های آموزشی؛ فقط فایل PDF'), findsOneWidget);
    expect(find.text('جزوهٔ فصل 1 - فهمینو'), findsOneWidget);
    expect(find.text('مشاهده PDF'), findsWidgets);
  });

  testWidgets('sample library is PDF-only and shows chapter resources', (tester) async {
    final chapters = await loadMathChapters();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: PdfResourceLibraryScreen(
          subjectId: 'math',
          subjectTitle: 'ریاضی هشتم',
          chapters: chapters,
          kind: PdfResourceKind.samples,
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('نمونه‌سؤال‌ها؛ فقط فایل PDF'), findsOneWidget);
    expect(find.text('نمونه‌سؤال فصل 1 - فهمینو'), findsOneWidget);
    expect(find.textContaining('ممکن است با چاپ فعلی کتاب تفاوت داشته باشند'), findsOneWidget);
  });
}
