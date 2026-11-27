/// Difficulty levels of the Multiple-Choice Tests section.
///
/// Easy and SAMPAD have no dedicated question set yet, so they stay visible
/// but disabled. Intermediate reads each chapter's `questions` list and
/// Advanced reads its `advancedQuestions` list from the subject packs.
enum McqLevel {
  easy(
    id: 'easy',
    title: 'آسان',
    subtitle: 'مرور مفهوم‌های پایه',
    isComingSoon: true,
  ),
  intermediate(
    id: 'intermediate',
    title: 'متوسط',
    subtitle: 'تمرین هم‌سطح کتاب درسی',
    isComingSoon: false,
    sourceKey: 'questions',
  ),
  advanced(
    id: 'advanced',
    title: 'پیشرفته',
    subtitle: 'پرسش‌های چالشی و استدلالی',
    isComingSoon: false,
    sourceKey: 'advancedQuestions',
  ),
  sampad(
    id: 'sampad',
    title: 'سمپاد',
    subtitle: 'آمادگی آزمون تیزهوشان',
    isComingSoon: true,
  );

  const McqLevel({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.isComingSoon,
    this.sourceKey,
  });

  /// Stable identifier, safe to use in keys and route parameters.
  final String id;

  /// Persian display title.
  final String title;

  /// One-line Persian description.
  final String subtitle;

  /// Whether the level is announced but has no exam content yet.
  final bool isComingSoon;

  /// Chapter field in a subject pack that holds this level's questions, or
  /// null when the level has no question source.
  final String? sourceKey;

  bool get hasQuestionSource => sourceKey != null;

  /// Label shown on the badge of coming-soon levels.
  static const String comingSoonLabel = 'به‌زودی';

  static McqLevel? fromId(String id) {
    for (final level in values) {
      if (level.id == id) {
        return level;
      }
    }
    return null;
  }
}
