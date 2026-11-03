import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hamyar_hashtom_plus/core/constants/app_constants.dart';
import 'package:hamyar_hashtom_plus/core/theme/app_colors.dart';
import 'package:hamyar_hashtom_plus/core/theme/theme_mode_provider.dart';
import 'package:hamyar_hashtom_plus/core/utils/persian_digits.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final mode = ref.watch(themeModeProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('تنظیمات')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('ظاهر برنامه', style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          SegmentedButton<ThemeMode>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: ThemeMode.light, label: Text('روشن')),
              ButtonSegment(value: ThemeMode.dark, label: Text('تاریک')),
              ButtonSegment(value: ThemeMode.system, label: Text('سیستم')),
            ],
            selected: {mode},
            onSelectionChanged: (selection) =>
                ref.read(themeModeProvider.notifier).set(selection.first),
          ),
          const SizedBox(height: 24),
          Material(
            color: AppColors.card(context),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: BorderSide(
                color: theme.colorScheme.outlineVariant.withAlpha(90),
              ),
            ),
            child: ListTile(
              leading: const Icon(Icons.info_outline_rounded),
              title: const Text(AppConstants.appName),
              subtitle: Text('نسخه ${AppConstants.version.toPersianDigits()}'),
            ),
          ),
        ],
      ),
    );
  }
}
