import 'package:flutter/material.dart';
import 'package:hamyar_hashtom_plus/features/content/presentation/widgets/book_page_gallery.dart';
import 'package:hamyar_hashtom_plus/features/quiz/presentation/screens/timed_combined_exam_screen.dart';

class SampleQuestionLibraryScreen extends StatefulWidget {
  const SampleQuestionLibraryScreen({super.key, required this.subjectId, required this.subjectTitle, required this.chapters});
  final String subjectId;
  final String subjectTitle;
  final List<Map<String, dynamic>> chapters;

  @override
  State<SampleQuestionLibraryScreen> createState() => _SampleQuestionLibraryScreenState();
}

class _SampleQuestionLibraryScreenState extends State<SampleQuestionLibraryScreen> {
  bool _termMode = false;
  int _chapterIndex = 0;
  String _term = 'first';

  List<Map<String, dynamic>> get _termChapters {
    final selected = widget.chapters.where((chapter) => chapter['examTerm'] == _term).toList();
    if (selected.isNotEmpty) return selected;
    final middle = (widget.chapters.length / 2).ceil();
    return _term == 'first' ? widget.chapters.take(middle).toList() : widget.chapters.skip(middle).toList();
  }

  List<Map<String, dynamic>> _questions(Map<String, dynamic> chapter) {
    final normal = (chapter['questions'] as List<dynamic>? ?? []).whereType<Map>();
    final advanced = (chapter['advancedQuestions'] as List<dynamic>? ?? []).whereType<Map>();
    return [
      ...normal.map((item) => Map<String, dynamic>.from(item)),
      ...advanced.map((item) => Map<String, dynamic>.from(item)),
    ];
  }

  int get _termCount => _termChapters.fold<int>(0, (count, chapter) => count + _questions(chapter).length);

