import 'package:hamyar_hashtom_plus/features/subjects/domain/entities/subject.dart';

abstract interface class SubjectsRepository {
  Future<List<Subject>> getSubjects();
  Future<Subject?> getSubjectById(String id);
}
