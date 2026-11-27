import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hamyar_hashtom_plus/features/quiz/data/mcq_history_store.dart';
import 'package:hamyar_hashtom_plus/features/quiz/data/subject_pack_repository.dart';
import 'package:hamyar_hashtom_plus/features/quiz/domain/mcq_level.dart';
import 'package:hamyar_hashtom_plus/features/quiz/domain/subject_pack.dart';

final subjectPackRepositoryProvider = Provider<SubjectPackRepository>(
  (ref) => SubjectPackRepository(rootBundle),
);

/// Every bundled subject pack, loaded once and shared by both exam sections.
final subjectPacksProvider = FutureProvider<List<SubjectPack>>(
  (ref) => ref.watch(subjectPackRepositoryProvider).loadAll(),
);

typedef McqHistoryKey = ({McqLevel level, String subjectId});

final mcqHistoryProvider =
    FutureProvider.autoDispose.family<List<McqAttempt>, McqHistoryKey>(
  (ref, key) => const McqHistoryStore().load(key.level, key.subjectId),
);
