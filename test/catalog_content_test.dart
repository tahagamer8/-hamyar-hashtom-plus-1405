import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('English workbook questions match their prompts and explanations', () async {
    final raw = await rootBundle.loadString('assets/content/catalog_fa.json');
    final catalog = jsonDecode(raw) as Map<String, dynamic>;
    final english = catalog['english'] as Map<String, dynamic>;
    final firstEnglishLesson = (english['chapters'] as List<dynamic>)[0];
    final nationalityQuestion = (firstEnglishLesson['questions'] as List<dynamic>)[0];
    expect(nationalityQuestion['question'], contains('Which nationality describes'));
    expect(nationalityQuestion['options'][nationalityQuestion['answer']], 'Canadian');
    final abilitiesLesson = (english['chapters'] as List<dynamic>)[2];
    final cantQuestion = (abilitiesLesson['questions'] as List<dynamic>)[1];
    expect(cantQuestion['question'], contains("can't"));
    expect(cantQuestion['options'][cantQuestion['answer']], 'نمی‌تواند');

    final workbook = catalog['english_workbook'] as Map<String, dynamic>;
    final lessons = workbook['chapters'] as List<dynamic>;

    final nationality = lessons[0]['questions'] as List<dynamic>;
    expect(nationality[0]['question'], contains('Which question asks someone'));
    expect(nationality[0]['options'][nationality[0]['answer']], 'Where are you from?');
    expect(nationality[1]['question'], contains('nationality for a person from Kuwait'));
    expect(nationality[1]['options'][nationality[1]['answer']], 'Kuwaiti');

    final abilities = lessons[2]['questions'] as List<dynamic>;
    expect(abilities[0]['options'][abilities[0]['answer']], 'play');
    expect(abilities[1]['options'][abilities[1]['answer']], 'نمی‌تواند');

    final city = lessons[4]['questions'] as List<dynamic>;
    expect(city[0]['question'], contains('There'));
    expect(city[0]['options'][city[0]['answer']], 'is');
    expect(city[1]['options'][city[1]['answer']], 'روبه‌رو');
  });
}
