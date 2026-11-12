import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MistakeReviewScreen extends StatefulWidget {
  const MistakeReviewScreen({super.key});

  @override
  State<MistakeReviewScreen> createState() => _MistakeReviewScreenState();
}

class _MistakeReviewScreenState extends State<MistakeReviewScreen> {
  static const _storageKey = 'fahmino_wrong_answers_v1';
  List<Map<String, dynamic>> _records = [];
  String? _subjectFilter;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final stored = preferences.getStringList(_storageKey) ?? const <String>[];
      final decoded = <Map<String, dynamic>>[];
      for (final row in stored) {
        try {
          final value = jsonDecode(row);
          if (value is Map<String, dynamic> &&
              value['question'] is String &&
              value['correctAnswer'] is String) {
            decoded.add(value);
          }
        } on FormatException {
          // Ignore one corrupt row and preserve the rest of the history.
        }
      }
      if (!mounted) return;
      setState(() {
        _records = decoded;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  List<String> get _subjects => (_records
      .map((item) => item['subjectTitle'])
      .whereType<String>()
      .toSet()
      .toList()
    ..sort());

  List<Map<String, dynamic>> get _visibleRecords => _records
      .where((item) =>
          _subjectFilter == null || item['subjectTitle'] == _subjectFilter)
      .toList(growable: false);

  Future<void> _clearHistory() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('پاک کردن مرور اشتباهات'),
        content: const Text('همهٔ سؤال‌های ذخیره‌شده از مرور اشتباهات حذف شوند؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('انصراف'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('پاک کردن'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_storageKey);
    if (!mounted) return;
    setState(() {
      _records = [];
      _subjectFilter = null;
    });
  }

  String _dateLabel(dynamic raw) {
    final date = raw is String ? DateTime.tryParse(raw) : null;
    if (date == null) return 'تاریخ نامشخص';
    return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final visible = _visibleRecords;
    return Scaffold(
      appBar: AppBar(
        title: const Text('مرور اشتباهات'),
        actions: [
          if (_records.isNotEmpty)
            IconButton(
              tooltip: 'پاک کردن سابقه',
              onPressed: _clearHistory,
              icon: const Icon(Icons.delete_outline_rounded),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _records.isEmpty
              ? const _MistakesEmptyState()
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${_records.length} سؤال برای مرور ذخیره شده',
                              style: theme.textTheme.titleSmall,
                            ),
                          ),
                          SizedBox(
                            width: 170,
                            child: DropdownButtonFormField<String?>(
                              initialValue: _subjectFilter,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'فیلتر درس',
                                isDense: true,
                                border: OutlineInputBorder(),
                              ),
                              items: [
                                const DropdownMenuItem<String?>(
                                  value: null,
                                  child: Text('همهٔ درس‌ها'),
                                ),
                                for (final subject in _subjects)
                                  DropdownMenuItem<String?>(
                                    value: subject,
                                    child: Text(subject,
                                        overflow: TextOverflow.ellipsis),
                                  ),
                              ],
                              onChanged: (value) =>
                                  setState(() => _subjectFilter = value),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: visible.isEmpty
                          ? const Center(
                              child: Text('برای این درس اشتباهی ثبت نشده است.'))
                          : ListView.separated(
                              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                              itemCount: visible.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 8),
                              itemBuilder: (context, index) {
                                final item = visible[index];
                                return Card(
                                  child: Padding(
                                    padding: const EdgeInsets.all(14),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                item['subjectTitle'] as String? ??
                                                    'درس',
                                                style: theme.textTheme.labelLarge
                                                    ?.copyWith(
                                                  color: theme.colorScheme.primary,
                                                  fontWeight: FontWeight.w800,
                                                ),
                                              ),
                                            ),
                                            Text(
                                              _dateLabel(item['date']),
                                              style: theme.textTheme.labelSmall,
                                            ),
                                          ],
                                        ),
                                        if (item['examTitle'] is String)
                                          Padding(
                                            padding:
                                                const EdgeInsets.only(top: 3),
                                            child: Text(
                                              item['examTitle'] as String,
                                              style: theme.textTheme.bodySmall,
                                            ),
                                          ),
                                        const SizedBox(height: 8),
                                        Text(
                                          item['question'] as String,
                                          style: theme.textTheme.titleSmall,
                                        ),
                                        const SizedBox(height: 8),
                                        Text('پاسخ انتخابی: ${item['selectedAnswer'] ?? 'بی‌پاسخ'}'),
                                        Text(
                                          'پاسخ درست: ${item['correctAnswer']}',
                                          style: theme.textTheme.bodyMedium
                                              ?.copyWith(
                                            color: theme.colorScheme.primary,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        if (item['explanation'] is String) ...[
                                          const SizedBox(height: 6),
                                          Text(item['explanation'] as String),
                                        ],
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
    );
  }
}

class _MistakesEmptyState extends StatelessWidget {
  const _MistakesEmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.fact_check_outlined,
                size: 56, color: theme.colorScheme.primary),
            const SizedBox(height: 12),
            Text('فعلاً اشتباهی ثبت نشده', style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            const Text(
              'بعد از آزمون، سؤال‌های اشتباه و بی‌پاسخ اینجا ذخیره می‌شوند تا دوباره مرورشان کنی.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
