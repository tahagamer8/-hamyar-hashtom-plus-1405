import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';

/// Selects a broad, balanced set of exam questions across chapters.
///
/// Questions are shuffled inside each chapter, then selected in rounds so a
/// term exam does not accidentally draw nearly all its questions from one
/// chapter just because that chapter has a larger question bank.
List<Map<String, dynamic>> buildBalancedExamQuestions({
  required List<Map<String, dynamic>> chapters,
  int? questionLimit,
  Random? random,
}) {
  final rng = random ?? Random();
  final pools = <List<Map<String, dynamic>>>[];

  for (final chapter in chapters) {
    final chapterTitle = chapter['title'] is String
        ? chapter['title'] as String
        : 'درس';
    final rawItems = <dynamic>[
      ...(chapter['questions'] as List<dynamic>? ?? const []),
      ...(chapter['advancedQuestions'] as List<dynamic>? ?? const []),
    ];
    final pool = <Map<String, dynamic>>[];

    for (final item in rawItems) {
      if (item is! Map) continue;
      final question = Map<String, dynamic>.from(item);
      final options = question['options'];
      final answer = question['answer'];
      final prompt = question['question'];
      if (prompt is! String ||
          prompt.trim().isEmpty ||
          options is! List ||
          options.length < 2 ||
          !options.every((option) => option is String) ||
          answer is! int ||
          answer < 0 ||
          answer >= options.length) {
        continue;
      }
      pool.add({
        'chapter': chapterTitle,
        'question': prompt,
        'options': options,
        'answer': answer,
        'explanation': question['explanation'] is String
            ? question['explanation']
            : '',
      });
    }

    if (pool.isNotEmpty) {
      pool.shuffle(rng);
      pools.add(pool);
    }
  }

  final availableCount = pools.fold<int>(
    0,
    (total, pool) => total + pool.length,
  );
  final limit = questionLimit == null || questionLimit <= 0
      ? availableCount
      : (questionLimit < availableCount ? questionLimit : availableCount);
  final selected = <Map<String, dynamic>>[];

  for (var round = 0; selected.length < limit; round++) {
    var addedQuestion = false;
    for (final pool in pools) {
      if (round < pool.length && selected.length < limit) {
        selected.add(pool[round]);
        addedQuestion = true;
      }
    }
    if (!addedQuestion) break;
  }

  return selected;
}

class TimedCombinedExamScreen extends StatefulWidget {
  const TimedCombinedExamScreen({
    super.key,
    required this.subjectTitle,
    required this.chapters,
    this.examTitle,
    this.questionLimit = 20,
  });
  final String subjectTitle;
  final List<Map<String, dynamic>> chapters;
  final String? examTitle;
  final int? questionLimit;

  String get historyKey => 'fahmino_exam_history_${subjectTitle}_${examTitle ?? 'general'}';

  @override
  State<TimedCombinedExamScreen> createState() => _TimedCombinedExamScreenState();
}

class _TimedCombinedExamScreenState extends State<TimedCombinedExamScreen> {
  late final List<Map<String, dynamic>> questions;
  final Map<int, int> answers = {};
  Timer? timer;
  late int secondsLeft;
  int current = 0;
  bool submitted = false;
  bool started = false;

  @override
  void initState() {
    super.initState();
    questions = buildBalancedExamQuestions(
      chapters: widget.chapters,
      questionLimit: widget.questionLimit,
    );
    secondsLeft = max(600, questions.length * 60);
  }

  void startExam() {
    if (started || submitted || questions.isEmpty) return;
    setState(() => started = true);
    timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted || submitted) return t.cancel();
      if (secondsLeft <= 1) {
        setState(() => secondsLeft = 0);
        finish();
      } else {
        setState(() => secondsLeft--);
      }
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  void finish() {
    if (submitted) return;
    timer?.cancel();
    setState(() => submitted = true);
    _saveResult();
  }

