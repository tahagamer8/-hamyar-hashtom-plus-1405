import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hamyar_hashtom_plus/features/quiz/data/mcq_history_store.dart';
import 'package:hamyar_hashtom_plus/features/quiz/domain/mcq_level.dart';
import 'package:hamyar_hashtom_plus/features/quiz/domain/mcq_question.dart';
import 'package:hamyar_hashtom_plus/features/quiz/domain/subject_pack.dart';
import 'package:hamyar_hashtom_plus/features/quiz/presentation/providers/quiz_providers.dart';
import 'package:hamyar_hashtom_plus/features/quiz/presentation/widgets/quiz_status_views.dart';

/// Practice session for one level and subject: question navigation, answer
/// selection, scoring, results and a full answer review.
class McqPracticeScreen extends ConsumerWidget {
  const McqPracticeScreen({
    super.key,
    required this.levelId,
    required this.subjectId,
    this.random,
  });

  final String levelId;
  final String subjectId;

  /// Injectable for deterministic tests.
  final Random? random;

  static const int sessionSize = 10;

  static Key optionKey(int index) => ValueKey('mcq-option-$index');
  static Key gotoKey(int index) => ValueKey('mcq-goto-$index');
  static const Key nextKey = ValueKey('mcq-next');
  static const Key previousKey = ValueKey('mcq-prev');
  static const Key finishKey = ValueKey('mcq-finish');
  static const Key retryKey = ValueKey('mcq-retry');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final level = McqLevel.fromId(levelId);
    if (level == null || !level.hasQuestionSource) {
      return const QuizMessageScaffold(
        title: 'تمرین چندگزینه‌ای',
        message: 'این سطح وجود ندارد یا هنوز پرسشی برای آن ثبت نشده است.',
      );
    }
    final packs = ref.watch(subjectPacksProvider);
    return packs.when(
      loading: () => const QuizLoadingScaffold(title: 'تمرین چندگزینه‌ای'),
      error: (error, stack) => Scaffold(
        appBar: AppBar(title: const Text('تمرین چندگزینه‌ای')),
        body: QuizErrorView(
          onRetry: () => ref.invalidate(subjectPacksProvider),
        ),
      ),
      data: (list) {
        SubjectPack? pack;
        for (final item in list) {
          if (item.id == subjectId) {
            pack = item;
          }
        }
        if (pack == null) {
          return const QuizMessageScaffold(
            title: 'تمرین چندگزینه‌ای',
            message: 'این درس پیدا نشد.',
          );
        }
        if (pack.questionsFor(level).isEmpty) {
          return QuizMessageScaffold(
            title: pack.title,
            message: 'برای این سطح و درس هنوز سؤالی ثبت نشده است.',
          );
        }
        return _McqSession(level: level, pack: pack, random: random);
      },
    );
  }
}

class _McqSession extends ConsumerStatefulWidget {
  const _McqSession({
    required this.level,
    required this.pack,
    required this.random,
  });

  final McqLevel level;
  final SubjectPack pack;
  final Random? random;

  @override
  ConsumerState<_McqSession> createState() => _McqSessionState();
}

class _McqSessionState extends ConsumerState<_McqSession> {
  late List<McqQuestion> _questions;
  final Map<int, int> _answers = {};
  int _current = 0;
  bool _submitted = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  void _start() {
    _questions = selectBalancedQuestions(
      widget.pack.questionsFor(widget.level),
      limit: McqPracticeScreen.sessionSize,
      random: widget.random,
    );
    _answers.clear();
    _current = 0;
    _submitted = false;
  }

  int get _score {
    var score = 0;
    for (var i = 0; i < _questions.length; i++) {
      if (_answers[i] == _questions[i].answerIndex) {
        score++;
      }
    }
    return score;
  }

