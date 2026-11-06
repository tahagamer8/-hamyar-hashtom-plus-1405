import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hamyar_hashtom_plus/core/router/app_routes.dart';
import 'package:hamyar_hashtom_plus/core/widgets/main_shell.dart';
import 'package:hamyar_hashtom_plus/features/ai/presentation/screens/ai_chat_screen.dart';
import 'package:hamyar_hashtom_plus/features/content/presentation/screens/content_library_screen.dart';
import 'package:hamyar_hashtom_plus/features/favorites/presentation/screens/favorites_screen.dart';
import 'package:hamyar_hashtom_plus/features/home/presentation/screens/home_screen.dart';
import 'package:hamyar_hashtom_plus/features/search/presentation/screens/search_screen.dart';
import 'package:hamyar_hashtom_plus/features/settings/presentation/screens/settings_screen.dart';
import 'package:hamyar_hashtom_plus/features/subjects/presentation/screens/subject_detail_screen.dart';
import 'package:hamyar_hashtom_plus/features/subjects/presentation/screens/subjects_screen.dart';
import 'package:hamyar_hashtom_plus/features/subjects/presentation/screens/feature_subjects_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: AppRoutes.home,
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            MainShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.home,
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '${AppRoutes.featureSelection}/:featureId',
                builder: (context, state) => FeatureSubjectsScreen(
                  featureId: state.pathParameters['featureId']!,
                ),
              ),
              GoRoute(
                path: AppRoutes.subjects,
                builder: (context, state) => const SubjectsScreen(),
                routes: [
                  GoRoute(
                    path: ':subjectId',
                    builder: (context, state) => SubjectDetailScreen(
                      subjectId: state.pathParameters['subjectId']!,
                    ),
                    routes: [
                      GoRoute(
                        path: ':featureId',
                        builder: (context, state) => ContentLibraryScreen(
                          subjectId: state.pathParameters['subjectId']!,
                          featureId: state.pathParameters['featureId']!,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.search,
                builder: (context, state) => const SearchScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.favorites,
                builder: (context, state) => const FavoritesScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.settings,
                builder: (context, state) => const SettingsScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.ai,
        builder: (context, state) => const AiChatScreen(),
      ),
    ],
    errorBuilder: (context, state) => const _NotFoundScreen(),
  );
});

class _NotFoundScreen extends StatelessWidget {
  const _NotFoundScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.explore_off_rounded, size: 64),
            const SizedBox(height: 16),
            Text('صفحه‌ای پیدا نشد',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => context.go(AppRoutes.home),
              child: const Text('بازگشت به خانه'),
            ),
          ],
        ),
      ),
    );
  }
}
