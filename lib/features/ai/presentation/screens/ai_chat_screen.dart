import 'dart:convert';

import 'package:flutter/material.dart';

class AiChatScreen extends StatefulWidget {
  const AiChatScreen({super.key});

  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends State<AiChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _visibleMessages = <_ChatMessage>[];

  Map<String, dynamic> _catalog = {};
  String? _selectedSubjectId;
  int _selectedChapterIndex = -1;
  bool _catalogRequested = false;

  List<Map<String, dynamic>> _quizQuestions = [];
  int _quizIndex = 0;
  int _quizCorrect = 0;
  bool _awaitingQuizAnswer = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_catalogRequested) {
      _catalogRequested = true;
      _loadCatalog(DefaultAssetBundle.of(context));
    }
  }

  Future<void> _loadCatalog(AssetBundle bundle) async {
    try {
      final raw = await bundle.loadString('assets/content/catalog_fa.json');
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic> || !mounted) return;

      for (final id in decoded.keys.toList()) {
        try {
          final packRaw =
              await bundle.loadString('assets/content/subjects/' + id + '.json');
          final pack = jsonDecode(packRaw);
          if (pack is Map<String, dynamic> &&
              pack['subjectId'] == id &&
              pack['title'] is String &&
              pack['chapters'] is List &&
              (pack['chapters'] as List).isNotEmpty) {
            decoded[id] = pack;
          }
        } on FlutterError {
          // Keep the legacy catalog entry if a separate pack is unavailable.
        } on FormatException {
          // Keep the legacy entry if a pack is malformed.
        } on TypeError {
          // Reject malformed pack shapes without breaking the tutor.
        }
      }

      if (!mounted) return;
      setState(() {
        _catalog = decoded;
        _selectedSubjectId = decoded.isEmpty ? null : decoded.keys.first;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _catalog = {});
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Map<String, dynamic>? get _selectedSubject {
    final value =
        _selectedSubjectId == null ? null : _catalog[_selectedSubjectId];
    return value is Map<String, dynamic> ? value : null;
  }

  List<Map<String, dynamic>> get _subjectChapters =>
      (_selectedSubject?['chapters'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .toList(growable: false);

  String _normalise(String value) {
    var result = value
        .toLowerCase()
        .replaceAll('ي', 'ی')
        .replaceAll('ك', 'ک')
        .replaceAll(RegExp('[ًٌٍَُِّْٰ]'), '')
        .replaceAll(RegExp('[^0-9a-zA-Zء-ی۰-۹]+'), ' ')
        .trim();

    const digits = '۰۱۲۳۴۵۶۷۸۹';
    for (var i = 0; i < digits.length; i++) {
      result = result.replaceAll(digits[i], i.toString());
    }
    return result;
  }

  Set<String> _tokens(String value) {
    const stopWords = {
      'و', 'در', 'از', 'به', 'را', 'که', 'این', 'آن', 'برای', 'با',
      'چیست', 'چگونه', 'کدام', 'است', 'هست', 'شود', 'می', 'یک', 'من',
      'لطفا', 'میشه', 'کن', 'کنید', 'فصل', 'درس', 'راهنمایی', 'بده',
      'بدهید', 'برام', 'همین', 'خودم', 'منو',
    };
    return _normalise(value)
        .split(' ')
        .where((word) => word.length > 1 && !stopWords.contains(word))
        .toSet();
  }

  int _score(String text, Set<String> tokens) {
    if (tokens.isEmpty) return 0;
    return tokens.intersection(_tokens(text)).length;
  }

  List<Map<String, dynamic>> _chaptersForQuestion(
    String question, {
    required bool preferSingleChapter,
  }) {
    final chapters = _subjectChapters;
    if (chapters.isEmpty) return const [];

    if (_selectedChapterIndex >= 0) {
      final index = _selectedChapterIndex.clamp(0, chapters.length - 1);
      return [chapters[index]];
    }
    if (preferSingleChapter) return [chapters.first];

    final tokens = _tokens(question);
    if (tokens.isEmpty) return [chapters.first];

    final scored = <({Map<String, dynamic> chapter, int score})>[];
    for (final chapter in chapters) {
      final searchable = [
        chapter['title'] as String? ?? '',
        chapter['summary'] as String? ?? '',
        chapter['example'] as String? ?? '',
        ...((chapter['points'] as List<dynamic>? ?? []).whereType<String>()),
        ...((chapter['solutionSteps'] as List<dynamic>? ?? [])
            .whereType<String>()),
        ...((chapter['commonMistakes'] as List<dynamic>? ?? [])
            .whereType<String>()),
        ...((chapter['questions'] as List<dynamic>? ?? [])
            .whereType<Map<String, dynamic>>()
            .map((item) => item['question'])
            .whereType<String>()),
      ].join(' ');
      scored.add((chapter: chapter, score: _score(searchable, tokens)));
    }

    scored.sort((a, b) => b.score.compareTo(a.score));
    return scored
        .where((item) => item.score > 0)
        .take(2)
        .map((item) => item.chapter)
        .toList(growable: false);
  }

  String _answerLocally(String question) {
    final subject = _selectedSubject;
    if (subject == null) {
      return 'محتوای درس هنوز بارگذاری نشده است. بستهٔ محتوای همین درس را بررسی کن.';
    }
    if (_subjectChapters.isEmpty) {
      return 'برای این درس هنوز فصل آموزشی ثبت نشده است.';
    }

    final wantsLesson =
        RegExp('آموزش|یاد بده|درسنامه|از پایه|توضیح فصل').hasMatch(question);
    final wantsExample =
        RegExp('مثال|حل|مرحله|گام|محاسبه').hasMatch(question);
    final wantsMistakes =
        RegExp('اشتباه|خطا|غلط|نکته|نکات').hasMatch(question);
    final wantsPractice =
        RegExp('تمرین|سوال|سؤال|پرسش').hasMatch(question);

    final chapters = _chaptersForQuestion(
      question,
      preferSingleChapter: wantsLesson || wantsExample || wantsMistakes,
    );
    if (chapters.isEmpty) {
      return 'در محتوای ثبت‌شدهٔ این درس مورد روشنی برای این عبارت پیدا نکردم. نام فصل یا متن دقیق پرسشت را بنویس.';
    }

    final subjectTitle = subject['title'] as String? ?? 'درس';
    final out = StringBuffer()
      ..writeln('معلم خصوصی فهمینو · ' + subjectTitle)
      ..writeln(
        'این راهنما از محتوای ذخیره‌شدهٔ فهمینو استفاده می‌کند؛ پاسخ رسمی کتاب یا مدل هوش مصنوعی مولد نیست.',
      )
      ..writeln();

    for (final chapter in chapters) {
      final title = chapter['title'] as String? ?? 'بخش آموزشی';
      final summary = chapter['summary'] as String? ?? '';
      final points =
          (chapter['points'] as List<dynamic>? ?? []).whereType<String>().toList();
      final example = chapter['example'] as String? ?? '';
      final steps = (chapter['solutionSteps'] as List<dynamic>? ?? [])
          .whereType<String>()
          .toList();
      final mistakes = (chapter['commonMistakes'] as List<dynamic>? ?? [])
          .whereType<String>()
          .toList();

      out.writeln('### ' + title);
      if (wantsLesson) {
        out.writeln('**آموزش مفهومی:**');
        if (summary.isNotEmpty) out.writeln(summary);
        if (points.isNotEmpty) {
          out.writeln('**نکته‌های کلیدی:**');
          for (final point in points.take(6)) {
            out.writeln('• ' + point);
          }
        }
        if (example.isNotEmpty) out.writeln('**مثال آموزشی:** ' + example);
        if (steps.isNotEmpty) {
          out.writeln('**حل مرحله‌به‌مرحله:**');
          for (var i = 0; i < steps.length; i++) {
            out.writeln((i + 1).toString() + '. ' + steps[i]);
          }
        }
        if (mistakes.isNotEmpty) {
          out.writeln('**مراقب این اشتباه‌ها باش:**');
          for (final mistake in mistakes.take(4)) {
            out.writeln('• ' + mistake);
          }
        }
        out.writeln(
          'حالا بدون نگاه‌کردن به متن بالا، مفهوم اصلی را در یک جمله برای خودت توضیح بده.',
        );
      } else {
        if (summary.isNotEmpty) out.writeln(summary);

        final tokens = _tokens(question);
        final matchedPoints = tokens.isEmpty
            ? points.take(4).toList()
            : points
                .where((point) => _score(point, tokens) > 0)
                .take(5)
                .toList();
        if (matchedPoints.isNotEmpty) {
          out.writeln('**نکته‌های مرتبط:**');
          for (final point in matchedPoints) {
            out.writeln('• ' + point);
          }
        }

        if (wantsExample) {
          if (example.isNotEmpty) out.writeln('**مثال آموزشی:** ' + example);
          if (steps.isNotEmpty) {
            out.writeln('**مراحل حل:**');
            for (var i = 0; i < steps.length; i++) {
              out.writeln((i + 1).toString() + '. ' + steps[i]);
            }
          }
          if (example.isEmpty && steps.isEmpty) {
            out.writeln('برای این فصل هنوز مثال حل‌شدهٔ جداگانه ثبت نشده است.');
          }
        }

        if (wantsMistakes) {
          if (mistakes.isEmpty) {
            out.writeln('برای این فصل هنوز فهرست اشتباهات رایج ثبت نشده است.');
          } else {
            out.writeln('**اشتباهات رایج:**');
            for (final mistake in mistakes) {
              out.writeln('• ' + mistake);
            }
          }
        }

        if (wantsPractice) {
          final questions = [
            ...((chapter['questions'] as List<dynamic>? ?? [])
                .whereType<Map<String, dynamic>>()),
            ...((chapter['advancedQuestions'] as List<dynamic>? ?? [])
                .whereType<Map<String, dynamic>>()),
          ];
          if (questions.isEmpty) {
            out.writeln('برای این فصل هنوز پرسش تمرینی ثبت نشده است.');
          } else {
            out.writeln('**برای تمرین بیشتر:**');
            for (final item in questions.take(3)) {
              out.writeln('• ' + (item['question'] as String? ?? ''));
            }
          }
        }
      }
      out.writeln();
    }

    out.write(
      'یادآوری: این مطالب برای یادگیری و تمرین‌اند؛ تا وقتی صفحه و پاسخ با نسخهٔ رسمی کتاب تطبیق داده نشده، آن‌ها را پاسخ قطعی کتاب در نظر نگیر.',
    );
    return out.toString();
  }

  String _startQuiz() {
    final chapters = _selectedChapterIndex >= 0
        ? _chaptersForQuestion('', preferSingleChapter: true)
        : _subjectChapters;
    final questions = <Map<String, dynamic>>[];

    for (final chapter in chapters) {
      for (final key in ['questions', 'advancedQuestions']) {
        final values = chapter[key];
        if (values is! List) continue;
        for (final value in values.whereType<Map<String, dynamic>>()) {
          final options = value['options'];
          final answer = value['answer'];
          if (value['question'] is String &&
              options is List &&
              options.length >= 2 &&
              answer is int &&
              answer >= 0 &&
              answer < options.length &&
              value['explanation'] is String) {
            questions.add({
              ...value,
              '_chapterTitle': chapter['title'] as String? ?? 'فصل',
            });
          }
        }
      }
    }

    if (questions.isEmpty) {
      _awaitingQuizAnswer = false;
      return 'برای فصل انتخاب‌شده سؤال معتبر و پاسخ تشریحی ثبت نشده است.';
    }

    _quizQuestions = questions.take(5).toList(growable: false);
    _quizIndex = 0;
    _quizCorrect = 0;
    _awaitingQuizAnswer = true;
    return 'آزمون کوتاه شروع شد. پاسخ را با شمارهٔ گزینه یا حرف الف، ب، پ، ت بفرست؛ بعد از هر پاسخ، دلیلش را توضیح می‌دهم.\n\n' +
        _currentQuizQuestion();
  }

  String _currentQuizQuestion() {
    final question = _quizQuestions[_quizIndex];
    final options = (question['options'] as List<dynamic>).whereType<String>();
    const labels = ['الف', 'ب', 'پ', 'ت', 'ث', 'ج'];
    final out = StringBuffer()
      ..writeln('سؤال ' +
          (_quizIndex + 1).toString() +
          ' از ' +
          _quizQuestions.length.toString())
      ..writeln(question['question'] as String);
    for (var i = 0; i < options.length; i++) {
      final label = i < labels.length ? labels[i] : (i + 1).toString();
      out.writeln(label + ') ' + options.elementAt(i));
    }
    out.write('پاسخت کدام گزینه است؟');
    return out.toString();
  }

  int? _parseQuizAnswer(String value, List<String> options) {
    final normalised = _normalise(value).replaceAll(' ', '');
    const letters = {'الف': 0, 'ب': 1, 'پ': 2, 'ت': 3, 'ث': 4, 'ج': 5};
    if (letters.containsKey(normalised)) return letters[normalised];

    final numeric = int.tryParse(normalised);
    if (numeric != null && numeric >= 1 && numeric <= options.length) {
      return numeric - 1;
    }

    for (var i = 0; i < options.length; i++) {
      if (_normalise(options[i]).replaceAll(' ', '') == normalised) return i;
    }
    return null;
  }

  String _gradeQuizAnswer(String response) {
    if (!_awaitingQuizAnswer ||
        _quizQuestions.isEmpty ||
        _quizIndex >= _quizQuestions.length) {
      _awaitingQuizAnswer = false;
      return 'آزمون فعالی وجود ندارد. از دکمهٔ «آزمون کوتاه» برای شروع دوباره استفاده کن.';
    }

    final question = _quizQuestions[_quizIndex];
    final options =
        (question['options'] as List<dynamic>).whereType<String>().toList();
    final chosen = _parseQuizAnswer(response, options);
    if (chosen == null) {
      return 'پاسخت را با شمارهٔ گزینه یا حرف الف، ب، پ یا ت بفرست تا بتوانم آن را بررسی کنم.';
    }

    final correct = question['answer'] as int;
    final isCorrect = chosen == correct;
    if (isCorrect) _quizCorrect++;

    final out = StringBuffer()
      ..writeln(isCorrect ? 'آفرین، این پاسخ درست است.' : 'این گزینه درست نیست.')
      ..writeln('پاسخ درست: ' + options[correct])
      ..writeln('توضیح: ' + (question['explanation'] as String));

    _quizIndex++;
    if (_quizIndex < _quizQuestions.length) {
      out
        ..writeln()
        ..writeln(_currentQuizQuestion());
    } else {
      _awaitingQuizAnswer = false;
      out
        ..writeln()
        ..writeln('آزمون تمام شد: ' +
            _quizCorrect.toString() +
            ' پاسخ درست از ' +
            _quizQuestions.length.toString() +
            ' سؤال.')
        ..writeln('برای مرور، فصل را انتخاب کن و «آموزش فصل» یا «اشتباهات رایج» را بزن.');
      _quizQuestions = [];
    }
    return out.toString();
  }

  void _send() {
    final prompt = _controller.text.trim();
    if (prompt.isEmpty) return;

    _controller.clear();
    final isQuizRequest =
        RegExp('آزمون|ازم سوال|از من سوال|امتحان بگیر|سؤال بپرس')
            .hasMatch(prompt);
    final answer = _awaitingQuizAnswer
        ? _gradeQuizAnswer(prompt)
        : isQuizRequest
            ? _startQuiz()
            : _answerLocally(prompt);

    setState(() {
      _visibleMessages.add(_ChatMessage(text: prompt, isUser: true));
      _visibleMessages.add(_ChatMessage(text: answer, isUser: false));
    });
    _scrollToBottom();
  }

  void _sendQuickPrompt(String prompt) {
    _controller.text = prompt;
    _send();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _resetChat() {
    setState(() {
      _visibleMessages.clear();
      _quizQuestions = [];
      _quizIndex = 0;
      _quizCorrect = 0;
      _awaitingQuizAnswer = false;
      _controller.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chapters = _subjectChapters;

    return Scaffold(
      appBar: AppBar(
        title: const Text('معلم خصوصی فهمینو'),
        actions: [
          IconButton(
            tooltip: 'گفت‌وگوی تازه',
            onPressed: _resetChat,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              color: theme.colorScheme.surfaceContainerHighest.withAlpha(110),
              child: Column(
                children: [
                  const Text(
                    'آموزش مرحله‌ای و آزمون تعاملی بر پایهٔ محتوای ذخیره‌شدهٔ فهمینو. '
                    'همه‌چیز روی دستگاه انجام می‌شود؛ این بخش به مدل مولد اینترنتی وصل نیست.',
                    textAlign: TextAlign.center,
                  ),
                  if (_catalog.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedSubjectId,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'درس',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        for (final entry in _catalog.entries)
                          DropdownMenuItem(
                            value: entry.key,
                            child: Text(
                              entry.value is Map<String, dynamic>
                                  ? (entry.value['title'] as String? ?? entry.key)
                                  : entry.key,
                            ),
                          ),
                      ],
                      onChanged: (value) => setState(() {
                        _selectedSubjectId = value;
                        _selectedChapterIndex = -1;
                        _quizQuestions = [];
                        _awaitingQuizAnswer = false;
                      }),
                    ),
                    if (chapters.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      DropdownButtonFormField<int>(
                        initialValue: _selectedChapterIndex,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'فصل یا محدودهٔ آموزش',
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          const DropdownMenuItem(
                            value: -1,
                            child: Text('همهٔ فصل‌های این درس'),
                          ),
                          for (var i = 0; i < chapters.length; i++)
                            DropdownMenuItem(
                              value: i,
                              child: Text(
                                chapters[i]['title'] as String? ?? 'فصل ' + (i + 1).toString(),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                        onChanged: (value) => setState(() {
                          _selectedChapterIndex = value ?? -1;
                          _quizQuestions = [];
                          _awaitingQuizAnswer = false;
                        }),
                      ),
                    ],
                    const SizedBox(height: 10),
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: Text(
                        'شروع سریع',
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.start,
                      children: [
                        ActionChip(
                          avatar: const Icon(Icons.school_outlined, size: 18),
                          label: const Text('آموزش فصل'),
                          onPressed: () =>
                              _sendQuickPrompt('این فصل را از پایه آموزش بده'),
                        ),
                        ActionChip(
                          avatar: const Icon(Icons.calculate_outlined, size: 18),
                          label: const Text('مثال حل‌شده'),
                          onPressed: () =>
                              _sendQuickPrompt('یک مثال را مرحله‌به‌مرحله حل کن'),
                        ),
                        ActionChip(
                          avatar: const Icon(Icons.quiz_outlined, size: 18),
                          label: const Text('آزمون کوتاه'),
                          onPressed: () => _sendQuickPrompt('از من آزمون بگیر'),
                        ),
                        ActionChip(
                          avatar: const Icon(Icons.lightbulb_outline, size: 18),
                          label: const Text('اشتباهات رایج'),
                          onPressed: () =>
                              _sendQuickPrompt('اشتباهات رایج این فصل چیست؟'),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            Expanded(
              child: _visibleMessages.isEmpty
                  ? const _EmptyChat()
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: _visibleMessages.length,
                      itemBuilder: (context, index) =>
                          _MessageBubble(message: _visibleMessages[index]),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      minLines: 1,
                      maxLines: 5,
                      maxLength: 500,
                      textDirection: TextDirection.rtl,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration: InputDecoration(
                        hintText: _awaitingQuizAnswer
                            ? 'پاسخت را با الف، ب، پ یا ت بنویس...'
                            : 'سؤالت را از معلم خصوصی بپرس...',
                        counterText: '',
                        filled: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(22),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    tooltip: 'ارسال پرسش',
                    onPressed: _send,
                    icon: const Icon(Icons.send_rounded),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatMessage {
  const _ChatMessage({required this.text, required this.isUser});
  final String text;
  final bool isUser;
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});
  final _ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = message.isUser
        ? theme.colorScheme.primaryContainer
        : theme.colorScheme.surfaceContainerHighest;
    return Align(
      alignment: message.isUser ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * .9,
        ),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(18),
        ),
        child: SelectableText(
          message.text,
          textDirection: TextDirection.rtl,
          style: theme.textTheme.bodyMedium,
        ),
      ),
    );
  }
}

class _EmptyChat extends StatelessWidget {
  const _EmptyChat();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.school_rounded,
                size: 54, color: theme.colorScheme.primary),
            const SizedBox(height: 14),
            Text('از کجا شروع کنیم؟', style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            const Text(
              'درس و فصل را انتخاب کن؛ بعد از معلم خصوصی بخواه آموزش بدهد، مثال حل کند یا از تو آزمون بگیرد.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
