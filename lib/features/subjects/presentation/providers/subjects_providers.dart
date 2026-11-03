import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hamyar_hashtom_plus/features/subjects/data/repositories/subjects_repository_impl.dart';
import 'package:hamyar_hashtom_plus/features/subjects/domain/entities/subject.dart';
import 'package:hamyar_hashtom_plus/features/subjects/domain/repositories/subjects_repository.dart';

final subjectsRepositoryProvider = Provider<SubjectsRepository>(
  (ref) => const SubjectsRepositoryImpl(),
);

final subjectsProvider = FutureProvider<List<Subject>>(
  (ref) => ref.watch(subjectsRepositoryProvider).getSubjects(),
);

final subjectProvider = FutureProvider.family<Subject?, String>(
  (ref, id) => ref.watch(subjectsRepositoryProvider).getSubjectById(id),
);