  Future<void> _saveResult() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final key = widget.examTitle == null ? 'fahmino_exam_history_${widget.subjectTitle}' : widget.historyKey;
      final previous = preferences.getStringList(key) ?? <String>[];
      final percent = (score * 100 / questions.length).round();
      previous.insert(0, jsonEncode({
        'date': DateTime.now().toIso8601String(),
        'score': score,
        'total': questions.length,
        'percent': percent,
      }));
      await preferences.setStringList(key, previous.take(20).toList());
    } catch (_) {
      // A failed local history write must not block the exam result.
    }
  }

  Future<void> _showHistory() async {
    final preferences = await SharedPreferences.getInstance();
    final key = widget.examTitle == null ? 'fahmino_exam_history_${widget.subjectTitle}' : widget.historyKey;
    final records = preferences.getStringList(key) ?? <String>[];
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: records.isEmpty
            ? const Padding(
                padding: EdgeInsets.all(24),
                child: Text('هنوز سابقه‌ای برای این درس ثبت نشده است.'),
              )
            : ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.all(16),
                children: [
                  Text('سوابق آزمون ${widget.examTitle ?? widget.subjectTitle}',
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  for (final record in records)
                    Builder(builder: (context) {
                      final item = jsonDecode(record) as Map<String, dynamic>;
                      final date = DateTime.tryParse(item['date'] as String? ?? '');
                      final dateText = date == null
                          ? 'تاریخ نامشخص'
                          : '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
                      return ListTile(
                        leading: const Icon(Icons.history_rounded),
                        title: Text('نمره ${item['percent']}٪'),
                        subtitle: Text('${item['score']} از ${item['total']} پاسخ درست • $dateText'),
                      );
                    }),
                ],
              ),
      ),
    );
  }

  Future<void> confirmFinish() async {
    final missing = questions.length - answers.length;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('پایان آزمون'),
        content: Text(missing == 0
            ? 'آزمون ثبت شود و نتیجه را ببینی؟'
            : '$missing سؤال بی‌پاسخ مانده است. آزمون ثبت شود؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('ادامه آزمون')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('ثبت آزمون')),
        ],
      ),
    );
    if (ok == true && mounted) finish();
  }

  String get clock => '${(secondsLeft ~/ 60).toString().padLeft(2, '0')}:${(secondsLeft % 60).toString().padLeft(2, '0')}';
  int get score => List.generate(questions.length, (i) => answers[i] == questions[i]['answer'] ? 1 : 0).fold(0, (a, b) => a + b);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (questions.isEmpty) {
      return Scaffold(appBar: AppBar(title: const Text('آزمون آنلاین')),
        body: const Center(child: Text('برای این درس هنوز سؤال ثبت نشده است.')));
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(submitted
            ? 'نتیجه آزمون'
            : (widget.examTitle ?? 'آزمون جامع ${widget.subjectTitle}')),
        actions: [
          if (started && !submitted)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 12),
              child: Center(
                child: Chip(
                  avatar: const Icon(Icons.timer_outlined, size: 18),
                  label: Text(clock),
                ),
              ),
            ),
        ],
      ),
      body: submitted
          ? _result(theme)
          : started
              ? _exam(theme)
              : _intro(theme),
    );
  }

  Widget _intro(ThemeData theme) {
    final colors = theme.colorScheme;
    final chapterCount = questions.map((q) => q['chapter']).toSet().length;
    final minutes = (secondsLeft / 60).ceil();

    Widget stat({
      required IconData icon,
      required String label,
      required String value,
    }) {
      return Expanded(
        child: Card(
          color: colors.surfaceContainerLow,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
            child: Column(
              children: [
                Icon(icon, color: colors.primary, size: 24),
                const SizedBox(height: 8),
                Text(value, style: theme.textTheme.titleLarge),
                const SizedBox(height: 3),
                Text(label, style: theme.textTheme.bodySmall,
                    textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      children: [
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: colors.primaryContainer,
            borderRadius: BorderRadius.circular(26),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: colors.onPrimaryContainer.withAlpha(12),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(Icons.assignment_turned_in_rounded,
                    color: colors.onPrimaryContainer, size: 30),
              ),
              const SizedBox(height: 18),
              Text('آماده‌ای دانسته‌هایت را بسنجی؟',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: colors.onPrimaryContainer,
                  )),
              const SizedBox(height: 7),
              Text(
                'آزمون ${widget.examTitle ?? widget.subjectTitle} از سؤال‌های فصل‌های این درس ساخته شده است.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.onPrimaryContainer,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            stat(
              icon: Icons.quiz_outlined,
              label: 'تعداد سؤال',
              value: '${questions.length}',
            ),
            const SizedBox(width: 10),
            stat(
              icon: Icons.timer_outlined,
              label: 'زمان آزمون',
              value: '$minutes دقیقه',
            ),
            const SizedBox(width: 10),
            stat(
              icon: Icons.menu_book_outlined,
              label: 'فصل‌ها',
              value: '$chapterCount',
            ),
          ],
        ),
        const SizedBox(height: 18),
        Text('قبل از شروع', style: theme.textTheme.titleMedium),
        const SizedBox(height: 10),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _instructionRow(
                  theme,
                  Icons.play_circle_outline_rounded,
                  'زمان‌سنج فقط پس از زدن دکمهٔ شروع فعال می‌شود.',
                ),
                const SizedBox(height: 12),
                _instructionRow(
                  theme,
                  Icons.shuffle_rounded,
                  'سؤال‌ها از فصل‌های مختلف به‌صورت متعادل انتخاب شده‌اند.',
                ),
                const SizedBox(height: 12),
                _instructionRow(
                  theme,
                  Icons.fact_check_outlined,
                  'پس از پایان، کارنامه و پاسخ‌نامهٔ تشریحی را می‌بینی.',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        FilledButton.icon(
          onPressed: startExam,
          icon: const Icon(Icons.play_arrow_rounded),
          label: const Text('شروع آزمون'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _showHistory,
          icon: const Icon(Icons.history_rounded),
          label: const Text('مشاهدهٔ سوابق آزمون'),
        ),
      ],
    );
  }

  Widget _instructionRow(ThemeData theme, IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: theme.colorScheme.primary, size: 21),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: theme.textTheme.bodyMedium)),
      ],
    );
  }

  Widget _exam(ThemeData theme) {
    final q = questions[current];
    final colors = theme.colorScheme;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(child: Text('پیشرفت آزمون', style: theme.textTheme.labelLarge)),
                  Text('${current + 1} از ${questions.length}',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: colors.primary, fontWeight: FontWeight.w800)),
                ],
              ),
              const SizedBox(height: 9),
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: LinearProgressIndicator(
                  value: (current + 1) / questions.length,
                  minHeight: 7,
                  backgroundColor: colors.surfaceContainerHighest,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.check_circle_outline_rounded, size: 18, color: colors.primary),
                  const SizedBox(width: 6),
                  Text('${answers.length} پاسخ ثبت‌شده', style: theme.textTheme.bodySmall),
                  const Spacer(),
                  Text('${questions.length - answers.length} باقی‌مانده',
                    style: theme.textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant)),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            children: [
              Card(
                color: colors.surfaceContainerLow,
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                        decoration: BoxDecoration(
                          color: colors.secondaryContainer,
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: Text(q['chapter'].toString(),
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: colors.onSecondaryContainer, fontWeight: FontWeight.w700)),
                      ),
                      const SizedBox(height: 16),
                      Text('سؤال ${current + 1}',
                        style: theme.textTheme.labelLarge?.copyWith(color: colors.primary)),
                      const SizedBox(height: 7),
                      Text(q['question'].toString(),
                        style: theme.textTheme.titleMedium?.copyWith(height: 1.65)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text('گزینهٔ درست را انتخاب کن', style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              RadioGroup<int>(
                groupValue: answers[current],
                onChanged: (value) { if (value != null) setState(() => answers[current] = value); },
                child: Column(
                  children: [
                    for (var i = 0; i < (q['options'] as List).length; i++)
                      Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        color: answers[current] == i
                            ? colors.primaryContainer.withAlpha(150)
                            : colors.surface,
                        child: RadioListTile<int>(
                          value: i,
                          title: Text((q['options'] as List)[i].toString()),
                          contentPadding: const EdgeInsetsDirectional.only(start: 12, end: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.grid_view_rounded, size: 18, color: colors.onSurfaceVariant),
                  const SizedBox(width: 7),
                  Text('رفتن به سؤال', style: theme.textTheme.titleSmall),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (var i = 0; i < questions.length; i++)
                    SizedBox(
                      width: 42,
                      height: 42,
                      child: OutlinedButton(
                        onPressed: () => setState(() => current = i),
                        style: OutlinedButton.styleFrom(
                          backgroundColor: current == i
                              ? colors.primary
                              : answers.containsKey(i) ? colors.tertiaryContainer : colors.surface,
                          foregroundColor: current == i ? colors.onPrimary : colors.onSurface,
                          side: BorderSide(color: current == i ? colors.primary : colors.outlineVariant),
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: Text('${i + 1}'),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: current == 0 ? null : () => setState(() => current--),
                    child: const Text('قبلی'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: current < questions.length - 1
                      ? FilledButton.icon(
                          onPressed: () => setState(() => current++),
                          icon: const Icon(Icons.arrow_back_rounded),
                          label: const Text('سؤال بعدی'),
                        )
                      : FilledButton.icon(
                          onPressed: confirmFinish,
                          icon: const Icon(Icons.check_rounded),
                          label: const Text('ثبت و پایان آزمون'),
                        ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _result(ThemeData theme) {
    final percent = (score * 100 / questions.length).round();
    return ListView(padding: const EdgeInsets.all(16), children: [
      Card(child: Padding(padding: const EdgeInsets.all(20), child: Column(children: [
        const Icon(Icons.emoji_events_outlined, size: 44),
        Text('نمره: $percent٪', style: theme.textTheme.headlineSmall),
        Text('$score پاسخ درست از ${questions.length} سؤال'),
        Text('${answers.length} پاسخ ثبت‌شده'),
      ]))),
      const SizedBox(height: 12),
      OutlinedButton.icon(
        onPressed: _showHistory,
        icon: const Icon(Icons.history_rounded),
        label: const Text('مشاهدهٔ سوابق آزمون این درس'),
      ),
      const SizedBox(height: 12),
      Text('پاسخ‌نامه و توضیحات', style: theme.textTheme.titleLarge),
      for (var i = 0; i < questions.length; i++) _reviewCard(theme, i),
      const SizedBox(height: 12),
      FilledButton(onPressed: () => Navigator.of(context).pop(), child: const Text('بازگشت به درس')),
    ]);
  }

  Widget _reviewCard(ThemeData theme, int i) {
    final q = questions[i];
    final options = q['options'] as List;
    final correct = q['answer'] as int;
    final selected = answers[i];
    final right = selected == correct;
    return Card(margin: const EdgeInsets.only(top: 8), child: Padding(
      padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${i + 1}. ${q['question']}', style: theme.textTheme.titleSmall),
        Text('موضوع: ${q['chapter']}'),
        Text(selected == null ? 'پاسخ شما: بدون پاسخ' : 'پاسخ شما: ${options[selected]}',
          style: TextStyle(color: selected == null ? theme.colorScheme.onSurfaceVariant : right ? Colors.green : theme.colorScheme.error)),
        Text('پاسخ درست: ${options[correct]}', style: const TextStyle(color: Colors.green)),
        if (q['explanation'].toString().isNotEmpty) Text(q['explanation'].toString()),
      ])));
  }
}
