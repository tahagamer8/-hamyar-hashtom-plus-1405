import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hamyar_hashtom_plus/features/ai_assistant/presentation/screens/ai_assistant_screen.dart';

class _CatalogAssetBundle extends CachingAssetBundle {
  static const _catalog = '''
  {
    "math": {
      "title": "ریاضی",
      "chapters": [
        {
          "title": "عددهای صحیح و گویا",
          "summary": "عددهای گویا به شکل کسر نوشته می‌شوند.",
          "points": ["مخرج کسر نباید صفر باشد."],
          "example": "۱/۲ + ۱/۴ = ۳/۴",
          "solutionSteps": ["مخرج مشترک می‌گیریم."]
        }
      ]
    }
  }
  ''';

  @override
  Future<ByteData> load(String key) async {
    if (key != 'assets/content/catalog_fa.json') {
      throw FlutterError('Unexpected asset: $key');
    }
    return ByteData.sublistView(Uint8List.fromList(utf8.encode(_catalog)));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('AI assistant loads the grade-eight chapter selector', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: DefaultAssetBundle(
          bundle: _CatalogAssetBundle(),
          child: const AiAssistantScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('پایه و فصل موردنظر را انتخاب کن'), findsOneWidget);
    expect(find.byType(DropdownButtonFormField<String>), findsOneWidget);
    expect(find.text('برای پاسخ دقیق‌تر، زمینهٔ کتاب را مشخص کن'), findsOneWidget);
    expect(find.text('یادگیری، با گفت‌وگو ساده‌تر می‌شود'), findsOneWidget);
    expect(find.text('از کجا شروع کنیم؟'), findsOneWidget);
    expect(find.text('آزمون چالشی'), findsOneWidget);
    expect(find.text('حل مسئلهٔ ریاضی'), findsOneWidget);
  });
}
