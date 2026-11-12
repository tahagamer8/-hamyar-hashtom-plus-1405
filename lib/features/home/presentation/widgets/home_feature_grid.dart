import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hamyar_hashtom_plus/core/constants/app_feature.dart';
import 'package:hamyar_hashtom_plus/core/router/app_routes.dart';
import 'package:hamyar_hashtom_plus/core/theme/app_colors.dart';

class HomeFeatureGrid extends StatelessWidget {
  const HomeFeatureGrid({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: GridView.builder(
        itemCount: AppFeature.values.length,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.18,
        ),
        itemBuilder: (context, index) =>
            _FeatureTile(feature: AppFeature.values[index]),
      ),
    );
  }
}

class _FeatureTile extends StatelessWidget {
  const _FeatureTile({required this.feature});
  final AppFeature feature;

  String get _description => switch (feature) {
    AppFeature.lessons => 'فصل‌ها را درس‌به‌درس یاد بگیر',
    AppFeature.notes => 'جزوه‌های PDF آفلاین هر فصل',
    AppFeature.flashcards => 'مرور فعال نکته‌ها و پرسش‌ها با کارت',
    AppFeature.solutions => 'پاسخ تمرین‌ها با راه‌حل مرحله‌ای',
    AppFeature.sampleExams => 'نمونه‌سؤال‌های PDF فصل و نیم‌سال',
    AppFeature.lessonQuestions => 'تمرین تعاملی هر فصل با پاسخ تشریحی',
    AppFeature.quiz => 'خودت را با آزمون بسنج',
    AppFeature.favorites => 'مطالب مهمت را یک‌جا ببین',
    AppFeature.studyPlanner => 'برای امتحان‌ها برنامه بساز و پیگیری کن',
    AppFeature.mistakes => 'پاسخ‌های اشتباه را دوباره تمرین کن',
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final radius = BorderRadius.circular(22);
    return Material(
      color: AppColors.card(context),
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(color: feature.color.withAlpha(70)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        borderRadius: radius,
        onTap: () {
          switch (feature) {
            case AppFeature.favorites:
              context.go(AppRoutes.favorites);
            case AppFeature.studyPlanner:
              context.push(AppRoutes.studyPlanner);
            case AppFeature.mistakes:
              context.push(AppRoutes.mistakes);
            default:
              context.push(AppRoutes.featureSubjects(feature.name));
          }
        },
        child: Stack(
          children: [
            Positioned(
              left: -18,
              top: -24,
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: feature.color.withAlpha(14),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 43,
                        height: 43,
                        decoration: BoxDecoration(
                          color: feature.color.withAlpha(25),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(feature.icon,
                            color: feature.color, size: 25),
                      ),
                      const Spacer(),
                      Icon(Icons.north_west_rounded,
                          size: 17, color: theme.colorScheme.onSurfaceVariant),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(feature.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w900,
                          )),
                      const SizedBox(height: 4),
                      Text(_description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            height: 1.35,
                            color: theme.colorScheme.onSurfaceVariant,
                          )),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
