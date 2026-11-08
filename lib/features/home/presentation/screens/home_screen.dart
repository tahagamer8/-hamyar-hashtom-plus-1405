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
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 4),
              child: Row(
                children: [
                  Icon(Icons.bolt_rounded, color: colors.primary),
                  const SizedBox(width: 7),
                  Text('دسترسی سریع',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      )),
                ],
              ),
            ),
          ),
          const SliverToBoxAdapter(child: HomeFeatureGrid()),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 4),
              child: Card(
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => context.push(AppRoutes.ai),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                colors.primaryContainer,
                                colors.secondaryContainer,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(Icons.auto_awesome_rounded,
                              color: colors.onPrimaryContainer, size: 27),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('راهنمای درسی فهمینو',
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w800)),
                              const SizedBox(height: 3),
                              Text('از محتوای درس‌ها پاسخ پیدا کن',
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(color: colors.onSurfaceVariant)),
                            ],
                          ),
                        ),
                        const Icon(Icons.arrow_back_ios_new_rounded, size: 16),
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
              title: 'درس‌های پایه هشتم',
              actionLabel: 'همه درس‌ها',
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
