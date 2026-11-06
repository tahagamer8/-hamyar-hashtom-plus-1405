import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hamyar_hashtom_plus/core/router/app_routes.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hamyar_hashtom_plus/features/favorites/presentation/providers/favorites_provider.dart';
import 'package:hamyar_hashtom_plus/core/constants/app_feature.dart';
import 'package:hamyar_hashtom_plus/features/quiz/presentation/screens/timed_combined_exam_screen.dart';
import 'package:hamyar_hashtom_plus/features/lessons/data/ai_lesson_cache.dart';

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
  bool _wholeSubjectExam = false;
  bool _initialChapterApplied = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialChapterApplied) {
      _selectedChapterIndex = widget.initialChapterIndex < 0
          ? 0
          : widget.initialChapterIndex;
      _initialChapterApplied = true;
    }
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
          if (chapters.isEmpty) {
            return const Center(child: Text('برای این کتاب فصلی ثبت نشده است.'));
          }

          final safeIndex = _selectedChapterIndex.clamp(0, chapters.length - 1).toInt();
          final selectedChapter = chapters[safeIndex];
          final studyContext = <String, dynamic>{
            'subjectTitle': subject['title'] as String? ?? 'درس',
            'chapterTitle': selectedChapter['title'] as String? ?? 'فصل',
            'bookChapterTitle': selectedChapter['bookChapterTitle'] as String? ?? '',
            'bookScope': selectedChapter['bookScope'] as String? ?? '',
            'alignmentStatus': selectedChapter['alignmentStatus'] as String? ??
                'not_verified_against_1405_1406_pdf',
            'summary': selectedChapter['summary'] as String? ?? '',
            'points': (selectedChapter['points'] as List<dynamic>? ?? [])
                .whereType<String>()
                .take(8)
                .toList(),
            'example': selectedChapter['example'] as String? ?? '',
            'solutionSteps':
                (selectedChapter['solutionSteps'] as List<dynamic>? ?? [])
                    .whereType<String>()
                    .take(8)
                    .toList(),
            'learningSections':
                (selectedChapter['learningSections'] as List<dynamic>? ?? [])
                    .whereType<Map<String, dynamic>>()
                    .take(8)
                    .toList(),
            'sourceLabel': 'محتوای اولیهٔ فهمینو؛ نیازمند تطبیق با کتاب رسمی',
          };

          if (_feature == AppFeature.quiz) {
            final examChapters = _wholeSubjectExam ? chapters : [selectedChapter];
            final examTitle = subject['title'] as String? ?? 'درس';
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Column(
                    children: [
                      SegmentedButton<bool>(
                        segments: const [
                          ButtonSegment(
                            value: false,
                            icon: Icon(Icons.filter_1_rounded),
                            label: Text('فصل انتخابی'),
                          ),
                          ButtonSegment(
                            value: true,
                            icon: Icon(Icons.library_books_rounded),
                            label: Text('کل درس'),
                          ),
                        ],
                        selected: {_wholeSubjectExam},
                        onSelectionChanged: (selection) => setState(
                          () => _wholeSubjectExam = selection.first,
                        ),
                      ),
                      if (!_wholeSubjectExam) ...[
                        const SizedBox(height: 8),
                        _ChapterPicker(
                          chapters: chapters,
                          selectedIndex: safeIndex,
                          onChanged: (index) => setState(
                            () => _selectedChapterIndex = index,
                          ),
                        ),
                      ],
                      const SizedBox(height: 6),
                      Text(
                        'در فصل‌هایی که سؤال چالشی دارند، آزمون آن‌ها را در اولویت قرار می‌دهد.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: TimedCombinedExamScreen(
                    key: ValueKey(
                      _wholeSubjectExam
                          ? 'whole-${widget.subjectId}'
                          : '${widget.subjectId}-${selectedChapter['title']}',
                    ),
                    subjectTitle: examTitle,
                    chapters: examChapters,
                  ),
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
              const SizedBox(height: 8),
              if (_feature != AppFeature.sampleExams) ...[
                OutlinedButton.icon(
                  onPressed: () => context.push(
                    AppRoutes.aiAssistant,
                    extra: studyContext,
                  ),
                  icon: const Icon(Icons.auto_awesome_rounded),
                  label: const Text('پرسش از دستیار دربارهٔ این فصل'),
                ),
                const SizedBox(height: 6),
                FilledButton.icon(
                  onPressed: () => context.push(
                    AppRoutes.aiAssistant,
                    extra: <String, dynamic>{
                      'studyContext': studyContext,
                      'lessonCacheKey': '${widget.subjectId}::$safeIndex',
                      'initialPrompt':
                          'برای درس ${studyContext['subjectTitle']} و فصل ${studyContext['chapterTitle']} یک درسنامهٔ کامل، دقیق و مرحله‌به‌مرحله آماده کن. هدف‌های یادگیری، پیش‌نیازها، بخش‌بندی مفهومی، مثال‌های مستقل و حل‌شده، اشتباه‌های رایج، پنج تمرین تألیفی از متوسط تا دشوار و پاسخ تشریحی آن‌ها را بیاور. فقط مطالب درست و متناسب با پایه هشتم را بنویس. اگر دادهٔ کتاب کافی نیست، بخش تکمیلی را با عنوان «آموزش تکمیلی تألیفی فهمینو» مشخص کن و هیچ شماره صفحه یا پاسخ رسمی حدس نزن.',
                    },
                  ),
                  icon: const Icon(Icons.menu_book_rounded),
                  label: const Text('ساخت درسنامهٔ کامل با Gemini'),
                ),
                const SizedBox(height: 8),
                _DraftContentNotice(feature: _feature),
              ],
              const SizedBox(height: 12),
              _ChapterContent(
                chapter: selectedChapter,
                feature: _feature,
                subjectId: widget.subjectId,
                chapterIndex: safeIndex,
                favoriteKey: widget.subjectId + '::' +
                    (selectedChapter['title']?.toString() ?? ''),
              ),
              if (_feature == AppFeature.lessons)
                _SavedAiLessonCard(
                  key: ValueKey('${widget.subjectId}::$safeIndex'),
                  lessonKey: '${widget.subjectId}::$safeIndex',
                ),
              if (_feature == AppFeature.sampleExams) ...[
                const SizedBox(height: 8),
                _DraftContentNotice(feature: _feature),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _DraftContentNotice extends StatelessWidget {
  const _DraftContentNotice({required this.feature});
  final AppFeature feature;

  @override
  Widget build(BuildContext context) {
    final text = feature == AppFeature.solutions
        ? 'در گام‌به‌گام فقط پاسخ‌هایی نمایش داده می‌شوند که با صفحهٔ کتاب تطبیق داده شده باشند.'
        : 'محتوای آموزشی و پرسش‌های فعلی نسخهٔ اولیهٔ تألیفی‌اند و هنوز با چاپ رسمی ۱۴۰۵–۱۴۰۶ به‌طور کامل تطبیق نشده‌اند.';
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: Theme.of(context).textTheme.bodySmall)),
        ],
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
    final bookChapterTitle = chapter['bookChapterTitle'] as String? ?? '';
    final bookScope = chapter['bookScope'] as String? ?? '';
    final summary = chapter['summary'] as String? ?? '';
    final example = chapter['example'] as String? ?? '';
    final solutionSteps = (chapter['solutionSteps'] as List<dynamic>? ?? [])
        .whereType<String>()
        .toList();
    final lessonSections = (chapter['learningSections'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();
    final points = (chapter['points'] as List<dynamic>? ?? []).cast<String>();
    final questions =
        (chapter['questions'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
    final challengeQuestions =
        (chapter['challengeQuestions'] as List<dynamic>? ?? [])
            .cast<Map<String, dynamic>>();
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
            if (bookChapterTitle.isNotEmpty || bookScope.isNotEmpty) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (bookChapterTitle.isNotEmpty)
                      Text('فصل کتاب: $bookChapterTitle',
                          style: theme.textTheme.bodyMedium),
                    if (bookScope.isNotEmpty) ...[
                      if (bookChapterTitle.isNotEmpty) const SizedBox(height: 4),
                      Text('محدودهٔ درس در کتاب: $bookScope',
                          style: theme.textTheme.bodySmall),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 10),
            ],
            if (feature == AppFeature.lessons) ...[
              Text(
                lessonSections.isEmpty
                    ? 'خلاصهٔ آموزشی فصل'
                    : 'درسنامهٔ فصل',
                style: theme.textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              if (lessonSections.isNotEmpty) ...[
                for (final section in lessonSections)
                  _LearningSectionCard(section: section),
              ] else if (summary.isNotEmpty || points.isNotEmpty) ...[
                if (summary.isNotEmpty) Text(summary),
                for (final point in points) _Bullet(text: point),
                if (example.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text('مثال آموزشی', style: theme.textTheme.titleSmall),
                  const SizedBox(height: 4),
                  Text(example),
                ],
                if (solutionSteps.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text('راه‌حل مرحله‌به‌مرحله',
                      style: theme.textTheme.titleSmall),
                  const SizedBox(height: 4),
                  for (var i = 0; i < solutionSteps.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text('${i + 1}. ${solutionSteps[i]}'),
                    ),
                ],
                const SizedBox(height: 8),
                Text(
                  'این محتوا خلاصهٔ اولیه است؛ هنوز درسنامهٔ کاملِ تطبیق‌داده‌شده با چاپ رسمی نیست.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ] else
                const _MissingLearningSections(),
            ] else if (feature == AppFeature.notes) ...[
              Text('جزوه و نکته‌های این فصل', style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              Text(summary),
              const SizedBox(height: 10),
              for (final point in points) _Bullet(text: point),
              const SizedBox(height: 10),
              const SizedBox(height: 12),
              ChapterPdfResources(
                subjectId: subjectId,
                chapterIndex: chapterIndex,
                type: 'notes',
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
              if (challengeQuestions.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text('سؤال‌های دشوار و ترکیبی',
                    style: theme.textTheme.titleSmall),
                const SizedBox(height: 4),
                for (var i = 0; i < challengeQuestions.length; i++)
                  _ReadOnlyQuestion(
                    question: challengeQuestions[i],
                    number: questions.length + i + 1,
                  ),
              ],
              if (questions.isEmpty && challengeQuestions.isEmpty)
                const Text('برای این فصل هنوز نمونه‌سؤالی ثبت نشده است.'),
              const SizedBox(height: 12),
              ChapterPdfResources(
                subjectId: subjectId,
                chapterIndex: chapterIndex,
                type: 'sampleExams',
              ),
            ],
          ],
        ),
      ),
    );
  }
}


class ChapterPdfResources extends StatefulWidget {
  const ChapterPdfResources({
    super.key,
    required this.subjectId,
    required this.chapterIndex,
    required this.type,
  });

  final String subjectId;
  final int chapterIndex;
  final String type;

  @override
  State<ChapterPdfResources> createState() => _ChapterPdfResourcesState();
}

class _ChapterPdfResourcesState extends State<ChapterPdfResources> {
  Future<List<Map<String, dynamic>>>? _resources;
  String? _opening;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resources ??= _loadResources(DefaultAssetBundle.of(context));
  }

  Future<List<Map<String, dynamic>>> _loadResources(AssetBundle bundle) async {
    final raw = await bundle.loadString('assets/generated_pdfs/manifest.json');
    final entries = (jsonDecode(raw) as List<dynamic>).cast<Map<String, dynamic>>();
    return entries.where((entry) =>
      entry['subjectId'] == widget.subjectId &&
      entry['chapterIndex'] == widget.chapterIndex &&
      entry['type'] == widget.type
    ).toList();
  }

  Future<void> _openPdf(String fileName) async {
    if (_opening != null) return;
    setState(() => _opening = fileName);
    try {
      final data = await DefaultAssetBundle.of(context).load('assets/generated_pdfs/' + fileName);
      final directory = await getApplicationSupportDirectory();
      final file = File(directory.path + '/' + fileName);
      await file.writeAsBytes(data.buffer.asUint8List(), flush: true);
      final result = await OpenFilex.open(file.path, type: 'application/pdf');
      if (!mounted) return;
      if (result.type != ResultType.done) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('باز کردن فایل ممکن نشد: ' + result.message)),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('فایل PDF این فصل در این نسخه آماده نیست.')),
      );
    } finally {
      if (mounted) setState(() => _opening = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _resources,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Padding(
            padding: EdgeInsets.all(12),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
          return const Text('فایل PDF جداگانه‌ای برای این فصل ثبت نشده است.');
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('فایل‌های PDF این فصل', style: Theme.of(context).textTheme.titleSmall),
            for (final resource in snapshot.data!)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.picture_as_pdf_rounded),
                title: Text(resource['title'] as String? ?? 'فایل PDF'),
                subtitle: Text(resource['chapterTitle'] as String? ?? ''),
                trailing: _opening == resource['fileName']
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.open_in_new_rounded),
                onTap: _opening == null
                    ? () => _openPdf(resource['fileName'] as String)
                    : null,
              ),
          ],
        );
      },
    );
  }
}

