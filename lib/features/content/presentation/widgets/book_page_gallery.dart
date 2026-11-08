import 'package:flutter/material.dart';

/// Displays only page scans explicitly supplied from the official textbook PDF.
/// No stock/illustrative imagery is used as a substitute for book pages.
class BookPageGallery extends StatelessWidget {
  const BookPageGallery({super.key, required this.pageAssets});
  final List<String> pageAssets;

  @override
  Widget build(BuildContext context) {
    if (pageAssets.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Column(
          children: [
            Icon(Icons.menu_book_rounded, size: 34),
            SizedBox(height: 8),
            Text('تصویر صفحهٔ کتاب برای این بخش هنوز ثبت نشده است.',
                textAlign: TextAlign.center),
            SizedBox(height: 4),
            Text('برای جلوگیری از نمایش تصویر اشتباه، فقط اسکن واقعی کتاب نمایش داده می‌شود.',
                textAlign: TextAlign.center),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < pageAssets.length; i++) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 8, top: 8),
            child: Text('تصویر کتاب ' + (i + 1).toString(),
                style: Theme.of(context).textTheme.labelLarge),
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: ColoredBox(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: InteractiveViewer(
                minScale: 1,
                maxScale: 4,
                child: Image.asset(
                  pageAssets[i],
                  fit: BoxFit.contain,
                  width: double.infinity,
                  errorBuilder: (context, error, stack) => const Padding(
                    padding: EdgeInsets.all(20),
                    child: Text('تصویر صفحه در این نسخه پیدا نشد.'),
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
