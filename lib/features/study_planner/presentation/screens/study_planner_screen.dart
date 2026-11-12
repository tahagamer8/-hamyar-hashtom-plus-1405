import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _studySubjects = <String>[
  'ریاضی',
  'علوم تجربی',
  'فارسی',
  'نگارش',
  'عربی',
  'زبان انگلیسی',
  'کتاب کار انگلیسی',
  'مطالعات اجتماعی',
  'پیام‌های آسمان',
  'آموزش قرآن',
  'فرهنگ و هنر',
  'تفکر و سبک زندگی',
  'کار و فناوری',
];

class _StudyTask {
  const _StudyTask({
    required this.id,
    required this.title,
    required this.subject,
    required this.date,
    required this.completed,
  });

  final String id;
  final String title;
  final String subject;
  final DateTime date;
  final bool completed;

  _StudyTask copyWith({bool? completed}) => _StudyTask(
        id: id,
        title: title,
        subject: subject,
        date: date,
        completed: completed ?? this.completed,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'subject': subject,
        'date': date.toIso8601String(),
        'completed': completed,
      };

  static _StudyTask? fromJson(dynamic value) {
    if (value is! Map<String, dynamic>) return null;
    final title = value['title'];
    final subject = value['subject'];
    final dateRaw = value['date'];
    final date = dateRaw is String ? DateTime.tryParse(dateRaw) : null;
    if (title is! String || title.trim().isEmpty ||
        subject is! String || date == null) {
      return null;
    }
    return _StudyTask(
      id: value['id'] as String? ?? date.microsecondsSinceEpoch.toString(),
      title: title,
      subject: subject,
      date: DateTime(date.year, date.month, date.day),
      completed: value['completed'] == true,
    );
  }
}

class StudyPlannerScreen extends StatefulWidget {
  const StudyPlannerScreen({super.key});

  @override
  State<StudyPlannerScreen> createState() => _StudyPlannerScreenState();
}

class _StudyPlannerScreenState extends State<StudyPlannerScreen> {
  static const _tasksKey = 'fahmino_study_tasks_v1';
  static const _examDateKey = 'fahmino_next_exam_date_v1';

