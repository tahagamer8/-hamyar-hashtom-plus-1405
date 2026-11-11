import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FavoritesNotifier extends Notifier<Set<String>> {
  static const _storageKey = 'fahmino_favorites_v1';

  Future<void>? _restoreFuture;
  Future<void> _writeQueue = Future<void>.value();
  final Map<String, bool> _pendingChanges = {};

  /// Completes after the first local snapshot has been restored.
  Future<void> get ready => _restoreFuture ?? Future<void>.value();

  @override
  Set<String> build() {
    _restoreFuture = _restore();
    return <String>{};
  }

  Future<void> _restore() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final restored =
          preferences.getStringList(_storageKey)?.toSet() ?? <String>{};

      // Keep user actions made while SharedPreferences was loading.
      for (final change in _pendingChanges.entries) {
        if (change.value) {
          restored.add(change.key);
        } else {
          restored.remove(change.key);
        }
      }
      state = restored;
    } catch (_) {
      // Favorites remain usable for this session if local storage is unavailable.
    }
  }

  Future<void> toggle(String key) async {
    final next = Set<String>.from(state);
    if (!next.add(key)) next.remove(key);
    state = next;
    _pendingChanges[key] = next.contains(key);

    await ready;

    // Serialize writes so two fast taps cannot persist an older snapshot last.
    _writeQueue = _writeQueue.then((_) async {
      try {
        final preferences = await SharedPreferences.getInstance();
        final snapshot = state.toList()..sort();
        await preferences.setStringList(_storageKey, snapshot);
      } catch (_) {
        // Keep the in-memory change; a storage failure must not break the UI.
      }
    });
    await _writeQueue;
  }
}

final favoritesProvider =
    NotifierProvider<FavoritesNotifier, Set<String>>(FavoritesNotifier.new);
