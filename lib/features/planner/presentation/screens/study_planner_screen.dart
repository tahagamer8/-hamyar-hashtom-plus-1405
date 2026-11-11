import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _plannerKey = 'fahmino.study_planner.tasks.v1';

class _StudyTask {
  const _StudyTask(this.id, this.title, this.subject, {this.done = false});
  final String id, title, subject;
  final bool done;
  _StudyTask toggle(bool value) => _StudyTask(id, title, subject, done: value);
  Map<String, Object?> toJson() => {'id': id, 'title': title, 'subject': subject, 'done': done};
  factory _StudyTask.fromJson(Map<String, dynamic> value) => _StudyTask(
    value['id'] as String, value['title'] as String, value['subject'] as String,
    done: value['done'] as bool? ?? false,
  );
}

class StudyPlannerScreen extends StatefulWidget {
  const StudyPlannerScreen({super.key});
  @override
  State<StudyPlannerScreen> createState() => _StudyPlannerScreenState();
}

class _StudyPlannerScreenState extends State<StudyPlannerScreen> {
  static const _subjects = ['ریاضی','علوم','فارسی','نگارش','عربی','انگلیسی','مطالعات اجتماعی','قرآن','پیام‌های آسمان'];
  final _title = TextEditingController();
  List<_StudyTask> _tasks = [];
  String _subject = _subjects.first;
  bool _loading = true;
  bool _saving = false;

  int get _done => _tasks.where((e) => e.done).length;
  double get _progress => _tasks.isEmpty ? 0 : _done / _tasks.length;

  @override
  void initState() { super.initState(); _load(); }
  @override
  void dispose() { _title.dispose(); super.dispose(); }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_plannerKey);
      if (raw != null) {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          _tasks = decoded.whereType<Map<String, dynamic>>().map(_StudyTask.fromJson).toList();
        }
      }
    } catch (_) { _tasks = []; }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_plannerKey, jsonEncode(_tasks.map((e) => e.toJson()).toList()));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _add() async {
    final value = _title.text.trim();
    if (value.isEmpty) return;
    setState(() {
      _tasks = [..._tasks, _StudyTask(DateTime.now().microsecondsSinceEpoch.toString(), value, _subject)];
      _title.clear();
    });
    await _save();
  }

  Future<void> _toggle(_StudyTask task, bool value) async {
    setState(() => _tasks = _tasks.map((e) => e.id == task.id ? e.toggle(value) : e).toList());
    await _save();
  }

  Future<void> _remove(_StudyTask task) async {
    setState(() => _tasks = _tasks.where((e) => e.id != task.id).toList());
    await _save();
  }

  Future<void> _clearDone() async {
    setState(() => _tasks = _tasks.where((e) => !e.done).toList());
    await _save();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final pending = _tasks.where((e) => !e.done).toList();
    final completed = _tasks.where((e) => e.done).toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('برنامه‌ریز مطالعه'),
        actions: [_saving ? const Padding(
          padding: EdgeInsetsDirectional.only(end: 18),
          child: Center(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))),
        ) : const SizedBox.shrink()],
      ),
      body: _loading ? const Center(child: CircularProgressIndicator()) : ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: colors.primaryContainer, borderRadius: BorderRadius.circular(28)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(Icons.track_changes_rounded, color: colors.onPrimaryContainer, size: 28),
                const SizedBox(width: 10),
                Expanded(child: Text('قدم‌به‌قدم جلو برو', style: theme.textTheme.titleLarge?.copyWith(color: colors.onPrimaryContainer, fontWeight: FontWeight.w800))),
              ]),
              const SizedBox(height: 8),
              Text('کارهای درسی‌ات را بنویس و بعد از انجام هرکدام علامت بزن.', style: TextStyle(color: colors.onPrimaryContainer)),
              const SizedBox(height: 18),
              Row(children: [
                Text(_done.toString() + ' از ' + _tasks.length.toString() + ' کار انجام شده', style: TextStyle(color: colors.onPrimaryContainer)),
                const Spacer(),
                Text((_progress * 100).round().toString() + '٪', style: TextStyle(color: colors.onPrimaryContainer, fontWeight: FontWeight.w800)),
              ]),
              const SizedBox(height: 9),
              ClipRRect(borderRadius: BorderRadius.circular(20), child: LinearProgressIndicator(value: _progress, minHeight: 9)),
            ]),
          ),
          const SizedBox(height: 24),
          Text('افزودن کار درسی', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          TextField(
            controller: _title, textDirection: TextDirection.rtl, maxLength: 90,
            textInputAction: TextInputAction.done, onSubmitted: (_) => _add(),
            decoration: const InputDecoration(labelText: 'مثلاً مرور درس ۳ علوم', prefixIcon: Icon(Icons.edit_note_rounded), counterText: ''),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            value: _subject, isExpanded: true,
            decoration: const InputDecoration(labelText: 'درس مربوطه', prefixIcon: Icon(Icons.menu_book_rounded)),
            items: [for (final s in _subjects) DropdownMenuItem(value: s, child: Text(s))],
            onChanged: (v) { if (v != null) setState(() => _subject = v); },
          ),
          const SizedBox(height: 12),
          FilledButton.icon(onPressed: _add, icon: const Icon(Icons.add_rounded), label: const Text('افزودن به برنامه')),
          const SizedBox(height: 26),
          _heading(context, 'کارهای باقی‌مانده', pending.length),
          const SizedBox(height: 8),
          if (pending.isEmpty) _empty(context, 'فعلاً کاری باقی نمانده؛ می‌توانی کار بعدی را اضافه کنی.'),
          for (final task in pending) _tile(context, task),
          if (completed.isNotEmpty) ...[
            const SizedBox(height: 22),
            Row(children: [
              Expanded(child: _heading(context, 'انجام‌شده‌ها', completed.length)),
              TextButton(onPressed: _clearDone, child: const Text('پاک‌کردن')),
            ]),
            const SizedBox(height: 8),
            for (final task in completed) _tile(context, task),
          ],
          const SizedBox(height: 18),
          Text('برنامه‌ات فقط روی همین دستگاه ذخیره می‌شود و بدون اینترنت هم در دسترس است.', textAlign: TextAlign.center, style: theme.textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant)),
        ],
      ),
    );
  }

  Widget _heading(BuildContext context, String title, int count) => Row(children: [
    Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
    const SizedBox(width: 8),
    Chip(label: Text(count.toString()), visualDensity: VisualDensity.compact, padding: EdgeInsets.zero),
  ]);

  Widget _tile(BuildContext context, _StudyTask task) => Card(
    margin: const EdgeInsets.only(bottom: 8),
    child: CheckboxListTile(
      value: task.done, onChanged: (v) => _toggle(task, v ?? false),
      controlAffinity: ListTileControlAffinity.leading,
      title: Text(task.title, style: TextStyle(decoration: task.done ? TextDecoration.lineThrough : null)),
      subtitle: Text(task.subject),
      secondary: IconButton(tooltip: 'حذف کار', onPressed: () => _remove(task), icon: const Icon(Icons.delete_outline_rounded)),
    ),
  );

  Widget _empty(BuildContext context, String message) => Card(
    child: Padding(padding: const EdgeInsets.all(20), child: Row(children: [
      const Icon(Icons.inbox_outlined), const SizedBox(width: 12), Expanded(child: Text(message)),
    ])),
  );
}
