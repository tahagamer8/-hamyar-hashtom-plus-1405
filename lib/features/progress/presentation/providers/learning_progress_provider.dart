import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Tracks completed lessons locally. Progress stays on the device and works offline.
class LearningProgressNotifier extends Notifier<Set<String>> {
  static const storageKey = 'fahmino_learning_progress_v1';

  @override
  Set<String> build() {
    _restore();
    return <String>{};
  }

  Future<void> _restore() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final saved = preferences.getStringList(storageKey) ?? const <String>[];
      // Preserve any changes made while preferences were being restored.
      state = <String>{...saved, ...state};
    } catch (_) {
      // Progress remains usable for the current session if storage is unavailable.
    }
  }

  Future<void> setCompleted(String key, bool completed) async {
    final next = Set<String>.from(state);
    if (completed) {
      next.add(key);
    } else {
      next.remove(key);
    }
    state = next;

    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setStringList(storageKey, next.toList()..sort());
    } catch (_) {
      // Do not block reading or changing lessons if local persistence fails.
    }
  }

  bool isCompleted(String key) => state.contains(key);
}

final learningProgressProvider =
    NotifierProvider<LearningProgressNotifier, Set<String>>(
  LearningProgressNotifier.new,
);
