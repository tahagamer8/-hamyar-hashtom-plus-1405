import 'package:flutter/material.dart';

/// امکانات اصلی برنامه؛ هم در صفحه اصلی و هم در صفحه هر درس استفاده می‌شود.
enum AppFeature {
  lessons('آموزش فصل‌به‌فصل', Icons.school_rounded, Color(0xFF4F46E5)),
  notes('جزوه (PDF)', Icons.picture_as_pdf_rounded, Color(0xFF0EA5A4)),
  flashcards('فلش‌کارت مرور', Icons.style_rounded, Color(0xFF059669)),
  solutions('گام‌به‌گام', Icons.fact_check_rounded, Color(0xFFF59E0B)),
  sampleExams('نمونه‌سؤال (PDF)', Icons.picture_as_pdf_rounded, Color(0xFFE11D48)),
  lessonQuestions('سؤالات هر درس', Icons.quiz_outlined, Color(0xFF0D9488)),
  quiz('آزمون جامع', Icons.quiz_rounded, Color(0xFF7C3AED)),
  favorites('علاقه‌مندی‌ها', Icons.bookmark_rounded, Color(0xFF0284C7)),
  studyPlanner('برنامه‌ریز امتحان', Icons.event_note_rounded, Color(0xFF0F766E)),
  mistakes('مرور اشتباهات', Icons.history_edu_rounded, Color(0xFFB45309));

  const AppFeature(this.title, this.icon, this.color);

  final String title;
  final IconData icon;
  final Color color;

  String get description => switch (this) {
        AppFeature.lessons => 'آموزش مفاهیم، مثال‌ها و نکته‌های فصل',
        AppFeature.notes => 'جزوه‌های PDF فصل‌به‌فصل و مرور آفلاین',
        AppFeature.flashcards => 'مرور فعال نکته‌ها و پرسش‌ها با کارت‌های تعاملی',
        AppFeature.solutions => 'حل تمرین‌ها با راه‌حل مرحله‌به‌مرحله',
        AppFeature.sampleExams => 'نمونه‌سؤال‌های PDF از منابع آموزشی',
        AppFeature.lessonQuestions => 'پرسش‌های تعاملی هر فصل همراه پاسخ و توضیح',
        AppFeature.quiz => 'آزمون زمان‌دار با نتیجه و توضیح پاسخ',
        AppFeature.favorites => 'مطالب نشان‌شده و ذخیره‌شدهٔ تو',
        AppFeature.studyPlanner => 'برنامهٔ روزانه و زمان‌بندی امتحان‌ها',
        AppFeature.mistakes => 'سؤال‌های نادرست و بی‌پاسخ با توضیح پاسخ',
      };

  /// آیا این امکان بخشی از یک درس است؟
  bool get isSubjectSection => this != AppFeature.favorites && this != AppFeature.studyPlanner && this != AppFeature.mistakes;
}
