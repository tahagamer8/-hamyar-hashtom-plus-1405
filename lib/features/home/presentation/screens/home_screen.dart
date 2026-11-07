import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hamyar_hashtom_plus/core/router/app_routes.dart';
import 'package:hamyar_hashtom_plus/core/widgets/section_header.dart';
import 'package:hamyar_hashtom_plus/features/home/presentation/widgets/home_feature_grid.dart';
import 'package:hamyar_hashtom_plus/features/home/presentation/widgets/home_header.dart';
import 'package:hamyar_hashtom_plus/features/home/presentation/widgets/home_subjects_list.dart';
import 'package:hamyar_hashtom_plus/features/documents/presentation/widgets/learning_pdfs_card.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          const SliverToBoxAdapter(child: HomeHeader()),
          const SliverToBoxAdapter(child: SectionHeader(title: 'امکانات')),
          const SliverToBoxAdapter(child: HomeFeatureGrid()),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
              child: Card(
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => context.push(AppRoutes.ai),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: colors.primaryContainer,
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: Icon(Icons.auto_awesome_rounded,
                              color: colors.onPrimaryContainer),
                        ),
                        const SizedBox(width: 14),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('هوش مصنوعی فهمینو',
                                  style: TextStyle(fontWeight: FontWeight.w700)),
                              SizedBox(height: 3),
                              Text('پاسخ‌گویی آموزشی با Gemini و محتوای آفلاین'),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_left_rounded),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SliverToBoxAdapter(child: LearningPdfsCard()),
          SliverToBoxAdapter(
            child: SectionHeader(
              title: 'دروس پایه هشتم',
              actionLabel: 'همه دروس',
              onAction: () => context.go(AppRoutes.subjects),
            ),
          ),
          const SliverToBoxAdapter(child: HomeSubjectsList()),
          const SliverToBoxAdapter(child: SizedBox(height: 28)),
        ],
      ),
    );
  }
}
