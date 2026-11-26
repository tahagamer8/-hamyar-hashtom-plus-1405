import 'package:flutter/material.dart';

/// Informational hub of the Interactive Exams section.
///
/// Nothing here is tappable yet; the existing timed exams inside each
/// subject are unchanged.
class InteractiveExamsHomeScreen extends StatelessWidget {
  const InteractiveExamsHomeScreen({super.key});

  static const List<_Feature> _features = [
    _Feature(
      Icons.timer_rounded,
      'آزمون زمان‌دار',
      'زمان‌سنج و پایان خودکار آزمون',
    ),
    _Feature(
      Icons.fact_check_rounded,
      'ثبت پاسخ',
      'پاسخ‌ها را ثبت کن و آزمون را پایان بده',
    ),
    _Feature(
      Icons.calculate_rounded,
      'تصحیح خودکار',
      'نمره بلافاصله محاسبه می‌شود',
    ),
    _Feature(
      Icons.rate_review_rounded,
      'مرور پاسخ‌ها',
      'پاسخ درست و توضیح هر پرسش را ببین',
    ),
    _Feature(
      Icons.insights_rounded,
      'تحلیل عملکرد',
      'نقاط قوت و ضعف خودت را بشناس',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('آزمون‌های تعاملی')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Text(
            'آزمونی شبیه شرایط واقعی، با بازخورد کامل بعد از پایان.',
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: colors.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                children: [
                  for (final feature in _features) _FeatureRow(feature: feature),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.info_outline_rounded,
                size: 18,
                color: colors.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'این بخش فعلاً اطلاع‌رسانی است. آزمون‌های زمان‌دار موجود در درس‌ها بدون تغییر باقی می‌مانند.',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: colors.onSurfaceVariant),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Feature {
  const _Feature(this.icon, this.title, this.subtitle);

  final IconData icon;
  final String title;
  final String subtitle;
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({required this.feature});

  final _Feature feature;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: colors.secondaryContainer,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              feature.icon,
              color: colors.onSecondaryContainer,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  feature.title,
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                Text(
                  feature.subtitle,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: colors.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
