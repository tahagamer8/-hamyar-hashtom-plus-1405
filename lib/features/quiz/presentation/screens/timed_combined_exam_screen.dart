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
    final examBank = chapter['chapterExam'];
    final rawItems = examBank is List
        ? examBank
        : <dynamic>[
            ...(chapter['questions'] as List<dynamic>? ?? const []),
            ...(chapter['advancedQuestions'] as List<dynamic>? ?? const []),
          ];
    final pool = <Map<String, dynamic>>[];
    final seenPrompts = <String>{};

    for (final item in rawItems) {
      if (item is! Map) continue;
      final question = Map<String, dynamic>.from(item);
      final prompt = question['question'];
      final explanation = question['explanation'];
      if (prompt is! String ||
          prompt.trim().isEmpty ||
          explanation is! String ||
          explanation.trim().isEmpty ||
          !seenPrompts.add(prompt.trim())) {
        continue;
      }

      final type = question['questionType'] as String? ?? 'multiple_choice';
      final rawOptions = question['options'];
      final rawAnswer = question['answer'];
      List<String>? options;
      int? answer;

      if (rawOptions is List &&
          rawOptions.length >= 2 &&
          rawOptions.every((option) => option is String && option.trim().isNotEmpty) &&
          rawAnswer is int &&
          rawAnswer >= 0 &&
          rawAnswer < rawOptions.length) {
        options = rawOptions.cast<String>();
        answer = rawAnswer;
      } else if (type == 'true_false' &&
          (rawAnswer == 'درست' || rawAnswer == 'نادرست')) {
        options = const ['درست', 'نادرست'];
        answer = rawAnswer == 'درست' ? 0 : 1;
      } else {
        // Open-answer items are practiced in the lesson-question section,
        // where the learner can compare their written response to a rubric.
        continue;
      }

      pool.add({
        'chapter': chapterTitle,
        'question': prompt,
        'options': options,
        'answer': answer,
        'explanation': explanation,
        'questionType': type,
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
    this.questionLimit,
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

  @override
  void initState() {
    super.initState();
    questions = buildBalancedExamQuestions(
      chapters: widget.chapters,
      questionLimit: widget.questionLimit,
    );
    secondsLeft = max(600, questions.length * 60);
    if (questions.isNotEmpty) {
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
      appBar: AppBar(title: Text(submitted ? 'نتیجه آزمون' : (widget.examTitle ?? 'آزمون جامع ${widget.subjectTitle}')),
        actions: [if (!submitted) Padding(padding: const EdgeInsetsDirectional.only(end: 12),
          child: Center(child: Chip(avatar: const Icon(Icons.timer_outlined, size: 18), label: Text(clock))))]),
      body: submitted ? _result(theme) : _exam(theme),
    );
  }

  Widget _exam(ThemeData theme) {
    final q = questions[current];
    return Column(children: [
      LinearProgressIndicator(value: (current + 1) / questions.length),
      Padding(padding: const EdgeInsets.all(12), child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [Text('سؤال ${current + 1} از ${questions.length}'), Text('${answers.length} پاسخ ثبت‌شده') ])),
      Expanded(child: ListView(padding: const EdgeInsets.all(16), children: [
        Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(q['chapter'].toString(), style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.primary)),
            const SizedBox(height: 12),
            Text(q['question'].toString(), style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            RadioGroup<int>(
              groupValue: answers[current],
              onChanged: (value) { if (value != null) setState(() => answers[current] = value); },
              child: Column(children: [
                for (var i = 0; i < (q['options'] as List).length; i++)
                  RadioListTile<int>(value: i, title: Text((q['options'] as List)[i].toString()), contentPadding: EdgeInsets.zero),
              ]),
            ),
          ]))),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (var i = 0; i < questions.length; i++)
            SizedBox(width: 40, height: 38, child: OutlinedButton(
              onPressed: () => setState(() => current = i),
              style: OutlinedButton.styleFrom(backgroundColor: current == i
                ? theme.colorScheme.primaryContainer : answers.containsKey(i) ? theme.colorScheme.tertiaryContainer : null,
                padding: EdgeInsets.zero), child: Text('${i + 1}'))),
        ]),
      ])),
      SafeArea(top: false, child: Padding(padding: const EdgeInsets.all(12), child: Row(children: [
        OutlinedButton(onPressed: current == 0 ? null : () => setState(() => current--), child: const Text('قبلی')),
        const Spacer(),
        if (current < questions.length - 1)
          FilledButton(onPressed: () => setState(() => current++), child: const Text('بعدی'))
        else FilledButton(onPressed: confirmFinish, child: const Text('ثبت و پایان آزمون')),
      ]))),
    ]);
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
