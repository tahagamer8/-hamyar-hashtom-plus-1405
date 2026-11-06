import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FavoritesNotifier extends Notifier<Set<String>> {
  static const _storageKey = 'fahmino_favorites_v1';

  @override
  Set<String> build() {
    _restore();
    return <String>{};
  }

  Future<void> _restore() async {
    final preferences = await SharedPreferences.getInstance();
    state = preferences.getStringList(_storageKey)?.toSet() ?? <String>{};
  }

  Future<void> toggle(String key) async {
    final next = Set<String>.from(state);
    if (!next.add(key)) next.remove(key);
    state = next;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setStringList(_storageKey, next.toList()..sort());
  }
}

final favoritesProvider =
    NotifierProvider<FavoritesNotifier, Set<String>>(FavoritesNotifier.new);
