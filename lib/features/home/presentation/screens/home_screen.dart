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
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          const SliverToBoxAdapter(child: HomeHeader()),
          const SliverToBoxAdapter(child: SectionHeader(title: 'امکانات')),
          const SliverToBoxAdapter(child: HomeFeatureGrid()),
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
