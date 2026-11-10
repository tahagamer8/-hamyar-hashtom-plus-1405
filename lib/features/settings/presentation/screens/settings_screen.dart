import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hamyar_hashtom_plus/core/constants/app_constants.dart';
import 'package:hamyar_hashtom_plus/core/theme/app_colors.dart';
import 'package:hamyar_hashtom_plus/core/theme/theme_mode_provider.dart';
import 'package:hamyar_hashtom_plus/core/utils/persian_digits.dart';
import 'package:hamyar_hashtom_plus/features/favorites/presentation/providers/favorites_provider.dart';
import 'package:hamyar_hashtom_plus/features/progress/presentation/providers/learning_progress_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
          Text('پشتیبان‌گیری و انتقال اطلاعات', style: theme.textTheme.titleMedium),
          const SizedBox(height: 10),
          _BackupCard(
            onRestored: () {
              ref.invalidate(favoritesProvider);
              ref.invalidate(learningProgressProvider);
              ref.invalidate(themeModeProvider);
            },
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

class _BackupCard extends StatefulWidget {
  const _BackupCard({required this.onRestored});

  final VoidCallback onRestored;

  @override
  State<_BackupCard> createState() => _BackupCardState();
}

class _BackupCardState extends State<_BackupCard> {
  static const _format = 'fahmino_local_backup';
  static const _schemaVersion = 1;
  bool _busy = false;

  bool _isAllowedKey(String key) =>
      key == 'fahmino_favorites_v1' ||
      key == 'fahmino_learning_progress_v1' ||
      key == 'fahmino_theme_mode' ||
      key == 'fahmino_next_exam_date_v1' ||
      key == 'fahmino_study_tasks_v1' ||
      key == 'fahmino_wrong_answers_v1' ||
      (key.startsWith('fahmino_exam_history_') &&
          key.length > 'fahmino_exam_history_'.length);

  bool _validateBackupEntry(String key, Object? value) {
    if (!_isAllowedKey(key)) return false;

    if (key == 'fahmino_theme_mode') {
      return value == 'light' || value == 'dark' || value == 'system';
    }
    if (key == 'fahmino_next_exam_date_v1') {
      return value is String && DateTime.tryParse(value) != null;
    }

    final isStringListKey = key == 'fahmino_favorites_v1' ||
        key == 'fahmino_learning_progress_v1' ||
        key == 'fahmino_study_tasks_v1' ||
        key == 'fahmino_wrong_answers_v1' ||
        key.startsWith('fahmino_exam_history_');
    if (!isStringListKey || value is! List || !value.every((item) => item is String)) {
      return false;
    }

    if (value.length > 500) return false;
    for (final row in value) {
      if (row.length > 40000) return false;
      if (key == 'fahmino_favorites_v1' ||
          key == 'fahmino_learning_progress_v1') {
        if (row.trim().isEmpty || row.length > 500) return false;
        continue;
      }

      dynamic decoded;
      try {
        decoded = jsonDecode(row);
      } on FormatException {
        return false;
      }
      if (decoded is! Map<String, dynamic>) return false;

      if (key == 'fahmino_study_tasks_v1') {
        final title = decoded['title'];
        final subject = decoded['subject'];
        final date = decoded['date'];
        final completed = decoded['completed'];
        if (title is! String || title.trim().isEmpty ||
            subject is! String || subject.trim().isEmpty ||
            date is! String || DateTime.tryParse(date) == null ||
            completed is! bool) {
          return false;
        }
      } else if (key == 'fahmino_wrong_answers_v1') {
        if (decoded['question'] is! String ||
            decoded['correctAnswer'] is! String ||
            decoded['subjectTitle'] is! String ||
            decoded['explanation'] is! String) {
          return false;
        }
      } else if (key.startsWith('fahmino_exam_history_')) {
        if (decoded['date'] is! String ||
            DateTime.tryParse(decoded['date'] as String) == null ||
            decoded['score'] is! int ||
            decoded['total'] is! int ||
            decoded['percent'] is! int) {
          return false;
        }
      }
    }
    return true;
  }

  Future<void> _exportBackup() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final preferences = await SharedPreferences.getInstance();
      final data = <String, Object?>{};
      for (final key in preferences.getKeys()) {
        if (_isAllowedKey(key)) {
          data[key] = preferences.get(key);
        }
      }
      final backup = const JsonEncoder.withIndent('  ').convert({
        'format': _format,
        'schemaVersion': _schemaVersion,
        'createdAt': DateTime.now().toUtc().toIso8601String(),
        'data': data,
      });
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('پشتیبان آماده است'),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: SelectableText(
                backup,
                textDirection: TextDirection.ltr,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('بستن'),
            ),
            FilledButton.icon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: backup));
                if (!context.mounted) return;
                Navigator.pop(context);
                ScaffoldMessenger.of(this.context).showSnackBar(
                  const SnackBar(content: Text('متن پشتیبان کپی شد. آن را در جای امن نگه دار.')),
                );
              },
              icon: const Icon(Icons.copy_rounded),
              label: const Text('کپی پشتیبان'),
            ),
          ],
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ساخت پشتیبان ممکن نشد.')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _importBackup() async {
    if (_busy) return;
    final raw = await showDialog<String>(
      context: context,
      builder: (context) => const _BackupImportDialog(),
    );
    if (raw == null || raw.isEmpty || !mounted) return;

    Map<String, dynamic> data;
    try {
      if (raw.length > 2 * 1024 * 1024) {
        throw const FormatException('Backup is too large');
      }
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic> ||
          decoded['format'] != _format ||
          decoded['schemaVersion'] != _schemaVersion ||
          decoded['data'] is! Map<String, dynamic>) {
        throw const FormatException('Unsupported backup format');
      }
      data = decoded['data'] as Map<String, dynamic>;
      if (data.isEmpty || data.keys.any((key) => !_isAllowedKey(key))) {
        throw const FormatException('Backup contains unsupported keys');
      }
      for (final entry in data.entries) {
        if (!_validateBackupEntry(entry.key, entry.value)) {
          throw const FormatException('Invalid backup entry');
        }
      }
    } on FormatException {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ساختار پشتیبان معتبر نیست یا با این نسخه سازگار نیست.')),
      );
      return;
    }

    final count = data.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأیید بازیابی'),
        content: Text(
          '$count بخش از اطلاعات فهمینو بازیابی می‌شود. داده‌های هم‌نام روی این دستگاه جایگزین خواهند شد.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('انصراف'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('بازیابی'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    try {
      final preferences = await SharedPreferences.getInstance();
      for (final entry in data.entries) {
        final value = entry.value;
        if (value == null) {
          await preferences.remove(entry.key);
        } else if (value is String) {
          await preferences.setString(entry.key, value);
        } else if (value is bool) {
          await preferences.setBool(entry.key, value);
        } else if (value is int) {
          await preferences.setInt(entry.key, value);
        } else if (value is double) {
          await preferences.setDouble(entry.key, value);
        } else if (value is List && value.every((item) => item is String)) {
          await preferences.setStringList(entry.key, value.cast<String>());
        }
      }
      widget.onRestored();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('پشتیبان با موفقیت بازیابی شد.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('بازیابی کامل نشد؛ اطلاعات فعلی را حفظ کن و دوباره تلاش کن.')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              children: [
                Icon(Icons.cloud_download_outlined,
                    color: theme.colorScheme.primary, size: 26),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'ذخیرهٔ علاقه‌مندی‌ها، پیشرفت، برنامه و سوابق آزمون روی فایل متنی امن',
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _busy ? null : _exportBackup,
                    icon: const Icon(Icons.upload_rounded),
                    label: const Text('ساخت پشتیبان'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _busy ? null : _importBackup,
                    icon: const Icon(Icons.restore_rounded),
                    label: const Text('بازیابی'),
                  ),
                ),
              ],
            ),
            if (_busy) ...[
              const SizedBox(height: 10),
              const LinearProgressIndicator(),
            ],
          ],
        ),
      ),
    );
  }
}

class _BackupImportDialog extends StatefulWidget {
  const _BackupImportDialog();

  @override
  State<_BackupImportDialog> createState() => _BackupImportDialogState();
}

class _BackupImportDialogState extends State<_BackupImportDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('بازیابی پشتیبان'),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('متن پشتیبانی را که قبلاً از فهمینو کپی کرده‌ای اینجا وارد کن.'),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              minLines: 4,
              maxLines: 10,
              textDirection: TextDirection.ltr,
              decoration: const InputDecoration(
                hintText: 'متن JSON پشتیبان',
                border: OutlineInputBorder(),
              ),
            ),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                onPressed: () async {
                  final clipboard = await Clipboard.getData('text/plain');
                  if (!mounted) return;
                  _controller.text = clipboard?.text ?? '';
                },
                icon: const Icon(Icons.content_paste_rounded),
                label: const Text('چسباندن از کلیپ‌بورد'),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('انصراف'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _controller.text.trim()),
          child: const Text('بررسی پشتیبان'),
        ),
      ],
    );
  }
}
