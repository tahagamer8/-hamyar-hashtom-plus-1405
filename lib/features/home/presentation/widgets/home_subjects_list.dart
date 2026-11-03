import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hamyar_hashtom_plus/core/router/app_routes.dart';
import 'package:hamyar_hashtom_plus/features/subjects/presentation/providers/subjects_providers.dart';
import 'package:hamyar_hashtom_plus/features/subjects/presentation/widgets/subject_card.dart';

class HomeSubjectsList extends ConsumerWidget {
  const HomeSubjectsList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subjects = ref.watch(subjectsProvider);

    return SizedBox(
      height: 168,
      child: subjects.when(
        data: (items) => ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          itemCount: items.length,
          separatorBuilder: (context, index) => const SizedBox(width: 12),
          itemBuilder: (context, index) {
            final subject = items[index];
            return SizedBox(
              width: 150,
              child: SubjectCard(
                subject: subject,
                onTap: () => context.go(AppRoutes.subjectDetail(subject.id)),
              ),
            );
          },
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) =>
            const Center(child: Text('خطا در بارگذاری دروس')),
      ),
    );
  }
}
