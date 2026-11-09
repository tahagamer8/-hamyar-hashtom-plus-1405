import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SubjectAnalyticsScreen extends StatefulWidget {
  const SubjectAnalyticsScreen({
    super.key,
    required this.subjectId,
    required this.subjectTitle,
  });

  final String subjectId;
  final String subjectTitle;

  @override
  State<SubjectAnalyticsScreen> createState() => _SubjectAnalyticsScreenState();
}

class _SubjectAnalyticsScreenState extends State<SubjectAnalyticsScreen> {
  late final Future<List<_ExamRecord>> _historyFuture;

  @override
  void initState() {
    super.initState();
    _historyFuture = _loadHistory();
  }

  Future<List<_ExamRecord>> _loadHistory() async {
    final preferences = await SharedPreferences.getInstance();
    final prefix = 'fahmino_exam_history_${widget.subjectTitle}';
    final records = <_ExamRecord>[];

    for (final key in preferences.getKeys().where((key) => key.startsWith(prefix))) {
      final values = preferences.getStringList(key) ?? const <String>[];
      for (final raw in values) {
        try {
          final decoded = Map<String, dynamic>.from(
            (Uri.decodeComponent(raw) == raw ? _decodeJson(raw) : _decodeJson(raw))
                as Map,
          );
          final percent = decoded['percent'];
          final score = decoded['score'];
          final total = decoded['total'];
          final date = decoded['date'];
          if (percent is! num || score is! num || total is! num) continue;
          records.add(
            _ExamRecord(
              percent: percent.toDouble().clamp(0, 100).toDouble(),
              score: score.toInt(),
              total: total.toInt(),
              date: date is String ? DateTime.tryParse(date) : null,
            ),
          );
        } catch (_) {
          // Ignore a malformed older record without breaking the report.
        }
      }
    }

    records.sort((a, b) {
      final left = a.date ?? DateTime.fromMillisecondsSinceEpoch(0);
      final right = b.date ?? DateTime.fromMillisecondsSinceEpoch(0);
      return right.compareTo(left);
    });
    return records;
  }

  dynamic _decodeJson(String value) {
    return _jsonDecode(value);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text('تحلیل عملکرد ${widget.subjectTitle}')),
      body: FutureBuilder<List<_ExamRecord>>(
        future: _historyFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text('خواندن سوابق آزمون ممکن نشد.'));
          }

          final records = snapshot.data ?? const <_ExamRecord>[];
          if (records.isEmpty) {
            return _EmptyReport(
              subjectId: widget.subjectId,
              subjectTitle: widget.subjectTitle,
            );
          }

          final average = records
                  .map((item) => item.percent)
                  .reduce((a, b) => a + b) /
              records.length;
          final best = records
              .map((item) => item.percent)
              .reduce((a, b) => a > b ? a : b);
          final latest = records.first.percent;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('خلاصهٔ عملکرد', style: theme.textTheme.titleMedium),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: _Metric(
                              title: 'میانگین',
                              value: '${average.round()}٪',
                              icon: Icons.analytics_outlined,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _Metric(
                              title: 'بهترین',
                              value: '${best.round()}٪',
                              icon: Icons.emoji_events_outlined,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _Metric(
                              title: 'آزمون‌ها',
                              value: records.length.toString(),
                              icon: Icons.fact_check_outlined,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'آخرین نتیجه: ${latest.round()}٪',
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 10),
                      LinearProgressIndicator(
                        value: latest / 100,
                        minHeight: 9,
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('پیشنهاد مرور', style: theme.textTheme.titleMedium),
                      const SizedBox(height: 8),
                      Text(
                        average >= 85
                            ? 'عملکردت در این درس خوب بوده است. برای تثبیت یادگیری، آزمون‌های ترکیبی و مرور فاصله‌دار را ادامه بده.'
                            : average >= 70
                                ? 'بهتر است فصل‌هایی را که در آن‌ها اشتباه داشتی دوباره مرور کنی و سپس یک آزمون زمان‌دار دیگر بدهی.'
                                : 'از فصل‌های پایه شروع کن، مثال‌های حل‌شده را مرور کن و بعد از هر فصل یک آزمون کوتاه انجام بده.',
                        style: theme.textTheme.bodyMedium?.copyWith(height: 1.7),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text('سوابق اخیر', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              for (final record in records.take(10))
                Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: Padding(
                    padding: const EdgeInsets.all(13),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${record.score} از ${record.total} پاسخ درست',
                                style: theme.textTheme.titleSmall,
                              ),
                            ),
                            Text(
                              '${record.percent.round()}٪',
                              style: theme.textTheme.titleSmall?.copyWith(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        LinearProgressIndicator(
                          value: record.percent / 100,
                          minHeight: 7,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        if (record.date != null) ...[
                          const SizedBox(height: 6),
                          Text(
                            _formatDate(record.date!),
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  'این گزارش فقط از سوابق ذخیره‌شده روی همین دستگاه ساخته شده است. '
                  'اطلاعات به مدرسه، استان یا سازمان دیگری ارسال نمی‌شود و گزارش رسمی پایش سمپاد نیست.',
                  style: theme.textTheme.bodySmall?.copyWith(height: 1.7),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _formatDate(DateTime date) {
    final local = date.toLocal();
    return '${local.year}/${local.month.toString().padLeft(2, '0')}/'
        '${local.day.toString().padLeft(2, '0')}';
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.title,
    required this.value,
    required this.icon,
  });

  final String title;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Icon(icon, color: theme.colorScheme.primary, size: 20),
          const SizedBox(height: 7),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(title, style: theme.textTheme.labelSmall),
        ],
      ),
    );
  }
}

class _EmptyReport extends StatelessWidget {
  const _EmptyReport({
    required this.subjectId,
    required this.subjectTitle,
  });

  final String subjectId;
  final String subjectTitle;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.query_stats_rounded, size: 48),
            const SizedBox(height: 12),
            Text(
              'هنوز نتیجه‌ای برای ${subjectTitle} ثبت نشده است.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () => context.go('/subjects/${subjectId}/quiz'),
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('شروع اولین آزمون'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExamRecord {
  const _ExamRecord({
    required this.percent,
    required this.score,
    required this.total,
    required this.date,
  });

  final double percent;
  final int score;
  final int total;
  final DateTime? date;
}

// Kept local to avoid requiring a separate JSON utility for this small report.
dynamic _jsonDecode(String value) {
  return jsonDecode(value);
}
