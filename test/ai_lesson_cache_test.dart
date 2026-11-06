import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hamyar_hashtom_plus/features/lessons/data/ai_lesson_cache.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('saves and reads an AI-generated supplemental lesson', () async {
    await AiLessonCache.save(
      lessonKey: 'math::0',
      content: 'درسنامهٔ تألیفی فصل عددهای گویا',
    );

    expect(
      await AiLessonCache.read('math::0'),
      'درسنامهٔ تألیفی فصل عددهای گویا',
    );
  });

  test('does not create a cache entry for blank content', () async {
    await AiLessonCache.save(lessonKey: 'math::0', content: '   ');
    expect(await AiLessonCache.read('math::0'), isNull);
  });

  test('deletes a saved lesson without affecting another chapter', () async {
    await AiLessonCache.save(lessonKey: 'math::0', content: 'درسنامهٔ اول');
    await AiLessonCache.save(lessonKey: 'math::1', content: 'درسنامهٔ دوم');

    await AiLessonCache.delete('math::0');

    expect(await AiLessonCache.read('math::0'), isNull);
    expect(await AiLessonCache.read('math::1'), 'درسنامهٔ دوم');
  });

  test('overwrites an existing chapter lesson', () async {
    await AiLessonCache.save(lessonKey: 'science::2', content: 'نسخهٔ اول');
    await AiLessonCache.save(lessonKey: 'science::2', content: 'نسخهٔ دوم');

    expect(await AiLessonCache.read('science::2'), 'نسخهٔ دوم');
  });
}
