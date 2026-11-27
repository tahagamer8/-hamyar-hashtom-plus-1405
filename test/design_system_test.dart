import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hamyar_hashtom_plus/core/theme/app_colors.dart';
import 'package:hamyar_hashtom_plus/core/theme/app_theme.dart';
import 'package:hamyar_hashtom_plus/core/widgets/icon_badge.dart';
import 'package:hamyar_hashtom_plus/features/subjects/presentation/utils/subject_style.dart';

/// WCAG contrast ratio between two opaque colors.
double _contrast(Color a, Color b) {
  final first = a.computeLuminance();
  final second = b.computeLuminance();
  final lighter = first > second ? first : second;
  final darker = first > second ? second : first;
  return (lighter + 0.05) / (darker + 0.05);
}

const _subjectIds = [
  'math',
  'science',
  'persian',
  'writing',
  'arabic',
  'english',
  'english_workbook',
  'social',
  'religion',
  'quran',
  'thinking',
  'work',
  'art',
];

void main() {
  final themes = <String, ThemeData>{
    'light': AppTheme.light(),
    'dark': AppTheme.dark(),
  };

  for (final entry in themes.entries) {
    final theme = entry.value;
    final scheme = theme.colorScheme;

    group('${entry.key} theme', () {
      test('is Material 3 with the matching brightness', () {
        expect(theme.useMaterial3, isTrue);
        expect(
          theme.brightness,
          entry.key == 'light' ? Brightness.light : Brightness.dark,
        );
      });

      test('applies Vazirmatn to every text style that is used', () {
        final text = theme.textTheme;
        for (final style in [
          text.headlineSmall,
          text.titleLarge,
          text.titleMedium,
          text.titleSmall,
          text.bodyLarge,
          text.bodyMedium,
          text.bodySmall,
          text.labelLarge,
          text.labelMedium,
          theme.appBarTheme.titleTextStyle,
        ]) {
          expect(style?.fontFamily, AppTheme.fontFamily);
        }
      });

      test('text meets WCAG AA contrast on its surfaces', () {
        final pairs = <String, List<Color>>{
          'onSurface on surface': [scheme.onSurface, scheme.surface],
          'onSurface on scaffold': [
            scheme.onSurface,
            theme.scaffoldBackgroundColor,
          ],
          'onSurface on card': [scheme.onSurface, theme.cardTheme.color!],
          'onSurfaceVariant on card': [
            scheme.onSurfaceVariant,
            theme.cardTheme.color!,
          ],
          'onPrimary on primary': [scheme.onPrimary, scheme.primary],
          'onPrimaryContainer on primaryContainer': [
            scheme.onPrimaryContainer,
            scheme.primaryContainer,
          ],
          'onSecondaryContainer on secondaryContainer': [
            scheme.onSecondaryContainer,
            scheme.secondaryContainer,
          ],
          'onError on error': [scheme.onError, scheme.error],
        };
        for (final pair in pairs.entries) {
          expect(
            _contrast(pair.value[0], pair.value[1]),
            greaterThanOrEqualTo(4.5),
            reason: '${entry.key}: ${pair.key}',
          );
        }
      });

      test('buttons share one shape and touch target size', () {
        final filled = theme.filledButtonTheme.style!;
        final outlined = theme.outlinedButtonTheme.style!;
        expect(filled.minimumSize!.resolve({})!.height, 52);
        expect(outlined.minimumSize!.resolve({})!.height, 52);
        expect(
          filled.shape!.resolve({}),
          outlined.shape!.resolve({}),
        );
      });

      testWidgets('hand-built cards match the theme card color',
          (tester) async {
        late Color resolved;
        await tester.pumpWidget(MaterialApp(
          theme: theme,
          home: Builder(
            builder: (context) {
              resolved = AppColors.card(context);
              return const SizedBox();
            },
          ),
        ));
        expect(resolved, theme.cardTheme.color);
      });

      testWidgets('icon badge keeps the icon legible', (tester) async {
        const base = Color(0xFF4F46E5);
        await tester.pumpWidget(MaterialApp(
          theme: theme,
          home: const Scaffold(
            body: Center(
              child: IconBadge(icon: Icons.school_rounded, color: base),
            ),
          ),
        ));
        final icon = tester.widget<Icon>(find.byIcon(Icons.school_rounded));
        if (entry.key == 'dark') {
          expect(icon.color, isNot(base));
          expect(
            _contrast(icon.color!, theme.scaffoldBackgroundColor),
            greaterThanOrEqualTo(3),
          );
        } else {
          expect(icon.color, base);
        }
        expect(tester.takeException(), isNull);
      });
    });
  }

  group('subject styles', () {
    test('every grade-eight subject has its own icon', () {
      final fallback = styleForSubject('unknown-subject').icon;
      final icons = <IconData>{};
      for (final id in _subjectIds) {
        final icon = styleForSubject(id).icon;
        expect(icon, isNot(fallback), reason: id);
        expect(icons.add(icon), isTrue, reason: 'duplicate icon for $id');
      }
      expect(icons, hasLength(_subjectIds.length));
    });

    test('unknown ids still get a usable fallback', () {
      final style = styleForSubject('something-new');
      expect(style.icon, Icons.book_rounded);
    });
  });
}
