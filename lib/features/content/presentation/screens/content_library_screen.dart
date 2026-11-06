import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hamyar_hashtom_plus/features/favorites/presentation/providers/favorites_provider.dart';
import 'package:hamyar_hashtom_plus/core/constants/app_feature.dart';
import 'package:hamyar_hashtom_plus/features/quiz/presentation/screens/timed_combined_exam_screen.dart';

class ContentLibraryScreen extends ConsumerStatefulWidget {
  const ContentLibraryScreen({
    super.key,
    required this.subjectId,
    required this.featureId,
  });

  final String subjectId;
  final String featureId;

  @override
  ConsumerState<ContentLibraryScreen> createState() => _ContentLibraryScreenState();
}

class _ContentLibraryScreenState extends ConsumerState<ContentLibraryScreen> {
  Future<Map<String, dynamic>>? _contentFuture;
  int _selectedChapterIndex = 0;

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
      appBar: _feature == AppFeature.quiz
          ? AppBar(title: const Text('آزمون فصل انتخاب‌شده'))
          : AppBar(title: Text(_feature.title)),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _contentFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
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
          if (chapters.isEmpty) {
            return const Center(child: Text('برای این کتاب فصلی ثبت نشده است.'));
          }

          final safeIndex = _selectedChapterIndex.clamp(0, chapters.length - 1);
          final selectedChapter = chapters[safeIndex];

