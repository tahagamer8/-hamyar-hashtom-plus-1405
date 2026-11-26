import 'package:flutter/material.dart';
import 'package:hamyar_hashtom_plus/features/quiz/domain/mcq_level.dart';

/// Hub of the Multiple-Choice Tests section: four difficulty levels.
///
/// No level opens an exam yet. Easy and SAMPAD carry a coming-soon badge;
/// Intermediate and Advanced stay disabled until [_practiceReady] is true.
class McqTestsHomeScreen extends StatelessWidget {
  const McqTestsHomeScreen({super.key});

  /// Flip to true once real practice flows exist for the ready levels.
  static const bool _practiceReady = false;

  static const Map<McqLevel, IconData> _icons = {
    McqLevel.easy: Icons.sentiment_satisfied_alt_rounded,
    McqLevel.intermediate: Icons.tune_rounded,
    McqLevel.advanced: Icons.bolt_rounded,
    McqLevel.sampad: Icons.workspace_premium_rounded,
  };

  static Key levelKey(McqLevel level) => ValueKey('mcq-level-${level.id}');
  static Key badgeKey(McqLevel level) => ValueKey('mcq-badge-${level.id}');

  static bool _isEnabled(McqLevel level) =>
      !level.isComingSoon && _practiceReady;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('آزمون‌های چندگزینه‌ای')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Text(
            'پرسش‌های چهارگزینه‌ای را بر اساس درس، فصل و موضوع تمرین کن. سطح مناسب را انتخاب کن.',
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: colors.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          for (final level in McqLevel.values)
            _LevelTile(
              level: level,
              icon: _icons[level]!,
              enabled: _isEnabled(level),
            ),
          const SizedBox(height: 4),
          Text(
            'آزمون‌های سطح متوسط و پیشرفته در به‌روزرسانی بعدی فعال می‌شوند.',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: colors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _LevelTile extends StatelessWidget {
  const _LevelTile({
    required this.level,
    required this.icon,
    required this.enabled,
  });

  final McqLevel level;
  final IconData icon;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          key: McqTestsHomeScreen.levelKey(level),
          enabled: enabled,
          // The exam destination is added in a later batch; until then no
          // level is tappable.
          onTap: null,
          leading: Opacity(
            opacity: enabled ? 1 : 0.6,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: colors.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: colors.onPrimaryContainer, size: 22),
            ),
          ),
          title: Text(
            level.title,
            style: theme.textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          subtitle: Text(level.subtitle),
          trailing: level.isComingSoon
              ? Container(
                  key: McqTestsHomeScreen.badgeKey(level),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: colors.secondaryContainer,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    McqLevel.comingSoonLabel,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colors.onSecondaryContainer,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                )
              : Icon(
                  enabled
                      ? Icons.arrow_back_ios_new_rounded
                      : Icons.lock_outline_rounded,
                  size: enabled ? 14 : 18,
                  color: colors.onSurfaceVariant,
                ),
        ),
      ),
    );
  }
}
