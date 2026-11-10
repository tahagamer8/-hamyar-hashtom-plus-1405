import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hamyar_hashtom_plus/features/documents/presentation/screens/pdf_resource_library_screen.dart';

class _PdfLibraryAssetBundle extends CachingAssetBundle {
  static const _resources = '''
  {
    "schemaVersion": 1,
    "subjects": {
      "math": {
        "notes": [
          {
            "chapterIndex": 0,
            "title": "جزوه تکمیلی ریاضی",
            "description": "مرور نکته‌ها و مثال‌ها.",
            "source": "پادرس",
            "url": "https://static.paadars.com/files/sample.pdf"
          }
        ],
        "samples": [
          {
            "chapterIndex": 0,
            "title": "نمونه‌سؤال تکمیلی ریاضی",
            "description": "تمرین بیشتر.",
            "source": "همیار",
            "url": "https://dl.hamyar.me/sample.pdf"
          }
        ]
      }
    }
  }
  ''';

  @override
  Future<ByteData> load(String key) async {
    if (key != 'assets/content/pdf_resources.json') {
      throw FlutterError('Unexpected test asset: $key');
    }
    return ByteData.sublistView(
      Uint8List.fromList(utf8.encode(_resources)),
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const chapters = <Map<String, dynamic>>[
    {
      'title': 'عددهای صحیح و گویا',
      'summary': 'مرور فصل اول ریاضی.',
    },
  ];

  Future<void> pumpResourceScreen(WidgetTester tester) async {
    // Do not use pumpAndSettle: the loading indicator is intentionally
    // indeterminate while the asset future is resolving.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();
  }

  Future<void> showLibrary(
    WidgetTester tester, {
    required PdfResourceKind kind,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: DefaultAssetBundle(
          bundle: _PdfLibraryAssetBundle(),
          child: Scaffold(
            body: PdfResourceLibraryScreen(
              subjectId: 'math',
              subjectTitle: 'ریاضی هشتم',
              chapters: chapters,
              kind: kind,
            ),
          ),
        ),
      ),
    );
    await pumpResourceScreen(tester);
  }

  testWidgets('notes library shows an offline PDF and brief description',
      (tester) async {
    await showLibrary(tester, kind: PdfResourceKind.notes);

    expect(find.text('جزوه‌های آموزشی؛ فقط فایل PDF'), findsOneWidget);
    expect(find.text('جزوهٔ فصل 1 - فهمینو'), findsOneWidget);
    expect(find.text('مشاهده PDF'), findsWidgets);
    expect(find.text('جزوه تکمیلی ریاضی'), findsOneWidget);
  });

  testWidgets('sample library is PDF-only and shows chapter resources',
      (tester) async {
    await showLibrary(tester, kind: PdfResourceKind.samples);

    expect(find.text('نمونه‌سؤال‌ها؛ فقط فایل PDF'), findsOneWidget);
    expect(find.text('نمونه‌سؤال فصل 1 - فهمینو'), findsOneWidget);
    expect(
      find.textContaining('ممکن است با چاپ فعلی کتاب تفاوت داشته باشند'),
      findsOneWidget,
    );
    expect(find.text('نمونه‌سؤال تکمیلی ریاضی'), findsOneWidget);
  });
}