          if (_feature == AppFeature.quiz) {
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _ChapterPicker(
                  chapters: chapters,
                  selectedIndex: safeIndex,
                  onChanged: (index) => setState(() => _selectedChapterIndex = index),
                ),
                const SizedBox(height: 12),
                TimedCombinedExamScreen(
                  subjectTitle: subject['title'] as String? ?? 'درس',
                  chapters: [selectedChapter],
                ),
              ],
            );
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                subject['title'] as String? ?? 'درس',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              _ChapterPicker(
                chapters: chapters,
                selectedIndex: safeIndex,
                onChanged: (index) => setState(() => _selectedChapterIndex = index),
              ),
              const SizedBox(height: 12),
              _ChapterContent(
                chapter: selectedChapter,
                feature: _feature,
                favoriteKey: widget.subjectId + '::' +
                    (selectedChapter['title']?.toString() ?? ''),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ChapterPicker extends StatelessWidget {
  const _ChapterPicker({
    required this.chapters,
    required this.selectedIndex,
    required this.onChanged,
  });

  final List<Map<String, dynamic>> chapters;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('انتخاب فصل یا درس', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            DropdownButtonFormField<int>(
              value: selectedIndex,
              isExpanded: true,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              items: [
                for (var i = 0; i < chapters.length; i++)
                  DropdownMenuItem<int>(
                    value: i,
                    child: Text(
                      chapters[i]['title'] as String? ?? ('بخش ' + (i + 1).toString()),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: (value) {
                if (value != null) onChanged(value);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ChapterContent extends ConsumerWidget {
  const _ChapterContent({
    required this.chapter,
    required this.feature,
    required this.favoriteKey,
  });

  final Map<String, dynamic> chapter;
  final AppFeature feature;
  final String favoriteKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final title = chapter['title'] as String? ?? 'درس';
    final summary = chapter['summary'] as String? ?? '';
    final points = (chapter['points'] as List<dynamic>? ?? []).cast<String>();
    final example = chapter['example'] as String? ?? '';
    final steps = (chapter['solutionSteps'] as List<dynamic>? ?? []).cast<String>();
    final questions =
        (chapter['questions'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
    final bookSolutions =
        (chapter['bookSolutions'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(title, style: theme.textTheme.titleMedium)),
                IconButton(
                  tooltip: ref.watch(favoritesProvider).contains(favoriteKey)
                      ? 'حذف از علاقه‌مندی‌ها'
                      : 'افزودن به علاقه‌مندی‌ها',
                  onPressed: () =>
                      ref.read(favoritesProvider.notifier).toggle(favoriteKey),
                  icon: Icon(
                    ref.watch(favoritesProvider).contains(favoriteKey)
                        ? Icons.bookmark_rounded
                        : Icons.bookmark_add_outlined,
                  ),
                ),
              ],
            ),
            const Divider(),
            if (feature == AppFeature.lessons) ...[
              Text('آموزش این بخش', style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              Text(summary, style: theme.textTheme.bodyMedium),
              if (points.isNotEmpty) ...[
                const SizedBox(height: 14),
                Text('نکته‌های مهم', style: theme.textTheme.titleSmall),
                for (final point in points) _Bullet(text: point),
              ],
              if (example.isNotEmpty) ...[
                const SizedBox(height: 14),
                Text('مثال آموزشی', style: theme.textTheme.titleSmall),
                Text(example),
                for (var i = 0; i < steps.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(radius: 12, child: Text((i + 1).toString())),
                        const SizedBox(width: 10),
                        Expanded(child: Text(steps[i])),
                      ],
                    ),
                  ),
              ],
            ] else if (feature == AppFeature.notes) ...[
              Text('جزوه و نکته‌های این فصل', style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              Text(summary),
              const SizedBox(height: 10),
              for (final point in points) _Bullet(text: point),
              const SizedBox(height: 10),
              Text(
                'این بخش فعلاً نکته‌های ثبت‌شده را نشان می‌دهد؛ جزوه‌های PDF باید به تفکیک همین فصل به فهرست منابع اضافه شوند.',
                style: theme.textTheme.bodySmall,
              ),
            ] else if (feature == AppFeature.solutions) ...[
              Text('پاسخ تمرین‌ها و فعالیت‌های کتاب', style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              if (bookSolutions.isEmpty)
                const _MissingBookSolutions()
              else
                for (final item in bookSolutions) _BookSolutionItem(item: item),
            ] else if (feature == AppFeature.sampleExams) ...[
              Text('نمونه‌سؤال‌های این فصل', style: theme.textTheme.titleSmall),
              for (var i = 0; i < questions.length; i++)
                _ReadOnlyQuestion(question: questions[i], number: i + 1),
              if (questions.isEmpty)
                const Text('برای این فصل هنوز نمونه‌سؤالی ثبت نشده است.'),
            ],
          ],
        ),
      ),
    );
  }
}

class _MissingBookSolutions extends StatelessWidget {
  const _MissingBookSolutions();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Text(
        'پاسخ‌های فعالیت‌ها و تمرین‌های خودِ کتاب هنوز برای این فصل با نسخهٔ رسمی کتاب تطبیق و ثبت نشده‌اند. برای جلوگیری از نمایش جواب ساختگی، فعلاً پاسخ نمونه یا مثال آموزشی را به‌جای گام‌به‌گام کتاب نشان نمی‌دهیم.',
      ),
    );
  }
}

class _BookSolutionItem extends StatelessWidget {
  const _BookSolutionItem({required this.item});
  final Map<String, dynamic> item;

  @override
  Widget build(BuildContext context) {
    final page = item['page']?.toString() ?? '—';
    final prompt = item['question'] as String? ?? '';
    final answer = item['answer'] as String? ?? '';
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('صفحه ' + page, style: Theme.of(context).textTheme.labelLarge),
          if (prompt.isNotEmpty) Text(prompt),
          if (answer.isNotEmpty) Text('پاسخ تشریحی: ' + answer),
          const Divider(height: 24),
        ],
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

class _ReadOnlyQuestion extends StatefulWidget {
  const _ReadOnlyQuestion({required this.question, required this.number});
  final Map<String, dynamic> question;
  final int number;

  @override
  State<_ReadOnlyQuestion> createState() => _ReadOnlyQuestionState();
}

class _ReadOnlyQuestionState extends State<_ReadOnlyQuestion> {
  bool _showAnswer = false;

  @override
  Widget build(BuildContext context) {
    final options = (widget.question['options'] as List<dynamic>? ?? []).cast<String>();
    final answer = widget.question['answer'] as int? ?? -1;
    final hasAnswer = answer >= 0 && answer < options.length;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${widget.number}. ${widget.question['question']}',
              style: Theme.of(context).textTheme.titleSmall),
          for (var i = 0; i < options.length; i++)
            Padding(
              padding: const EdgeInsets.only(top: 5),
              child: Text('${String.fromCharCode(65 + i)}) ${options[i]}'),
            ),
          const SizedBox(height: 5),
          TextButton.icon(
            onPressed: () => setState(() => _showAnswer = !_showAnswer),
            icon: Icon(_showAnswer ? Icons.visibility_off_outlined : Icons.visibility_outlined),
            label: Text(_showAnswer ? 'پنهان کردن پاسخ' : 'نمایش پاسخ و توضیح'),
          ),
          if (_showAnswer) ...[
            Text(
              'پاسخ: ${hasAnswer ? options[answer] : 'ثبت نشده'}',
              style: TextStyle(color: Theme.of(context).colorScheme.primary),
            ),
            if (widget.question['explanation'] is String)
              Text(widget.question['explanation'] as String),
          ],
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
            const Text('پاسخ‌ها را انتخاب کن و نتیجه را بررسی کن.'),
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
          RadioGroup<int>(
            groupValue: _answers[index],
            onChanged: (value) {
              if (!checked && value != null) {
                setState(() => _answers[index] = value);
              }
            },
            child: IgnorePointer(
              ignoring: checked,
              child: Column(
                children: [
                  for (var option = 0; option < options.length; option++)
                    RadioListTile<int>(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      value: option,
                      title: Text(options[option]),
                    ),
                ],
              ),
            ),
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
