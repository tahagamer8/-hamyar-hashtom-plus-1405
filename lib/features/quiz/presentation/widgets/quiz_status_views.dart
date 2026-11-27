import 'package:flutter/material.dart';

/// Full-screen message with an app bar, used for missing or empty content.
class QuizMessageScaffold extends StatelessWidget {
  const QuizMessageScaffold({
    super.key,
    required this.title,
    required this.message,
  });

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(message, textAlign: TextAlign.center),
        ),
      ),
    );
  }
}

/// Loading scaffold shown while the subject packs are read.
class QuizLoadingScaffold extends StatelessWidget {
  const QuizLoadingScaffold({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: const Center(child: CircularProgressIndicator()),
    );
  }
}

/// Error state with a retry action.
class QuizErrorView extends StatelessWidget {
  const QuizErrorView({super.key, required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded, size: 40, color: colors.error),
            const SizedBox(height: 12),
            const Text(
              'محتوای درس‌ها بارگذاری نشد.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            FilledButton.tonal(
              onPressed: onRetry,
              child: const Text('تلاش دوباره'),
            ),
          ],
        ),
      ),
    );
  }
}
