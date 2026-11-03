import 'package:flutter/material.dart';

/// امکانات اصلی برنامه؛ هم در صفحه اصلی و هم در صفحه هر درس استفاده می‌شود.
enum AppFeature {
  lessons('آموزش فصل‌به‌فصل', Icons.school_rounded, Color(0xFF4F46E5)),
  notes('جزوه و خلاصه', Icons.description_rounded, Color(0xFF0EA5A4)),
  solutions('گام‌به‌گام', Icons.fact_check_rounded, Color(0xFFF59E0B)),
  sampleExams('نمونه‌سؤال', Icons.assignment_rounded, Color(0xFFE11D48)),
  quiz('آزمون', Icons.quiz_rounded, Color(0xFF7C3AED)),
  favorites('علاقه‌مندی‌ها', Icons.bookmark_rounded, Color(0xFF0284C7));

  const AppFeature(this.title, this.icon, this.color);

  final String title;
  final IconData icon;
  final Color color;

  /// آیا این امکان بخشی از یک درس است؟
  bool get isSubjectSection => this != AppFeature.favorites;
}
