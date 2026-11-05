import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hamyar_hashtom_plus/core/constants/app_feature.dart';

class ContentLibraryScreen extends StatefulWidget {
  const ContentLibraryScreen({
    super.key,
    required this.subjectId,
    required this.featureId,
  });

  final String subjectId;
  final String featureId;

  @override
  State<ContentLibraryScreen> createState() => _ContentLibraryScreenState();
}

class _ContentLibraryScreenState extends State<ContentLibraryScreen> {
  Future<Map<String, dynamic>>? _contentFuture;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _contentFuture ??= _loadContent(DefaultAssetBundle.of(context));
  }

  Future<Map<String, dynamic>> _loadContent(AssetBundle bundle) async {
    final raw = await bundle.loadString('assets/content/catalog_fa.json');
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    final subject = decoded[widget.subjectId];
    if (subject is! Map<String, dynamic>) {
      throw StateError('محتوای این درس هنوز ثبت نشده است.');
    }
    return subject;
  }

  AppFeature get _feature => AppFeature.values.firstWhere(
        (item) => item.name == widget.featureId,
        orElse: () => AppFeature.lessons,
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_feature.title)),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _contentFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'محتوای این بخش هنوز آماده نشده است.\n'
                  'می‌توانی بعداً دوباره بررسی کنی.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          final subject = snapshot.data!;
          final chapters = (subject['chapters'] as List<dynamic>? ?? [])
              .cast<Map<String, dynamic>>();
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(subject['title'] as String? ?? 'درس',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 6),
              Text('محتوای آموزشی تألیفی فهمینو',
                  style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 16),
              for (final chapter in chapters)
                _ChapterContent(
                  chapter: chapter,
                  feature: _feature,
                ),
            ],
          );
        },
      ),
    );
  }
}

class _ChapterContent extends StatelessWidget {
  const _ChapterContent({required this.chapter, required this.feature});
  final Map<String, dynamic> chapter;
  final AppFeature feature;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = chapter['title'] as String? ?? 'درس';
    final summary = chapter['summary'] as String? ?? '';
    final points = (chapter['points'] as List<dynamic>? ?? []).cast<String>();
    final steps = (chapter['solutionSteps'] as List<dynamic>? ?? [])
        .cast<String>();
    final questions =
        (chapter['questions'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();

    if (feature == AppFeature.quiz) {
      return _QuizChapter(title: title, questions: questions);
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.titleMedium),
            const SizedBox(height: 10),
            if (feature == AppFeature.lessons) ...[
              Text(summary, style: theme.textTheme.bodyMedium),
              if (points.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text('نکته‌های کلیدی', style: theme.textTheme.titleSmall),
                for (final point in points)
                  _Bullet(text: point),
              ],
            ] else if (feature == AppFeature.notes) ...[
              for (final point in points) _Bullet(text: point),
            ] else if (feature == AppFeature.solutions) ...[
              Text(chapter['example'] as String? ?? 'مثال آموزشی',
                  style: theme.textTheme.bodyMedium),
              const SizedBox(height: 10),
              for (var i = 0; i < steps.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(radius: 12, child: Text('${i + 1}')),
                      const SizedBox(width: 10),
                      Expanded(child: Text(steps[i])),
                    ],
                  ),
                ),
            ] else if (feature == AppFeature.sampleExams) ...[
              for (var i = 0; i < questions.length; i++)
                _ReadOnlyQuestion(question: questions[i], number: i + 1),
            ],
          ],
        ),
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 7),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('•  '),
            Expanded(child: Text(text)),
          ],
        ),
      );
}

class _ReadOnlyQuestion extends StatelessWidget {
  const _ReadOnlyQuestion({required this.question, required this.number});
  final Map<String, dynamic> question;
  final int number;

  @override
  Widget build(BuildContext context) {
    final options = (question['options'] as List<dynamic>? ?? []).cast<String>();
    final answer = question['answer'] as int? ?? -1;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$number. ${question['question']}',
              style: Theme.of(context).textTheme.titleSmall),
          for (var i = 0; i < options.length; i++)
            Padding(
              padding: const EdgeInsets.only(top: 5),
              child: Text('${String.fromCharCode(65 + i)}) ${options[i]}'),
            ),
          const SizedBox(height: 5),
          Text('پاسخ: ${answer >= 0 && answer < options.length ? options[answer] : 'ثبت نشده'}',
              style: TextStyle(color: Theme.of(context).colorScheme.primary)),
          if (question['explanation'] is String)
            Text(question['explanation'] as String),
          const Divider(height: 24),
        ],
      ),
    );
  }
}

class _QuizChapter extends StatefulWidget {
  const _QuizChapter({required this.title, required this.questions});
  final String title;
  final List<Map<String, dynamic>> questions;

  @override
  State<_QuizChapter> createState() => _QuizChapterState();
}

class _QuizChapterState extends State<_QuizChapter> {
  final Map<int, int> _answers = {};
  final Set<int> _checked = {};

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.title, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text('پاسخ‌ها را انتخاب کن و نتیجه را بررسی کن.'),
            for (var q = 0; q < widget.questions.length; q++)
              _buildQuestion(context, q, widget.questions[q]),
            if (widget.questions.isNotEmpty)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => setState(() {
                    _answers.clear();
                    _checked.clear();
                  }),
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('شروع دوباره'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestion(
      BuildContext context, int index, Map<String, dynamic> question) {
    final options =
        (question['options'] as List<dynamic>? ?? []).cast<String>();
    final correct = question['answer'] as int? ?? -1;
    final checked = _checked.contains(index);
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${index + 1}. ${question['question']}',
              style: Theme.of(context).textTheme.titleSmall),
          for (var option = 0; option < options.length; option++)
            RadioListTile<int>(
              dense: true,
              contentPadding: EdgeInsets.zero,
              value: option,
              groupValue: _answers[index],
              onChanged: checked
                  ? null
                  : (value) => setState(() => _answers[index] = value!),
              title: Text(options[option]),
            ),
          if (!checked)
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.tonal(
                onPressed: _answers.containsKey(index)
                    ? () => setState(() => _checked.add(index))
                    : null,
                child: const Text('بررسی پاسخ'),
              ),
            )
          else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: ( _answers[index] == correct
                        ? Colors.green
                        : Theme.of(context).colorScheme.error)
                    .withAlpha(18),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${_answers[index] == correct ? 'آفرین، پاسخ درست است.' : 'پاسخ درست: ${correct >= 0 && correct < options.length ? options[correct] : 'ثبت نشده'}'}\n'
                '${question['explanation'] ?? ''}',
              ),
            ),
          const Divider(height: 24),
        ],
      ),
    );
  }
}
