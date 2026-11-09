import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hamyar_hashtom_plus/features/favorites/presentation/providers/favorites_provider.dart';
import 'package:hamyar_hashtom_plus/core/constants/app_feature.dart';
import 'package:hamyar_hashtom_plus/features/quiz/presentation/screens/timed_combined_exam_screen.dart';
import 'package:hamyar_hashtom_plus/features/documents/presentation/screens/pdf_resource_library_screen.dart';
import 'package:hamyar_hashtom_plus/features/documents/presentation/screens/pdf_viewer_screen.dart';
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
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(subject['title'] as String? ?? 'درس',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 6),
              Text('ابتدا فصل یا درس موردنظرت را انتخاب کن.',
                  style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 14),
              DropdownButtonFormField<int>(
                value: selectedIndex,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'انتخاب فصل یا درس',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.menu_book_rounded),
                ),
                items: [
                  for (var i = 0; i < chapters.length; i++)
                    DropdownMenuItem<int>(
                      value: i,
                      child: Text(
                        '${i + 1}. ${chapters[i]['title'] as String? ?? 'درس'}'
                        '${chapters[i]['pageStart'] is int ? '  •  صفحه ${chapters[i]['pageStart']}' : ''}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (value) => setState(() {
                  _selectedChapterIndex = value ?? 0;
                }),
              ),
              const SizedBox(height: 14),
              _ChapterContent(
                chapter: selectedChapter,
                feature: _feature,
                favoriteKey: '${widget.subjectId}::${selectedChapter['title']}',
                subjectId: widget.subjectId,
                chapterIndex: selectedIndex,
              ),
              if (chapters.length > 1)
                Row(
                  children: [
                    TextButton.icon(
                      onPressed: selectedIndex > 0
                          ? () => setState(() => _selectedChapterIndex = selectedIndex - 1)
                          : null,
                      icon: const Icon(Icons.chevron_right_rounded),
                      label: const Text('درس قبلی'),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: selectedIndex < chapters.length - 1
                          ? () => setState(() => _selectedChapterIndex = selectedIndex + 1)
                          : null,
                      icon: const Icon(Icons.chevron_left_rounded),
                      label: const Text('درس بعدی'),
                    ),
                  ],
                ),
            ],
          );
        },
      ),
    );
  }
}

class _ChapterContent extends ConsumerWidget {
  const _ChapterContent({
    required this.chapter,
    required this.feature,
    required this.favoriteKey,
    required this.subjectId,
    required this.chapterIndex,
  });
  final Map<String, dynamic> chapter;
  final AppFeature feature;
  final String favoriteKey;
  final String subjectId;
  final int chapterIndex;

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

    if (feature == AppFeature.quiz) {
      return _QuizChapter(title: title, questions: questions);
    }
    if (feature == AppFeature.lessonQuestions) {
      final lessonQuestions = [...questions, ...advancedQuestions];
      if (lessonQuestions.isEmpty) {
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Text('برای این درس هنوز پرسشی ثبت نشده است.',
                style: theme.textTheme.bodyMedium),
          ),
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ChapterPdfQuickAccess(
            subjectId: subjectId,
            chapterIndex: chapterIndex,
            chapterTitle: title,
            showNotes: false,
          ),
          _QuizChapter(title: title, questions: lessonQuestions),
        ],
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
            if (feature == AppFeature.lessons) ...[
              const SizedBox(height: 10),
              _ChapterPdfQuickAccess(
                subjectId: subjectId,
                chapterIndex: chapterIndex,
                chapterTitle: title,
              ),
            ],
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

class _ChapterPdfQuickAccess extends StatelessWidget {
  const _ChapterPdfQuickAccess({
    required this.subjectId,
    required this.chapterIndex,
    required this.chapterTitle,
    this.showNotes = true,
  });

  final String subjectId;
  final int chapterIndex;
  final String chapterTitle;
  final bool showNotes;

  String _assetPath(String kind) =>
      'assets/generated_pdfs/chapters/$subjectId/'
      'Fahmino-$subjectId-Chapter-${chapterIndex + 1}-$kind-FA.pdf';

  void _open(BuildContext context, String kind, String label) {
    final path = _assetPath(kind);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PdfViewerScreen.asset(
          title: '$label · $chapterTitle',
          assetPath: path,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.surfaceContainerLow,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(13),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'فایل‌های PDF همین درس',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'فایل‌ها داخل برنامه باز می‌شوند و برای مطالعهٔ آفلاین در دسترس‌اند.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (showNotes)
                  OutlinedButton.icon(
                    onPressed: () => _open(context, 'Notes', 'جزوه PDF'),
                    icon: const Icon(Icons.menu_book_rounded),
                    label: const Text('جزوه PDF'),
                  ),
                FilledButton.tonalIcon(
                  onPressed: () => _open(context, 'Questions', 'نمونه‌سؤال PDF'),
                  icon: const Icon(Icons.quiz_outlined),
                  label: const Text('نمونه‌سؤال PDF'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
