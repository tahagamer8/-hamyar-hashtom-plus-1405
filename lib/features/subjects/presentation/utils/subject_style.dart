import 'package:flutter/material.dart';

class SubjectStyle {
  const SubjectStyle(this.icon, this.color);

  final IconData icon;
  final Color color;
}

SubjectStyle styleForSubject(String id) {
  switch (id) {
    case 'math':
      return const SubjectStyle(Icons.calculate_rounded, Color(0xFF4F46E5));
    case 'science':
      return const SubjectStyle(Icons.science_rounded, Color(0xFF0EA5A4));
    case 'persian':
      return const SubjectStyle(Icons.menu_book_rounded, Color(0xFFE11D48));
    case 'writing':
      return const SubjectStyle(Icons.edit_note_rounded, Color(0xFFF59E0B));
    case 'arabic':
      return const SubjectStyle(Icons.translate_rounded, Color(0xFF16A34A));
    case 'social':
      return const SubjectStyle(Icons.public_rounded, Color(0xFF0284C7));
    case 'english':
      return const SubjectStyle(Icons.language_rounded, Color(0xFF7C3AED));
    case 'religion':
      return const SubjectStyle(Icons.auto_stories_rounded, Color(0xFF0D9488));
    case 'quran':
      return const SubjectStyle(Icons.import_contacts_rounded, Color(0xFF65A30D));
    case 'thinking':
      return const SubjectStyle(Icons.psychology_rounded, Color(0xFFDB2777));
    case 'work':
      return const SubjectStyle(Icons.construction_rounded, Color(0xFFEA580C));
    case 'culture_art':
      return const SubjectStyle(Icons.palette_rounded, Color(0xFFBE185D));
    case 'from_me_to_god':
      return const SubjectStyle(Icons.favorite_rounded, Color(0xFF0F766E));
    default:
      return const SubjectStyle(Icons.book_rounded, Color(0xFF4F46E5));
  }
}
