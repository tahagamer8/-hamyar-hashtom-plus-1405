import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hamyar_hashtom_plus/features/favorites/presentation/providers/favorites_provider.dart';
import 'package:hamyar_hashtom_plus/features/progress/presentation/providers/learning_progress_provider.dart';
import 'package:hamyar_hashtom_plus/core/constants/app_feature.dart';
import 'package:hamyar_hashtom_plus/features/quiz/presentation/screens/timed_combined_exam_screen.dart';
import 'package:hamyar_hashtom_plus/features/documents/presentation/screens/pdf_resource_library_screen.dart';
import 'package:hamyar_hashtom_plus/features/documents/presentation/widgets/subject_pdf_card.dart';
import 'package:hamyar_hashtom_plus/features/content/presentation/widgets/book_page_gallery.dart';

class ContentLibraryScreen extends ConsumerStatefulWidget {
  const ContentLibraryScreen({
    super.key,
    required this.subjectId,
    required this.featureId,
    this.initialChapterIndex = 0,
  });

  final String subjectId;
  final String featureId;
  final int initialChapterIndex;

  @override
  ConsumerState<ContentLibraryScreen> createState() => _ContentLibraryScreenState();
}

class _ContentLibraryScreenState extends ConsumerState<ContentLibraryScreen> {
  Future<Map<String, dynamic>>? _contentFuture;
  int _selectedChapterIndex = 0;

  @override
  void initState() {
    super.initState();
    _selectedChapterIndex = widget.initialChapterIndex < 0 ? 0 : widget.initialChapterIndex;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _contentFuture ??= _loadContent(DefaultAssetBundle.of(context), widget.subjectId);
  }

