import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hamyar_hashtom_plus/core/router/app_routes.dart';

/// One compact card on the home screen that links to the two independent
/// exam sections: Multiple-Choice Tests and Interactive Exams.
class ExamSectionsCard extends StatelessWidget {
  const ExamSectionsCard({super.key});

  static const Key mcqKey = ValueKey('exam-section-mcq');
  static const Key interactiveKey = ValueKey('exam-section-interactive');

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 4),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _SectionRow(
              key: mcqKey,
              icon: Icons.checklist_rounded,
              iconBackground: colors.primaryContainer,
              iconColor: colors.onPrimaryContainer,
              title: 'آزمون‌های چندگزینه‌ای',
              subtitle: 'تمرین سطح‌بندی‌شده با نتیجه و مرور پاسخ‌ها',
              onTap: () => context.push(AppRoutes.mcqTests),
            ),
            const Divider(height: 1, indent: 16, endIndent: 16),
            _SectionRow(
              key: interactiveKey,
              icon: Icons.timer_rounded,
              iconBackground: colors.secondaryContainer,
              iconColor: colors.onSecondaryContainer,
              title: 'آزمون‌های تعاملی',
              subtitle: 'آزمون زمان‌دار با کارنامه و پاسخ‌نامه',
              onTap: () => context.push(AppRoutes.interactiveExams),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionRow extends StatelessWidget {
  const _SectionRow({
    super.key,
    required this.icon,
    required this.iconBackground,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color iconBackground;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: iconBackground,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.arrow_back_ios_new_rounded, size: 14),
          ],
        ),
      ),
    );
  }
}
