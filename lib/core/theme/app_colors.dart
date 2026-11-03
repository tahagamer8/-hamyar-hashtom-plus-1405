import 'package:flutter/material.dart';

abstract final class AppColors {
  static const Color primary = Color(0xFF4F46E5);
  static const Color primaryDark = Color(0xFF3730A3);
  static const Color secondary = Color(0xFF0EA5A4);
  static const Color accent = Color(0xFFF59E0B);

  static const Color lightBackground = Color(0xFFF5F6FB);
  static const Color darkBackground = Color(0xFF0E1120);
  static const Color darkSurface = Color(0xFF171B2E);

  /// رنگ کارت‌ها بر اساس تم فعلی
  static Color card(BuildContext context) {
    return Theme.of(context).brightness == Brightness.light
        ? Colors.white
        : darkSurface;
  }
}