class _MissingLearningSections extends StatelessWidget {
  const _MissingLearningSections();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Text(
        'برای این فصل هنوز درسنامهٔ کاملِ بخش‌بندی‌شده ثبت نشده است. خلاصه و چند نکته را به‌جای آموزش کامل نمایش نمی‌دهیم؛ درسنامه باید با سرفصل‌های کتاب رسمی و مثال‌های مرحله‌ای تکمیل شود.',
      ),
    );
  }
}

class _LearningSectionCard extends StatelessWidget {
  const _LearningSectionCard({required this.section});
  final Map<String, dynamic> section;

  @override
  Widget build(BuildContext context) {
    final title = section['title'] as String? ?? 'بخش آموزشی';
    final body = section['content'] as String? ?? '';
    final examples = (section['examples'] as List<dynamic>? ?? []).cast<String>();
    final keyPoints = (section['keyPoints'] as List<dynamic>? ?? []).cast<String>();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleSmall),
          if (body.isNotEmpty) Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(body),
          ),
          for (final point in keyPoints) _Bullet(text: point),
          for (final example in examples)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(example),
            ),
          const Divider(height: 24),
        ],
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


class _SavedAiLessonCard extends StatefulWidget {
  const _SavedAiLessonCard({super.key, required this.lessonKey});
  final String lessonKey;

