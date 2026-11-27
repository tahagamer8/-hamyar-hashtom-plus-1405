abstract final class AppRoutes {
  static const String home = '/';
  static const String subjects = '/subjects';
  static const String featureSelection = '/feature';
  static String featureSubjects(String featureId) => '$featureSelection/$featureId';
  static const String search = '/search';
  static const String favorites = '/favorites';
  static const String settings = '/settings';
  static const String ai = '/ai';
  static const String planner = '/planner';
  static const String mcqTests = '/mcq-tests';
  static const String interactiveExams = '/interactive-exams';
  static String mcqLevel(String levelId) => '$mcqTests/$levelId';
  static String mcqPractice(String levelId, String subjectId) => '$mcqTests/$levelId/$subjectId';
  static String interactiveExam(String examId) => '$interactiveExams/$examId';
  static String subjectDetail(String id) => '$subjects/$id';
}
