import 'package:flutter/material.dart';
import 'package:hamyar_hashtom_plus/core/widgets/feature_placeholder.dart';

class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const FeaturePlaceholder(
      title: 'علاقه‌مندی‌ها',
      icon: Icons.bookmark_rounded,
      message: 'مطالب نشان‌شده شما اینجا نمایش داده می‌شود.\nاین بخش در مراحل بعدی اضافه می‌شود.',
    );
  }
}