  @override
  void didUpdateWidget(covariant ContentLibraryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.subjectId != widget.subjectId ||
        oldWidget.initialChapterIndex != widget.initialChapterIndex) {
      _selectedChapterIndex = widget.initialChapterIndex < 0 ? 0 : widget.initialChapterIndex;
      _contentFuture = _loadContent(DefaultAssetBundle.of(context), widget.subjectId);
    }
  }

  bool _isValidSubjectPack(Map<String, dynamic> subject) {
    if (subject['title'] is! String || (subject['title'] as String).trim().isEmpty) {
      return false;
    }
    final chapters = subject['chapters'];
    if (chapters is! List || chapters.isEmpty) return false;
    return chapters.every((value) {
      if (value is! Map<String, dynamic>) return false;
      final title = value['title'];
      final summary = value['summary'];
      final points = value['points'];
      final example = value['example'];
      final steps = value['solutionSteps'];
      final questions = value['questions'];
      final advancedQuestions = value['advancedQuestions'];
      if (title is! String || title.trim().isEmpty ||
          summary is! String || points is! List ||
          !points.every((item) => item is String) ||
          example is! String || steps is! List ||
          !steps.every((item) => item is String) ||
          questions is! List ||
          (advancedQuestions != null && advancedQuestions is! List)) {
        return false;
      }
      final allQuestions = [
        ...questions,
        ...(advancedQuestions as List<dynamic>? ?? const []),
      ];
      return allQuestions.every((item) {
        if (item is! Map<String, dynamic>) return false;
        final options = item['options'];
        final answer = item['answer'];
        return item['question'] is String &&
            (item['question'] as String).trim().isNotEmpty &&
            options is List && options.length >= 2 &&
            options.every((option) => option is String) &&
            answer is int && answer >= 0 && answer < options.length &&
            item['explanation'] is String;
      });
    });
  }

  Future<Map<String, dynamic>> _loadContent(
      AssetBundle bundle, String subjectId) async {
    // Prefer a separately versioned pack, but reject malformed data before UI casts.
    try {
      final raw = await bundle.loadString('assets/content/subjects/$subjectId.json');
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic> &&
          decoded['subjectId'] == subjectId &&
          _isValidSubjectPack(decoded)) {
        return decoded;
      }
    } on FlutterError {
      // Use the legacy catalog for older installations.
    } on FormatException {
      // Use the legacy catalog if a pack is malformed JSON.
    } on TypeError {
      // Reject malformed pack shape and try the legacy catalog.
    }

    final raw = await bundle.loadString('assets/content/catalog_fa.json');
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      throw StateError('ساختار فهرست محتوای برنامه معتبر نیست.');
    }
    final subject = decoded[subjectId];
    if (subject is! Map<String, dynamic> ||
        !_isValidSubjectPack(subject)) {
      throw StateError('محتوای این درس ناقص یا نامعتبر است.');
    }
    return subject;
  }

  AppFeature get _feature => AppFeature.values.firstWhere(
        (item) => item.name == widget.featureId,
        orElse: () => AppFeature.lessons,
      );

  @override
  Widget build(BuildContext context) {
    final completedKeys = ref.watch(learningProgressProvider);
    return Scaffold(
      appBar: _feature == AppFeature.quiz ? null : AppBar(title: Text(_feature.title)),
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
          if (_feature == AppFeature.quiz) {
            return TimedCombinedExamScreen(
              subjectTitle: subject['title'] as String? ?? 'درس',
              chapters: chapters,
            );
          }
          if (_feature == AppFeature.notes ||
              _feature == AppFeature.sampleExams) {
            return PdfResourceLibraryScreen(
              subjectId: widget.subjectId,
              subjectTitle: subject['title'] as String? ?? 'درس',
              chapters: chapters,
              kind: _feature == AppFeature.notes
                  ? PdfResourceKind.notes
                  : PdfResourceKind.samples,
              initialChapterIndex: widget.initialChapterIndex,
            );
          }
          if (chapters.isEmpty) {
            return const Center(child: Text('برای این درس هنوز فصلی ثبت نشده است.'));
          }
          final selectedIndex = _selectedChapterIndex < 0
              ? 0
              : (_selectedChapterIndex >= chapters.length ? chapters.length - 1 : _selectedChapterIndex);
          final selectedChapter = chapters[selectedIndex];
          final completedCount = chapters.where((chapter) =>
              completedKeys.contains('${widget.subjectId}::${chapter['title']}')).length;
          final sourceValue = subject['textbookSource'];
          final sourceMap = sourceValue is Map<String, dynamic> ? sourceValue : null;
          final sourceUrl = sourceMap?['pdfUrl'];
          final sourceUri =
              sourceUrl is String ? Uri.tryParse(sourceUrl) : null;
          final officialSourceUrl = sourceUri != null &&
                  const {'http', 'https'}.contains(sourceUri.scheme) &&
                  sourceUri.host == 'chap.sch.ir'
              ? sourceUrl as String
              : null;
          return CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _LearningPageHeader(
                      subjectTitle: subject['title'] as String? ?? 'درس',
                      feature: _feature,
                      chapterCount: chapters.length,
                    ),
                    const SizedBox(height: 14),
                    _LearningProgressCard(
                      completed: completedCount,
                      total: chapters.length,
                    ),
                    if (_feature == AppFeature.lessons) ...[
                      const SizedBox(height: 12),
                      SubjectPdfCard(
                        subjectId: widget.subjectId,
                        subjectTitle: subject['title'] as String? ?? 'درس',
                      ),
                      if (officialSourceUrl != null)
                        _OfficialTextbookSourceCard(url: officialSourceUrl),
                    ],
                    const SizedBox(height: 18),
                    _ChapterIndexSelector(
                      count: chapters.length,
                      selectedIndex: selectedIndex,
                      onSelected: (index) =>
                          setState(() => _selectedChapterIndex = index),
                    ),
                    const SizedBox(height: 12),
                    _ChapterContent(
                      chapter: selectedChapter,
                      feature: _feature,
                      favoriteKey: '${widget.subjectId}::${selectedChapter['title']}',
                      progressKey: '${widget.subjectId}::${selectedChapter['title']}',
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: selectedIndex > 0
                                ? () => setState(
                                      () => _selectedChapterIndex = selectedIndex - 1,
                                    )
                                : null,
                            icon: const Icon(Icons.chevron_right_rounded),
                            label: const Text('بخش قبلی'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: selectedIndex < chapters.length - 1
                                ? () => setState(
                                      () => _selectedChapterIndex = selectedIndex + 1,
                                    )
                                : null,
                            icon: const Icon(Icons.chevron_left_rounded),
                            label: const Text('بخش بعدی'),
                          ),
                        ),
                      ],
                    ),
                  ]),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ChapterContent extends ConsumerWidget {
  const _ChapterContent({required this.chapter, required this.feature, required this.favoriteKey, required this.progressKey});
  final Map<String, dynamic> chapter;
  final AppFeature feature;
  final String favoriteKey;
  final String progressKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final title = chapter['title'] as String? ?? 'درس';
    final summary = chapter['summary'] as String? ?? '';
    final points = (chapter['points'] as List<dynamic>? ?? []).cast<String>();
    final steps = (chapter['solutionSteps'] as List<dynamic>? ?? [])
        .cast<String>();
    final mistakes = (chapter['commonMistakes'] as List<dynamic>? ?? [])
        .whereType<String>()
        .toList(growable: false);
    final questions =
        (chapter['questions'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
    final advancedQuestions =
        (chapter['advancedQuestions'] as List<dynamic>? ?? [])
            .cast<Map<String, dynamic>>();
    final pageAssets = (chapter['bookPageImages'] as List<dynamic>? ?? [])
        .whereType<String>()
        .toList(growable: false);
    final isCompleted = ref.watch(learningProgressProvider).contains(progressKey);

    if (feature == AppFeature.quiz) {
      return _QuizChapter(title: title, questions: questions);
    }
    if (feature == AppFeature.lessonQuestions) {
      return _QuizChapter(
        title: title,
        questions: [...questions, ...advancedQuestions],
      );
    }

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
                  tooltip: ref.watch(favoritesProvider).contains(favoriteKey) ? 'حذف از علاقه‌مندی‌ها' : 'افزودن به علاقه‌مندی‌ها',
                  onPressed: () => ref.read(favoritesProvider.notifier).toggle(favoriteKey),
                  icon: Icon(ref.watch(favoritesProvider).contains(favoriteKey) ? Icons.bookmark_rounded : Icons.bookmark_add_outlined),
                ),
              ],
            ),
            if (chapter['pageStart'] is int) ...[
              const SizedBox(height: 4),
              Text(
                chapter['pageEnd'] is int
                    ? 'محدودهٔ کتاب درسی: صفحه ${chapter['pageStart']} تا ${chapter['pageEnd']}'
                    : 'شروع این بخش در کتاب: صفحه ${chapter['pageStart']}',
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.primary),
              ),
            ],
            if (chapter['curriculumInstruction'] is String &&
                (chapter['curriculumInstruction'] as String).trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.secondaryContainer.withAlpha(110),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline_rounded,
                        color: theme.colorScheme.onSecondaryContainer, size: 19),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        chapter['curriculumInstruction'] as String,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSecondaryContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton.tonalIcon(
                onPressed: () => ref.read(learningProgressProvider.notifier)
                    .setCompleted(progressKey, !isCompleted),
                icon: Icon(isCompleted ? Icons.check_circle_rounded : Icons.task_alt_rounded),
                label: Text(isCompleted ? 'مطالعه شد؛ برداشتن علامت' : 'این بخش را مطالعه کردم'),
              ),
            ),
            if (chapter['textbookLessons'] is List &&
                (chapter['textbookLessons'] as List).isNotEmpty) ...[
              const SizedBox(height: 8),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: const EdgeInsetsDirectional.only(start: 8, bottom: 8),
                leading: const Icon(Icons.menu_book_outlined),
                title: const Text('درس‌های این فصل در کتاب'),
                subtitle: Text('${(chapter['textbookLessons'] as List).length} درس'),
                children: [
                  for (final item in (chapter['textbookLessons'] as List)
                      .whereType<Map<String, dynamic>>())
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(item['title'] as String? ?? 'درس'),
                      trailing: item['pageStart'] is int
                          ? Text('صفحه ${item['pageStart']}')
                          : null,
                    ),
                ],
              ),
            ],
            const SizedBox(height: 10),
            if (feature == AppFeature.notes ||
                feature == AppFeature.solutions ||
                feature == AppFeature.sampleExams) ...[
              BookPageGallery(pageAssets: pageAssets),
              const SizedBox(height: 12),
            ],
            if (feature == AppFeature.lessons) ...[
              Text(summary, style: theme.textTheme.bodyMedium),
              if (points.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text('نکته‌های کلیدی', style: theme.textTheme.titleSmall),
                for (final point in points)
                  _Bullet(text: point),
              ],
              if ((chapter['example'] as String? ?? '').trim().isNotEmpty ||
                  steps.isNotEmpty) ...[
                const SizedBox(height: 10),
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: const EdgeInsetsDirectional.only(
                    start: 8,
                    end: 8,
                    bottom: 12,
                  ),
                  leading: Icon(
                    Icons.psychology_alt_rounded,
                    color: theme.colorScheme.primary,
                  ),
                  title: const Text('نمونهٔ آموزشی و مراحل یادگیری'),
                  subtitle: Text('${steps.length} گام آموزشی'),
                  children: [
                    if ((chapter['example'] as String? ?? '').trim().isNotEmpty)
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Text(
                            chapter['example'] as String,
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                      ),
                    for (var i = 0; i < steps.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              radius: 12,
                              backgroundColor: theme.colorScheme.primaryContainer,
                              child: Text(
                                '${i + 1}',
                                style: TextStyle(
                                  color: theme.colorScheme.onPrimaryContainer,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(child: Text(steps[i])),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
              if (mistakes.isNotEmpty) ...[
                const SizedBox(height: 12),
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  leading: Icon(Icons.lightbulb_outline_rounded,
                      color: theme.colorScheme.tertiary),
                  title: const Text('اشتباهات رایج'),
                  subtitle: Text('${mistakes.length} نکته برای بررسی پاسخ‌ها'),
                  children: [for (final mistake in mistakes) _Bullet(text: mistake)],
                ),
              ],
            ] else if (feature == AppFeature.notes) ...[
              for (final point in points) _Bullet(text: point),
            ] else if (feature == AppFeature.flashcards) ...[
          const SizedBox(height: 12),
          _ContentPanel(
            title: 'کارت‌های مرور این بخش',
            icon: Icons.style_rounded,
            child: _FlashcardDeck(
              cards: [
                for (var i = 0; i < points.length; i++)
                  _StudyFlashcard(
                    front: 'نکتهٔ ' + (i + 1).toString(),
                    back: points[i],
                  ),
                ...questions.map((question) {
                  final options =
                      (question['options'] as List<dynamic>? ?? []).whereType<String>().toList();
                  final answerIndex = question['answer'] as int? ?? -1;
                  final answerText = answerIndex >= 0 && answerIndex < options.length
                      ? options[answerIndex]
                      : 'پاسخ در داده‌ها ثبت نشده است';
                  final explanation = question['explanation'] as String? ?? '';
                  return _StudyFlashcard(
                    front: question['question'] as String? ?? 'پرسش مروری',
                    back: 'پاسخ: ' + answerText + '\n' + explanation,
                  );
                }),
              ],
            ),
          ),
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


class _OfficialTextbookSourceCard extends StatelessWidget {
  const _OfficialTextbookSourceCard({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: ListTile(
        leading: Icon(Icons.menu_book_rounded, color: theme.colorScheme.primary),
        title: const Text('کتاب درسی رسمی (PDF)'),
        subtitle: const Text('دریافت از پایگاه رسمی کتاب‌های درسی'),
        trailing: const Icon(Icons.open_in_new_rounded),
        onTap: () async {
          final uri = Uri.tryParse(url);
          if (uri == null ||
              !const {'http', 'https'}.contains(uri.scheme) ||
              uri.host != 'chap.sch.ir') {
            return;
          }
          final opened = await launchUrl(
            uri,
            mode: LaunchMode.externalApplication,
          );
          if (!opened && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('باز کردن پیوند کتاب ممکن نشد.')),
            );
          }
        },
      ),
    );
  }
}


class _ContentPanel extends StatelessWidget {
  const _ContentPanel({
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: theme.colorScheme.primary, size: 21),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _LearningPageHeader extends StatelessWidget {
  const _LearningPageHeader({required this.subjectTitle, required this.feature, required this.chapterCount});
  final String subjectTitle;
  final AppFeature feature;
  final int chapterCount;

  String get _description => switch (feature) {
    AppFeature.lessons => 'مفهوم را یاد بگیر، مثال ببین و نکته‌ها را مرور کن.',
    AppFeature.notes => 'خلاصه‌ها و نکته‌های مهم را سریع مرور کن.',
    AppFeature.flashcards => 'با یادآوری فعال، نکته‌ها و پرسش‌ها را تمرین کن.',
    AppFeature.solutions => 'راه‌حل‌ها را مرحله‌به‌مرحله دنبال کن.',
    AppFeature.sampleExams => 'نمونه‌سؤال‌های PDF فصل و نیم‌سال را ببین.',
    AppFeature.lessonQuestions => 'پرسش‌های این فصل را حل کن و پاسخ و توضیح را بررسی کن.',
    AppFeature.quiz => 'دانسته‌هایت را با آزمون بسنج.',
    AppFeature.favorites => 'مطالب نشان‌شدهٔ خودت را ببین.',
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [feature.color, Color.lerp(feature.color, const Color(0xFF151B35), 0.22)!],
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(color: Colors.white.withAlpha(38), borderRadius: BorderRadius.circular(16)),
            child: Icon(feature.icon, color: Colors.white, size: 27),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(subjectTitle, style: theme.textTheme.titleLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(_description, style: theme.textTheme.bodySmall?.copyWith(color: Colors.white.withAlpha(230), height: 1.5)),
                const SizedBox(height: 7),
                Text('$chapterCount بخش آموزشی', style: theme.textTheme.labelMedium?.copyWith(color: Colors.white.withAlpha(220))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LearningProgressCard extends StatelessWidget {
  const _LearningProgressCard({required this.completed, required this.total});
  final int completed;
  final int total;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final value = total == 0 ? 0.0 : completed / total;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.trending_up_rounded, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(child: Text('پیشرفت تو در این درس', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800))),
                Text('$completed از $total', style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.w800)),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: LinearProgressIndicator(value: value, minHeight: 8, backgroundColor: theme.colorScheme.surfaceContainerHighest),
            ),
            const SizedBox(height: 7),
            Text(completed == total ? 'همهٔ بخش‌ها را مطالعه کرده‌ای.' : 'بعد از مطالعهٔ هر بخش، آن را علامت بزن تا مسیرت ذخیره شود.', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}

class _ChapterIndexSelector extends StatelessWidget {
  const _ChapterIndexSelector({required this.count, required this.selectedIndex, required this.onSelected});
  final int count;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('انتخاب فصل یا درس', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 3),
        Text('برای جابه‌جایی سریع، شمارهٔ بخش را انتخاب کن.', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        const SizedBox(height: 9),
        SizedBox(
          height: 44,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: count,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) => ChoiceChip(
              selected: index == selectedIndex,
              onSelected: (_) => onSelected(index),
              label: Text('بخش ${index + 1}'),
              showCheckmark: false,
            ),
          ),
        ),
      ],
    );
  }
}


class _StudyFlashcard {
  const _StudyFlashcard({required this.front, required this.back});
  final String front;
  final String back;
}

class _FlashcardDeck extends StatefulWidget {
  const _FlashcardDeck({required this.cards});
  final List<_StudyFlashcard> cards;

  @override
  State<_FlashcardDeck> createState() => _FlashcardDeckState();
}

class _FlashcardDeckState extends State<_FlashcardDeck> {
  int _index = 0;
  bool _showBack = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (widget.cards.isEmpty) {
      return const Text('برای این بخش هنوز کارت مرور ساخته نشده است.');
    }
    final card = widget.cards[_index];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'کارت ' + (_index + 1).toString() + ' از ' + widget.cards.length.toString(),
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: () => setState(() => _showBack = !_showBack),
              icon: Icon(_showBack ? Icons.visibility_off_outlined : Icons.visibility_outlined),
              label: Text(_showBack ? 'دیدن روی کارت' : 'نمایش پاسخ'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Semantics(
          button: true,
          label: _showBack ? 'پاسخ کارت؛ برای برگشت لمس کن' : 'پرسش کارت؛ برای دیدن پاسخ لمس کن',
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => setState(() => _showBack = !_showBack),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              constraints: const BoxConstraints(minHeight: 170),
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _showBack
                    ? theme.colorScheme.primaryContainer
                    : theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: theme.colorScheme.outlineVariant),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _showBack ? Icons.lightbulb_rounded : Icons.touch_app_rounded,
                    size: 28,
                    color: _showBack
                        ? theme.colorScheme.onPrimaryContainer
                        : theme.colorScheme.primary,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _showBack ? card.back : card.front,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium?.copyWith(
                      height: 1.7,
                      fontWeight: FontWeight.w700,
                      color: _showBack
                          ? theme.colorScheme.onPrimaryContainer
                          : theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'برای برگرداندن کارت لمس کن',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: _showBack
                          ? theme.colorScheme.onPrimaryContainer
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _index > 0
                    ? () => setState(() {
                          _index--;
                          _showBack = false;
                        })
                    : null,
                icon: const Icon(Icons.chevron_right_rounded),
                label: const Text('قبلی'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton.icon(
                onPressed: _index < widget.cards.length - 1
                    ? () => setState(() {
                          _index++;
                          _showBack = false;
                        })
                    : null,
                icon: const Icon(Icons.chevron_left_rounded),
                label: const Text('بعدی'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

