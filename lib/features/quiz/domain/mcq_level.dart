/// Difficulty levels of the Multiple-Choice Tests section.
///
/// SAMPAD is a difficulty level alongside Easy, Intermediate and Advanced.
/// Levels flagged [isComingSoon] stay visible but must never open an empty
/// exam.
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
  ),
  advanced(
    id: 'advanced',
    title: 'پیشرفته',
    subtitle: 'پرسش‌های چالشی و استدلالی',
    isComingSoon: false,
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
  });

  /// Stable identifier, safe to use in keys and future route parameters.
  final String id;

  /// Persian display title.
  final String title;

  /// One-line Persian description.
  final String subtitle;

  /// Whether the level is announced but has no exam content yet.
  final bool isComingSoon;

  /// Label shown on the badge of coming-soon levels.
  static const String comingSoonLabel = 'به‌زودی';
}
