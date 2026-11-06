import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Stores original AI-generated supplemental lessons locally.
/// Cached lessons are never marked as official textbook answers.
class AiLessonCache {
  AiLessonCache._();

  static const _storageKey = 'fahmino_ai_lessons_v1';
  static const _maxStorageBytes = 450 * 1024;
  static const _maxLessonCharacters = 18000;

  static Future<String?> read(String lessonKey) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      final entry = decoded[lessonKey];
      if (entry is! Map<String, dynamic>) return null;
      final text = entry['content'];
      return text is String && text.trim().isNotEmpty ? text : null;
    } catch (_) {
      return null;
    }
  }

  static Future<void> save({
    required String lessonKey,
    required String content,
  }) async {
    final normalizedKey = lessonKey.trim();
    final normalizedContent = content.trim();
    if (normalizedKey.isEmpty || normalizedContent.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final Map<String, dynamic> entries = {};
    final raw = prefs.getString(_storageKey);
    if (raw != null) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) entries.addAll(decoded);
      } catch (_) {
        // Replace a malformed cache instead of making lesson generation fail.
      }
    }

    entries[normalizedKey] = {
      'content': normalizedContent.length > _maxLessonCharacters
          ? normalizedContent.substring(0, _maxLessonCharacters)
          : normalizedContent,
      'createdAt': DateTime.now().toUtc().toIso8601String(),
      'source': 'fahmino_ai_supplementary',
      'verificationStatus': 'not_verified_as_official_textbook_answer',
    };

    while (entries.isNotEmpty &&
        utf8.encode(jsonEncode(entries)).length > _maxStorageBytes) {
      final oldestKey = entries.keys.reduce((oldest, key) {
        final oldDate = DateTime.tryParse(
              (entries[oldest] as Map<String, dynamic>)['createdAt'] as String? ?? '',
            ) ??
            DateTime.fromMillisecondsSinceEpoch(0);
        final currentDate = DateTime.tryParse(
              (entries[key] as Map<String, dynamic>)['createdAt'] as String? ?? '',
            ) ??
            DateTime.fromMillisecondsSinceEpoch(0);
        return currentDate.isBefore(oldDate) ? key : oldest;
      });
      entries.remove(oldestKey);
    }

    await prefs.setString(_storageKey, jsonEncode(entries));
  }

  static Future<void> delete(String lessonKey) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        await prefs.remove(_storageKey);
        return;
      }
      decoded.remove(lessonKey);
      if (decoded.isEmpty) {
        await prefs.remove(_storageKey);
      } else {
        await prefs.setString(_storageKey, jsonEncode(decoded));
      }
    } catch (_) {
      await prefs.remove(_storageKey);
    }
  }
}