  @override
  State<_SavedAiLessonCard> createState() => _SavedAiLessonCardState();
}

class _SavedAiLessonCardState extends State<_SavedAiLessonCard> {
  late Future<String?> _lessonFuture;

  @override
  void initState() {
    super.initState();
    _lessonFuture = AiLessonCache.read(widget.lessonKey);
  }

  Future<void> _delete() async {
    await AiLessonCache.delete(widget.lessonKey);
    if (!mounted) return;
    setState(() => _lessonFuture = Future<String?>.value(null));
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: _lessonFuture,
      builder: (context, snapshot) {
        final lesson = snapshot.data;
        if (snapshot.connectionState != ConnectionState.done ||
            lesson == null ||
            lesson.trim().isEmpty) {
          return const SizedBox.shrink();
        }
        final theme = Theme.of(context);
        return Card(
          margin: const EdgeInsets.only(bottom: 14),
          child: ExpansionTile(
            leading: Icon(Icons.auto_awesome_rounded, color: theme.colorScheme.primary),
            title: const Text('درسنامهٔ تکمیلی ذخیره‌شده'),
            subtitle: const Text('تألیفی با هوش مصنوعی؛ پاسخ رسمی کتاب نیست'),
            trailing: IconButton(
              tooltip: 'حذف درسنامهٔ ذخیره‌شده',
              onPressed: _delete,
              icon: const Icon(Icons.delete_outline_rounded),
            ),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            children: [
              SelectableText(lesson),
            ],
          ),
        );
      },
    );
  }
}
