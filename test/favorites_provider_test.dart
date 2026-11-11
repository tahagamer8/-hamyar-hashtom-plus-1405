import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hamyar_hashtom_plus/features/favorites/presentation/providers/favorites_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('restores chapter favorites and persists PDF favorites', () async {
    SharedPreferences.setMockInitialValues({
      'fahmino_favorites_v1': ['math::عددهای گویا'],
    });

    final container = ProviderContainer();
    addTearDown(container.dispose);

    final notifier = container.read(favoritesProvider.notifier);
    await notifier.ready;

    expect(
      container.read(favoritesProvider),
      contains('math::عددهای گویا'),
    );

    await notifier.toggle('pdf::math::notes');
    var preferences = await SharedPreferences.getInstance();
    expect(
      preferences.getStringList('fahmino_favorites_v1'),
      containsAll(['math::عددهای گویا', 'pdf::math::notes']),
    );

    await notifier.toggle('math::عددهای گویا');
    preferences = await SharedPreferences.getInstance();
    expect(
      preferences.getStringList('fahmino_favorites_v1'),
      ['pdf::math::notes'],
    );
  });

  test('removing a PDF favorite persists the removal', () async {
    SharedPreferences.setMockInitialValues({
      'fahmino_favorites_v1': ['pdf::english::questions'],
    });

    final container = ProviderContainer();
    addTearDown(container.dispose);

    final notifier = container.read(favoritesProvider.notifier);
    await notifier.ready;
    await notifier.toggle('pdf::english::questions');

    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getStringList('fahmino_favorites_v1'), isEmpty);
  });
}
