import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hamyar_hashtom_plus/core/router/app_routes.dart';
import 'package:hamyar_hashtom_plus/core/widgets/section_header.dart';
import 'package:hamyar_hashtom_plus/features/home/presentation/widgets/home_feature_grid.dart';
import 'package:hamyar_hashtom_plus/features/home/presentation/widgets/home_header.dart';
import 'package:hamyar_hashtom_plus/features/home/presentation/widgets/home_subjects_list.dart';

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
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 14),
              child: Card(
                child: ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.auto_awesome_rounded)),
                  title: const Text('دستیار هوشمند فهمینو'),
                  subtitle: const Text('پرسش و پاسخ درسی با Gemini'),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                  onTap: () => context.push(AppRoutes.aiAssistant),
                ),
              ),
            ),
          ),
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
