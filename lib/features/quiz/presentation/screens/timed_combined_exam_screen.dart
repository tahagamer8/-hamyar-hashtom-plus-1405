import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';

class TimedCombinedExamScreen extends StatefulWidget {
  const TimedCombinedExamScreen({super.key, required this.subjectTitle, required this.chapters});
  final String subjectTitle;
  final List<Map<String, dynamic>> chapters;

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
    questions = [];
    for (final chapter in widget.chapters) {
      final advancedItems = chapter['challengeQuestions'];
      final standardItems = chapter['questions'];
      final items = advancedItems is List && advancedItems.isNotEmpty
          ? advancedItems
          : standardItems;
      if (items is! List) continue;
      for (final item in items) {
        if (item is! Map) continue;
        final q = Map<String, dynamic>.from(item);
        final options = q['options'];
        final answer = q['answer'];
        if (q['question'] is String && options is List && options.length >= 2 &&
            options.every((x) => x is String) && answer is int &&
            answer >= 0 && answer < options.length) {
          questions.add({
            'chapter': chapter['title'] ?? 'درس',
            'difficulty': q['difficulty'] ?? 'standard',
            'question': q['question'],
            'options': options,
            'answer': answer,
            'explanation': q['explanation'] ?? '',
          });
        }
      }
    }
    questions.shuffle(Random());
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
      appBar: AppBar(title: Text(submitted ? 'نتیجه آزمون' : 'آزمون جامع ${widget.subjectTitle}'),
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
            if (q['difficulty'] == 'advanced')
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Chip(
                    avatar: const Icon(Icons.psychology_alt_rounded, size: 17),
                    label: const Text('سطح دشوار و ترکیبی'),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ),
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
