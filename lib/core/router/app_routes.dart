abstract final class AppRoutes {
  static const String home = '/';
  static const String subjects = '/subjects';
  static const String search = '/search';
  static const String favorites = '/favorites';
  static const String settings = '/settings';
  static const String aiAssistant = '/ai-assistant';

  static String subjectDetail(String id) => '$subjects/$id';
}
