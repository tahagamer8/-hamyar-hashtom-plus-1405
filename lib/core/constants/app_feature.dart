import 'package:flutter/material.dart';

/// امکانات اصلی برنامه؛ هم در صفحه اصلی و هم در صفحه هر درس استفاده می‌شود.
enum AppFeature {
  lessons('آموزش فصل‌به‌فصل', Icons.school_rounded, Color(0xFF4F46E5)),
  notes('جزوه (PDF)', Icons.picture_as_pdf_rounded, Color(0xFF0EA5A4)),
  solutions('گام‌به‌گام', Icons.fact_check_rounded, Color(0xFFF59E0B)),
  sampleExams('نمونه‌سؤال (PDF)', Icons.picture_as_pdf_rounded, Color(0xFFE11D48)),
  lessonQuestions('سؤالات هر درس', Icons.quiz_outlined, Color(0xFF0D9488)),
  quiz('آزمون جامع', Icons.quiz_rounded, Color(0xFF7C3AED)),
  favorites('علاقه‌مندی‌ها', Icons.bookmark_rounded, Color(0xFF0284C7));

  const AppFeature(this.title, this.icon, this.color);

  final String title;
  final IconData icon;
  final Color color;

  /// آیا این امکان بخشی از یک درس است؟
  bool get isSubjectSection => this != AppFeature.favorites;
}