  Future<void> _finish() async {
    final missing = _questions.length - _answers.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('پایان تمرین'),
        content: Text(
          missing == 0
              ? 'نتیجه ثبت شود و پاسخ‌ها را مرور کنی؟'
              : '$missing سؤال بی‌پاسخ مانده است. نتیجه ثبت شود؟',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('بازبینی'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('ثبت نتیجه'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    setState(() => _submitted = true);
    final key = (level: widget.level, subjectId: widget.pack.id);
    await const McqHistoryStore().save(
      widget.level,
      widget.pack.id,
      McqAttempt(
        date: DateTime.now(),
        score: _score,
        total: _questions.length,
      ),
    );
    if (mounted) {
      ref.invalidate(mcqHistoryProvider(key));
    }
  }

  Future<void> _confirmLeave() async {
    final leave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('خروج از تمرین'),
        content: const Text(
          'پاسخ‌های این تمرین ذخیره نمی‌شوند. خارج می‌شوی؟',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('ادامه تمرین'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('خروج'),
          ),
        ],
      ),
    );
    if (leave == true && mounted) {
      Navigator.of(context).pop();
    }
  }

  Color _goodColor(ThemeData theme) => theme.brightness == Brightness.dark
      ? Colors.green.shade300
      : Colors.green.shade800;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PopScope(
      canPop: _submitted || _answers.isEmpty,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _confirmLeave();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            _submitted
                ? 'نتیجه تمرین'
                : '${widget.level.title} • ${widget.pack.title}',
            overflow: TextOverflow.ellipsis,
          ),
        ),
        body: _submitted ? _results(theme) : _questionView(theme),
      ),
    );
  }

  Widget _questionView(ThemeData theme) {
    final colors = theme.colorScheme;
    final question = _questions[_current];
    final isLast = _current == _questions.length - 1;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text('پیشرفت', style: theme.textTheme.labelLarge),
                  ),
                  Text(
                    '${_current + 1} از ${_questions.length}',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: colors.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 9),
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: LinearProgressIndicator(
                  value: (_current + 1) / _questions.length,
                  minHeight: 7,
                  backgroundColor: colors.surfaceContainerHighest,
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  '${_answers.length} پاسخ ثبت‌شده از ${_questions.length}',
                  style: theme.textTheme.bodySmall,
                ),
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
                        padding: const EdgeInsets.symmetric(
                          horizontal: 11,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: colors.secondaryContainer,
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: Text(
                          question.chapterTitle,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: colors.onSecondaryContainer,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        question.prompt,
                        style: theme.textTheme.titleMedium?.copyWith(height: 1.65),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              for (var i = 0; i < question.options.length; i++)
                _OptionCard(
                  key: McqPracticeScreen.optionKey(i),
                  label: question.options[i],
                  selected: _answers[_current] == i,
                  onTap: () => setState(() => _answers[_current] = i),
                ),
              const SizedBox(height: 12),
              Text('رفتن به سؤال', style: theme.textTheme.titleSmall),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (var i = 0; i < _questions.length; i++)
                    SizedBox(
                      width: 42,
                      height: 42,
                      child: OutlinedButton(
                        key: McqPracticeScreen.gotoKey(i),
                        onPressed: () => setState(() => _current = i),
                        style: OutlinedButton.styleFrom(
                          backgroundColor: _current == i
                              ? colors.primary
                              : _answers.containsKey(i)
                                  ? colors.tertiaryContainer
                                  : colors.surface,
                          foregroundColor: _current == i
                              ? colors.onPrimary
                              : colors.onSurface,
                          side: BorderSide(
                            color: _current == i
                                ? colors.primary
                                : colors.outlineVariant,
                          ),
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
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
                    key: McqPracticeScreen.previousKey,
                    onPressed:
                        _current == 0 ? null : () => setState(() => _current--),
                    child: const Text('قبلی'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: isLast
                      ? FilledButton.icon(
                          key: McqPracticeScreen.finishKey,
                          onPressed: _finish,
                          icon: const Icon(Icons.check_rounded),
                          label: const Text('پایان و مشاهده نتیجه'),
                        )
                      : FilledButton.icon(
                          key: McqPracticeScreen.nextKey,
                          onPressed: () => setState(() => _current++),
                          icon: const Icon(Icons.arrow_back_rounded),
                          label: const Text('سؤال بعدی'),
                        ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _results(ThemeData theme) {
    final total = _questions.length;
    final score = _score;
    final percent = (score * 100 / total).round();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                const Icon(Icons.emoji_events_outlined, size: 44),
                const SizedBox(height: 6),
                Text('نمره: $percent٪', style: theme.textTheme.headlineSmall),
                const SizedBox(height: 4),
                Text('$score پاسخ درست از $total سؤال'),
                Text('${_answers.length} پاسخ ثبت‌شده'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                key: McqPracticeScreen.retryKey,
                onPressed: () => setState(_start),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('تمرین دوباره'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('بازگشت'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text('مرور پاسخ‌ها', style: theme.textTheme.titleLarge),
        for (var i = 0; i < _questions.length; i++) _reviewCard(theme, i),
      ],
    );
  }

  Widget _reviewCard(ThemeData theme, int index) {
    final question = _questions[index];
    final selected = _answers[index];
    final correct = question.answerIndex;
    final isRight = selected == correct;
    final good = _goodColor(theme);
    final bad = theme.colorScheme.error;
    return Card(
      margin: const EdgeInsets.only(top: 8),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${index + 1}. ${question.prompt}',
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 4),
            Text('موضوع: ${question.chapterTitle}'),
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  selected == null
                      ? Icons.remove_circle_outline_rounded
                      : isRight
                          ? Icons.check_circle_rounded
                          : Icons.cancel_rounded,
                  size: 18,
                  color: selected == null
                      ? theme.colorScheme.onSurfaceVariant
                      : isRight
                          ? good
                          : bad,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    selected == null
                        ? 'پاسخ شما: بدون پاسخ'
                        : 'پاسخ شما: ${question.options[selected]}',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'پاسخ درست: ${question.options[correct]}',
              style: TextStyle(color: good, fontWeight: FontWeight.w700),
            ),
            if (question.explanation.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(question.explanation),
            ],
          ],
        ),
      ),
    );
  }
}

class _OptionCard extends StatelessWidget {
  const _OptionCard({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      inMutuallyExclusiveGroup: true,
      selected: selected,
      child: Card(
        margin: const EdgeInsets.only(bottom: 8),
        color: selected ? colors.primaryContainer : colors.surface,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Row(
              children: [
                Icon(
                  selected
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_unchecked_rounded,
                  color: selected ? colors.primary : colors.onSurfaceVariant,
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(label)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
