import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('video catalogue contains unique HTTPS links on approved hosts', () async {
    final raw = await rootBundle.loadString(
      'assets/content/video_lessons_fa.json',
    );
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    final videos = decoded['videos'] as List<dynamic>;
    final ids = <String>{};
    final subjectIds = <String>{};

    expect(decoded['grade'], 8);
    expect(videos, isNotEmpty);

    for (final value in videos) {
      final video = value as Map<String, dynamic>;
      final id = video['id'] as String;
      final subjectId = video['subjectId'] as String;
      final uri = Uri.parse(video['url'] as String);

      expect(ids.add(id), isTrue, reason: 'Duplicate video id: $id');
      expect(subjectId.trim(), isNotEmpty);
      expect((video['title'] as String).trim(), isNotEmpty);
      expect((video['sourceName'] as String).trim(), isNotEmpty);
      expect(uri.scheme, 'https');
      expect(
        const {'telewebion.net', 'telewebion.ir', 'tv7.ir'},
        contains(uri.host),
      );
      subjectIds.add(subjectId);
    }

    expect(
      subjectIds,
      containsAll(['math', 'science', 'english', 'persian', 'arabic']),
    );
  });
}
