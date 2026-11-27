import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hamyar_hashtom_plus/core/router/app_routes.dart';
import 'package:hamyar_hashtom_plus/features/quiz/domain/mcq_level.dart';
import 'package:hamyar_hashtom_plus/features/quiz/domain/subject_pack.dart';
import 'package:hamyar_hashtom_plus/features/quiz/presentation/providers/quiz_providers.dart';
import 'package:hamyar_hashtom_plus/features/quiz/presentation/widgets/quiz_status_views.dart';

/// Hub of the Multiple-Choice Tests section: four difficulty levels.
///
/// A level opens only when the bundled content has real questions for it.
/// Easy and SAMPAD have no question set yet and carry a coming-soon badge.
class McqTestsHomeScreen extends ConsumerWidget {
  const McqTestsHomeScreen({super.key});

  /// Practice flows exist; a level is still disabled without questions.
  static const bool _practiceReady = true;

  static const Map<McqLevel, IconData> _icons = {
    McqLevel.easy: Icons.sentiment_satisfied_alt_rounded,
    McqLevel.intermediate: Icons.tune_rounded,
    McqLevel.advanced: Icons.bolt_rounded,
    McqLevel.sampad: Icons.workspace_premium_rounded,
  };

  static Key levelKey(McqLevel level) => ValueKey('mcq-level-${level.id}');
  static Key badgeKey(McqLevel level) => ValueKey('mcq-badge-${level.id}');

  static bool _isEnabled(McqLevel level, int questionCount) =>
      _practiceReady && level.hasQuestionSource && questionCount > 0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final packs = ref.watch(subjectPacksProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('آزمون‌های چندگزینه‌ای')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Text(
            'سطح موردنظرت را انتخاب کن، سپس درس را برگزین. سطح‌هایی که هنوز پرسش ندارند غیرفعال‌اند.',
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: colors.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          if (packs.hasError)
            QuizErrorView(onRetry: () => ref.invalidate(subjectPacksProvider)),
          for (final level in McqLevel.values)
            _buildTile(context, level, packs),
          const SizedBox(height: 4),
          Text(
            'پرسش‌ها برای تمرین‌اند و جایگزین کتاب درسی یا آزمون رسمی نیستند. سطح آسان و سمپاد پس از افزودن پرسش‌های مخصوص خودشان فعال می‌شوند.',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: colors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget _buildTile(
    BuildContext context,
    McqLevel level,
    AsyncValue<List<SubjectPack>> packs,
  ) {
    final list = packs.valueOrNull;
    final count = list == null
        ? 0
        : list.fold<int>(0, (total, pack) => total + pack.countFor(level));
    final subjects =
        list == null ? 0 : list.where((pack) => pack.countFor(level) > 0).length;
    final loading = packs.isLoading && list == null;
    final enabled = _isEnabled(level, count);

    String subtitle;
    _Trailing trailing;
    if (level.isComingSoon) {
      subtitle = level.subtitle;
      trailing = _Trailing.badge;
    } else if (loading) {
      subtitle = level.subtitle;
      trailing = _Trailing.loading;
    } else if (enabled) {
      subtitle = '$count سؤال در $subjects درس';
      trailing = _Trailing.chevron;
    } else {
      subtitle = 'هنوز سؤالی برای این سطح ثبت نشده است';
      trailing = _Trailing.lock;
    }

    return _LevelTile(
      level: level,
      icon: _icons[level]!,
      enabled: enabled,
      subtitle: subtitle,
      trailing: trailing,
      onTap: enabled ? () => context.push(AppRoutes.mcqLevel(level.id)) : null,
    );
  }
}

enum _Trailing { badge, loading, chevron, lock }

class _LevelTile extends StatelessWidget {
  const _LevelTile({
    required this.level,
    required this.icon,
    required this.enabled,
    required this.subtitle,
    required this.trailing,
    required this.onTap,
  });

  final McqLevel level;
  final IconData icon;
  final bool enabled;
  final String subtitle;
  final _Trailing trailing;
  final VoidCallback? onTap;

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
          onTap: onTap,
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
          subtitle: Text(subtitle),
          trailing: _buildTrailing(theme),
        ),
      ),
    );
  }

  Widget _buildTrailing(ThemeData theme) {
    final colors = theme.colorScheme;
    switch (trailing) {
      case _Trailing.badge:
        return Container(
          key: McqTestsHomeScreen.badgeKey(level),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
        );
      case _Trailing.loading:
        return const SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        );
      case _Trailing.chevron:
        return const Icon(Icons.arrow_back_ios_new_rounded, size: 14);
      case _Trailing.lock:
        return Icon(
          Icons.lock_outline_rounded,
          size: 18,
          color: colors.onSurfaceVariant,
        );
    }
  }
}
