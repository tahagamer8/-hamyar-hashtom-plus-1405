import 'dart:convert';

import 'package:hamyar_hashtom_plus/features/quiz/domain/mcq_level.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// One finished multiple-choice practice session.
class McqAttempt {
  const McqAttempt({
    required this.date,
    required this.score,
    required this.total,
  });

  final DateTime date;
  final int score;
  final int total;

  int get percent => total == 0 ? 0 : (score * 100 / total).round();

  Map<String, dynamic> toJson() => {
        'date': date.toIso8601String(),
        'score': score,
        'total': total,
      };

  static McqAttempt? tryFromJson(Object? raw) {
    if (raw is! Map) {
      return null;
    }
    final date = DateTime.tryParse(raw['date'] is String ? raw['date'] as String : '');
    final score = raw['score'];
    final total = raw['total'];
    if (date == null || score is! int || total is! int) {
      return null;
    }
    return McqAttempt(date: date, score: score, total: total);
  }
}

/// Keeps the last attempts per level and subject in SharedPreferences.
///
/// A storage failure never blocks the practice flow.
class McqHistoryStore {
  const McqHistoryStore();

  static const int maxEntries = 20;

  static String keyFor(McqLevel level, String subjectId) =>
      'fahmino_mcq_history_${level.id}_$subjectId';

  Future<List<McqAttempt>> load(McqLevel level, String subjectId) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final raw = preferences.getStringList(keyFor(level, subjectId)) ??
          const <String>[];
      final attempts = <McqAttempt>[];
      for (final item in raw) {
        try {
          final attempt = McqAttempt.tryFromJson(jsonDecode(item));
          if (attempt != null) {
            attempts.add(attempt);
          }
        } on FormatException {
          // Skip a corrupted entry.
        }
      }
      return attempts;
    } catch (_) {
      return const <McqAttempt>[];
    }
  }

  Future<void> save(
    McqLevel level,
    String subjectId,
    McqAttempt attempt,
  ) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final key = keyFor(level, subjectId);
      final entries = preferences.getStringList(key) ?? <String>[];
      entries.insert(0, jsonEncode(attempt.toJson()));
      await preferences.setStringList(key, entries.take(maxEntries).toList());
    } catch (_) {
      // The result screen must still show when history cannot be written.
    }
  }
}