  Future<void> _startExam(List<Map<String, dynamic>> chapters, String title, int limit) async {
    if (chapters.isEmpty) return;
    await Navigator.of(context).push<void>(MaterialPageRoute(
      builder: (_) => TimedCombinedExamScreen(
        subjectTitle: widget.subjectTitle,
        chapters: chapters,
        examTitle: title,
        questionLimit: limit,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final safeIndex = _chapterIndex < 0
        ? 0
        : (_chapterIndex >= widget.chapters.length
            ? (widget.chapters.isEmpty ? 0 : widget.chapters.length - 1)
            : _chapterIndex);
    final chapter = widget.chapters.isEmpty ? null : widget.chapters[safeIndex];
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(widget.subjectTitle, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 6),
        Text('بانک نمونه‌سؤال‌های تألیفی فهمینو؛ برای مطالعه و تمرین آفلاین.', style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 14),
        Wrap(spacing: 8, children: [
          ChoiceChip(label: const Text('فصل‌به‌فصل'), selected: !_termMode, onSelected: (_) => setState(() => _termMode = false)),
          ChoiceChip(label: const Text('نوبت اول و دوم'), selected: _termMode, onSelected: (_) => setState(() => _termMode = true)),
        ]),
        const SizedBox(height: 14),
        if (!_termMode && chapter != null) ...[
          DropdownButtonFormField<int>(
            value: safeIndex,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'انتخاب فصل یا درس', prefixIcon: Icon(Icons.menu_book_rounded), border: OutlineInputBorder()),
            items: [
              for (var index = 0; index < widget.chapters.length; index++)
                DropdownMenuItem(value: index, child: Text('${index + 1}. ${widget.chapters[index]['title'] ?? 'درس'}', overflow: TextOverflow.ellipsis)),
            ],
            onChanged: (value) => setState(() => _chapterIndex = value ?? 0),
          ),
          const SizedBox(height: 12),
          Card(child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(chapter['title'] as String? ?? 'فصل انتخاب‌شده', style: Theme.of(context).textTheme.titleMedium),
              if (chapter['pageStart'] is int)
                Text(chapter['pageEnd'] is int ? 'صفحه ${chapter['pageStart']} تا ${chapter['pageEnd']}' : 'شروع از صفحه ${chapter['pageStart']}'),
              Text('${_questions(chapter).length} پرسش'),
            ]),
          )),
          BookPageGallery(pageAssets: (chapter['bookPageImages'] as List<dynamic>? ?? []).whereType<String>().toList()),
          for (var index = 0; index < _questions(chapter).length; index++)
            _SampleQuestionCard(number: index + 1, question: _questions(chapter)[index]),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _questions(chapter).isEmpty ? null : () => _startExam([chapter], 'آزمون تمرینی ${chapter['title']}', 10),
            icon: const Icon(Icons.timer_outlined),
            label: const Text('آزمون زمان‌دار این فصل'),
          ),
        ] else if (_termMode) ...[
          Text('آزمون‌های تألیفی در سبک تیزهوشان', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          Text('این پرسش‌ها تألیفی‌اند و آزمون رسمی سازمان سنجش نیستند.', style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 12),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'first', label: Text('نوبت اول'), icon: Icon(Icons.looks_one_outlined)),
              ButtonSegment(value: 'second', label: Text('نوبت دوم'), icon: Icon(Icons.looks_two_outlined)),
            ],
            selected: {_term},
            onSelectionChanged: (values) => setState(() => _term = values.first),
          ),
          const SizedBox(height: 14),
          Card(child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('محدودهٔ ${_term == 'first' ? 'نوبت اول' : 'نوبت دوم'}', style: Theme.of(context).textTheme.titleMedium),
              Text('${_termChapters.length} فصل یا بخش، ${_termCount} پرسش در بانک این نوبت'),
              const SizedBox(height: 8),
              Text('برای کتاب‌هایی که نوبت‌بندی رسمی در داده ندارند، نیمهٔ نخست فصل‌ها پیش‌فرض نوبت اول و نیمهٔ دوم پیش‌فرض نوبت دوم است؛ برنامهٔ دبیر ممکن است متفاوت باشد.', style: Theme.of(context).textTheme.bodySmall),
            ]),
          )),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _termCount == 0 ? null : () => _startExam(_termChapters, 'آزمون تألیفی تیزهوشان ${_term == 'first' ? 'نوبت اول' : 'نوبت دوم'}', 20),
            icon: const Icon(Icons.play_arrow_rounded),
            label: Text('شروع آزمون تیزهوشان ${_term == 'first' ? 'نوبت اول' : 'نوبت دوم'}'),
          ),
          const SizedBox(height: 12),
          Text('فصل‌های این آزمون', style: Theme.of(context).textTheme.titleSmall),
          for (final item in _termChapters)
            ListTile(dense: true, contentPadding: EdgeInsets.zero, leading: const Icon(Icons.menu_book_outlined), title: Text(item['title'] as String? ?? 'درس'), subtitle: Text('${_questions(item).length} پرسش')),
        ],
      ],
    );
  }
}

class _SampleQuestionCard extends StatefulWidget {
  const _SampleQuestionCard({required this.number, required this.question});
  final int number;
  final Map<String, dynamic> question;

  @override
  State<_SampleQuestionCard> createState() => _SampleQuestionCardState();
}

class _SampleQuestionCardState extends State<_SampleQuestionCard> {
  bool _showAnswer = false;

  @override
  Widget build(BuildContext context) {
    final options = (widget.question['options'] as List<dynamic>? ?? []).cast<String>();
    final answer = widget.question['answer'] as int? ?? -1;
    final valid = answer >= 0 && answer < options.length;
    final advanced = widget.question['questionType'] == 'reasoning';
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (advanced) Text('پرسش استدلالی و چالشی', style: Theme.of(context).textTheme.labelMedium?.copyWith(color: Theme.of(context).colorScheme.primary)),
          Text('${widget.number}. ${widget.question['question']}', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          for (var index = 0; index < options.length; index++)
            Padding(padding: const EdgeInsets.only(bottom: 4), child: Text('${String.fromCharCode(65 + index)}) ${options[index]}')),
          TextButton.icon(
            onPressed: () => setState(() => _showAnswer = !_showAnswer),
            icon: Icon(_showAnswer ? Icons.visibility_off_outlined : Icons.visibility_outlined),
            label: Text(_showAnswer ? 'پنهان کردن پاسخ' : 'نمایش پاسخ و توضیح'),
          ),
          if (_showAnswer) ...[
            Text('پاسخ: ${valid ? options[answer] : 'ثبت نشده'}', style: TextStyle(color: Theme.of(context).colorScheme.primary)),
            if (widget.question['explanation'] is String) Text(widget.question['explanation'] as String),
          ],
        ]),
      ),
    );
  }
}