  List<_StudyTask> _tasks = [];
  DateTime? _examDate;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final stored = preferences.getStringList(_tasksKey) ?? const <String>[];
      final tasks = <_StudyTask>[];
      for (final row in stored) {
        try {
          final parsed = _StudyTask.fromJson(jsonDecode(row));
          if (parsed != null) tasks.add(parsed);
        } on FormatException {
          // Ignore a damaged row rather than losing the rest of the plan.
        }
      }
      final savedDate = preferences.getString(_examDateKey);
      final parsedDate =
          savedDate == null ? null : DateTime.tryParse(savedDate);
      if (!mounted) return;
      setState(() {
        _tasks = _sortTasks(tasks);
        _examDate = parsedDate == null
            ? null
            : DateTime(parsedDate.year, parsedDate.month, parsedDate.day);
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  List<_StudyTask> _sortTasks(List<_StudyTask> tasks) {
    final sorted = [...tasks];
    sorted.sort((a, b) {
      final dateOrder = a.date.compareTo(b.date);
      if (dateOrder != 0) return dateOrder;
      if (a.completed != b.completed) return a.completed ? 1 : -1;
      return a.subject.compareTo(b.subject);
    });
    return sorted;
  }

  Future<void> _persist() async {
    if (_saving) return;
    _saving = true;
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setStringList(
        _tasksKey,
        _tasks.map((task) => jsonEncode(task.toJson())).toList(),
      );
      if (_examDate == null) {
        await preferences.remove(_examDateKey);
      } else {
        await preferences.setString(
          _examDateKey,
          _examDate!.toIso8601String(),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ذخیرهٔ برنامه ممکن نشد؛ دوباره تلاش کن.')),
        );
      }
    } finally {
      _saving = false;
    }
  }

  Future<void> _chooseExamDate() async {
    final now = DateTime.now();
    final chosen = await showDatePicker(
      context: context,
      initialDate: _examDate ?? now,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(2100),
      helpText: 'تاریخ امتحان بعدی را انتخاب کن',
      cancelText: 'انصراف',
      confirmText: 'ثبت تاریخ',
    );
    if (chosen == null) return;
    setState(() => _examDate = DateTime(chosen.year, chosen.month, chosen.day));
    await _persist();
  }

  Future<void> _addTask() async {
    final draft = await showDialog<_StudyTask>(
      context: context,
      builder: (context) => const _StudyTaskDialog(),
    );
    if (draft == null) return;
    setState(() => _tasks = _sortTasks([..._tasks, draft]));
    await _persist();
  }

  Future<void> _toggleTask(_StudyTask task, bool completed) async {
    setState(() {
      _tasks = _sortTasks([
        for (final current in _tasks)
          if (current.id == task.id)
            current.copyWith(completed: completed)
          else
            current,
      ]);
    });
    await _persist();
  }

  Future<void> _deleteTask(_StudyTask task) async {
    setState(() => _tasks.removeWhere((item) => item.id == task.id));
    await _persist();
  }

  String _dateLabel(DateTime date) =>
      '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';

  int get _completed => _tasks.where((task) => task.completed).length;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final today = DateTime.now();
    final daysLeft = _examDate == null
        ? null
        : DateTime(_examDate!.year, _examDate!.month, _examDate!.day)
            .difference(DateTime(today.year, today.month, today.day))
            .inDays;

    return Scaffold(
      appBar: AppBar(
        title: const Text('برنامه‌ریز مطالعه'),
        actions: [
          IconButton(
            tooltip: 'افزودن برنامه',
            onPressed: _loading ? null : _addTask,
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _loading ? null : _addTask,
        icon: const Icon(Icons.add_rounded),
        label: const Text('برنامهٔ جدید'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.event_available_rounded,
                                color: theme.colorScheme.primary),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text('امتحان بعدی',
                                  style: theme.textTheme.titleMedium),
                            ),
                            TextButton(
                              onPressed: _chooseExamDate,
                              child: Text(_examDate == null
                                  ? 'انتخاب تاریخ'
                                  : 'تغییر تاریخ'),
                            ),
                          ],
                        ),
                        if (_examDate == null)
                          const Text('تاریخ امتحانت را ثبت کن تا زمان باقی‌مانده را ببینی.')
                        else ...[
                          Text(
                            _dateLabel(_examDate!),
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(daysLeft == 0
                              ? 'امتحانت امروز است.'
                              : daysLeft! > 0
                                  ? '$daysLeft روز تا امتحان باقی مانده است.'
                                  : 'این تاریخ گذشته است؛ تاریخ تازه‌ای انتخاب کن.'),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text('پیشرفت برنامه',
                                  style: theme.textTheme.titleMedium),
                            ),
                            Text('$_completed از ${_tasks.length}'),
                          ],
                        ),
                        const SizedBox(height: 10),
                        LinearProgressIndicator(
                          value: _tasks.isEmpty ? 0 : _completed / _tasks.length,
                          minHeight: 8,
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Text('کارهای مطالعه',
                          style: theme.textTheme.titleLarge),
                    ),
                    TextButton.icon(
                      onPressed: _addTask,
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('افزودن'),
                    ),
                  ],
                ),
                if (_tasks.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(22),
                      child: Column(
                        children: [
                          Icon(Icons.calendar_month_outlined, size: 42),
                          SizedBox(height: 8),
                          Text('برنامه‌ای ثبت نشده است.'),
                          SizedBox(height: 4),
                          Text('برای هر درس، یک کار کوتاه و تاریخ انجامش را اضافه کن.',
                              textAlign: TextAlign.center),
                        ],
                      ),
                    ),
                  )
                else
                  for (final task in _tasks)
                    Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: CheckboxListTile(
                        value: task.completed,
                        onChanged: (value) =>
                            _toggleTask(task, value ?? false),
                        controlAffinity: ListTileControlAffinity.leading,
                        title: Text(
                          task.title,
                          style: TextStyle(
                            decoration: task.completed
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                        ),
                        subtitle: Text('${task.subject} • ${_dateLabel(task.date)}'),
                        secondary: IconButton(
                          tooltip: 'حذف برنامه',
                          onPressed: () => _deleteTask(task),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ),
                    ),
              ],
            ),
    );
  }
}

class _StudyTaskDialog extends StatefulWidget {
  const _StudyTaskDialog();

  @override
  State<_StudyTaskDialog> createState() => _StudyTaskDialogState();
}

class _StudyTaskDialogState extends State<_StudyTaskDialog> {
  final _controller = TextEditingController();
  String _subject = _studySubjects.first;
  DateTime _date = DateTime.now();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _chooseDate() async {
    final now = DateTime.now();
    final chosen = await showDatePicker(
      context: context,
      initialDate: _date.isBefore(DateTime(now.year, now.month, now.day))
          ? DateTime(now.year, now.month, now.day)
          : _date,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(2100),
    );
    if (chosen != null) {
      setState(() => _date = DateTime(chosen.year, chosen.month, chosen.day));
    }
  }

  void _submit() {
    final title = _controller.text.trim();
    if (title.isEmpty) return;
    final task = _StudyTask(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      title: title,
      subject: _subject,
      date: DateTime(_date.year, _date.month, _date.day),
      completed: false,
    );
    Navigator.pop(context, task);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('برنامهٔ مطالعهٔ جدید'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _controller,
              autofocus: true,
              maxLength: 100,
              textDirection: TextDirection.rtl,
              decoration: const InputDecoration(
                labelText: 'چه کاری باید انجام بدهی؟',
                hintText: 'مثلاً مرور فصل دوم علوم',
              ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _subject,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'درس',
                border: OutlineInputBorder(),
              ),
              items: [
                for (final item in _studySubjects)
                  DropdownMenuItem(value: item, child: Text(item)),
              ],
              onChanged: (value) =>
                  setState(() => _subject = value ?? _studySubjects.first),
            ),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_today_outlined),
              title: const Text('تاریخ انجام'),
              subtitle: Text(
                '${_date.year}/${_date.month.toString().padLeft(2, '0')}/${_date.day.toString().padLeft(2, '0')}',
              ),
              onTap: _chooseDate,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('انصراف'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('ذخیره برنامه'),
        ),
      ],
    );
  }
}
