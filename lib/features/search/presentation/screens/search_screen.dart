import 'package:flutter/material.dart';
import 'package:hamyar_hashtom_plus/core/widgets/feature_placeholder.dart';

class SearchScreen extends StatelessWidget {
  const SearchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const FeaturePlaceholder(
      title: 'جست‌وجو',
      icon: Icons.search_rounded,
      message: 'جست‌وجوی سریع در درس‌ها، جزوه‌ها و سؤال‌ها\nدر مراحل بعدی اضافه می‌شود.',
    );
  }
}
