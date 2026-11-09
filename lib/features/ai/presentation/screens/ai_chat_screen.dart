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
      // Load the independently versioned subject packs first, matching the
      // lesson and search screens so the offline helper sees current content.
      for (final id in decoded.keys.toList()) {
        try {
          final packRaw = await bundle.loadString('assets/content/subjects/$id.json');
          final pack = jsonDecode(packRaw);
          if (pack is Map<String, dynamic> &&
              pack['subjectId'] == id &&
              pack['title'] is String &&
              pack['chapters'] is List &&
              (pack['chapters'] as List).isNotEmpty) {
            decoded[id] = pack;
          }
        } on FlutterError {
          // Retain the legacy catalog entry when no separate pack exists.
        } on FormatException {
          // Retain the legacy catalog entry when a pack is malformed.
        } on TypeError {
          // Reject invalid pack shapes without breaking the offline helper.
        }
      }
      setState(() {
        _catalog = decoded;
        _selectedSubjectId = decoded.isEmpty ? null : decoded.keys.first;
      });
    } catch (_) {
      // The local helper stays available with a clear empty state.
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  String _normalise(String value) => value
      .toLowerCase()
      .replaceAll('ي', 'ی')
      .replaceAll('ك', 'ک')
      .replaceAll(RegExp('[ًٌٍَُِّْٰ]'), '')
      .replaceAll(RegExp('[^0-9a-zA-Zء-ی]+'), ' ')
      .trim();

  Set<String> _tokens(String value) {
    const stopWords = {
      'و', 'در', 'از', 'به', 'را', 'که', 'این', 'آن', 'برای', 'با',
      'چیست', 'چگونه', 'کدام', 'است', 'هست', 'شود', 'می', 'یک', 'من',
      'لطفا', 'لطفاً', 'میشه', 'کن', 'کنید',
    };
    return _normalise(value)
        .split(' ')
        .where((word) => word.length > 1 && !stopWords.contains(word))
        .toSet();
  }

  int _score(String text, Set<String> tokens) {
    final textTokens = _tokens(text);
    return tokens.intersection(textTokens).length;
  }

  String _answerLocally(String question) {
    final subject = _selectedSubjectId == null
        ? null
        : _catalog[_selectedSubjectId];
    if (subject is! Map<String, dynamic>) {
      return 'محتوای این درس هنوز روی دستگاه بارگذاری نشده است. بعداً دوباره بخش درس‌ها را بررسی کن.';
    }

    final chapters = (subject['chapters'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .toList();
    if (chapters.isEmpty) return 'برای این درس هنوز محتوای آموزشی ثبت نشده است.';

    final tokens = _tokens(question);
    final scored = <({Map<String, dynamic> chapter, int index, int score})>[];
    for (var i = 0; i < chapters.length; i++) {
      final chapter = chapters[i];
      final points = (chapter['points'] as List<dynamic>? ?? []).whereType<String>();
      final questions = (chapter['questions'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map((item) => item['question'])
          .whereType<String>();
      final searchable = [
        chapter['title'] as String? ?? '',
        chapter['summary'] as String? ?? '',
        chapter['example'] as String? ?? '',
        ...points,
        ...questions,
        ...((chapter['solutionSteps'] as List<dynamic>? ?? []).whereType<String>()),
        ...((chapter['commonMistakes'] as List<dynamic>? ?? []).whereType<String>()),
      ].join(' ');
      scored.add((chapter: chapter, index: i, score: _score(searchable, tokens)));
    }

    // A learner can search the selected chapter or all chapters in the
    // current subject. The default is subject-wide retrieval so a relevant
    // chapter is not missed simply because another chapter was first.
    final selectedOnly = _selectedChapterIndex >= 0;
    final selectedIndex = _selectedChapterIndex >= scored.length
        ? scored.length - 1
        : (_selectedChapterIndex < 0 ? 0 : _selectedChapterIndex);
    final candidates = selectedOnly ? [scored[selectedIndex]] : scored;
    final best = tokens.isEmpty
        ? [candidates.first]
        : (candidates.where((item) => item.score > 0).toList()
          ..sort((a, b) => b.score.compareTo(a.score)))
            .take(selectedOnly ? 1 : 3)
            .toList();
    if (best.isEmpty) {
      return selectedOnly
          ? 'در فصل انتخاب‌شده مطلبی با این واژه‌ها پیدا نکردم. فصل دیگری را انتخاب کن یا جست‌وجوی همهٔ فصل‌ها را فعال کن.'
          : 'در محتوای ثبت‌شدهٔ این درس مطلبی با این واژه‌ها پیدا نکردم. عبارت دیگری را امتحان کن یا فصل مرتبط را باز کن.';
    }

    final asksForExample = RegExp('مثال|حل|مرحله|گام|محاسبه|تمرین').hasMatch(question);
    final asksForQuestions = RegExp('سوال|سؤال|آزمون|تست|تمرین').hasMatch(question);
    final asksForMistakes = RegExp('اشتباه|خطا|غلط|نکته|نکات').hasMatch(question);
    final out = StringBuffer()
      ..writeln('راهنمای آفلاین فهمینو — ' + (subject['title'] as String? ?? 'درس'))
      ..writeln('این پاسخ از محتوای ذخیره‌شده در برنامه پیدا شده است؛ مدل هوش مصنوعی مولد نیست.')
      ..writeln();

    for (final result in best) {
      final chapter = result.chapter;
      out.writeln('**' + (chapter['title'] as String? ?? 'بخش آموزشی') + '**');
      final summary = chapter['summary'] as String? ?? '';
      if (summary.isNotEmpty) {
        out.writeln(summary);
        out.writeln();
      }

      final points = (chapter['points'] as List<dynamic>? ?? [])
          .whereType<String>()
          .toList();
      final relevantPoints = tokens.isEmpty
          ? points.take(4).toList()
          : points.where((point) => _score(point, tokens) > 0).take(4).toList();
      final chosenPoints = relevantPoints.isNotEmpty
          ? relevantPoints
          : points.take(3).toList();
      if (chosenPoints.isNotEmpty) {
        out.writeln('نکته‌های مرتبط:');
        for (final point in chosenPoints) {
          out.writeln('• ' + point);
        }
        out.writeln();
      }

      if (asksForExample) {
        final example = chapter['example'] as String? ?? '';
        final steps = (chapter['solutionSteps'] as List<dynamic>? ?? [])
            .whereType<String>()
            .toList();
        if (example.isNotEmpty) out.writeln('مثال آموزشی: ' + example);
        if (steps.isNotEmpty) {
          out.writeln('مراحل ثبت‌شده در فهمینو:');
          for (var i = 0; i < steps.length; i++) {
            out.writeln((i + 1).toString() + '. ' + steps[i]);
          }
        }
        out.writeln();
      }

      if (asksForQuestions) {
        final questions = (chapter['questions'] as List<dynamic>? ?? [])
            .whereType<Map<String, dynamic>>()
            .take(3)
            .toList();
        if (questions.isNotEmpty) {
          out.writeln('چند پرسش تمرینی از همین بخش:');
          for (var i = 0; i < questions.length; i++) {
            out.writeln((i + 1).toString() + '. ' + (questions[i]['question'] as String? ?? ''));
          }
        }
        out.writeln();
      }

      if (asksForMistakes) {
        final mistakes = (chapter['commonMistakes'] as List<dynamic>? ?? [])
            .whereType<String>()
            .toList();
        if (mistakes.isNotEmpty) {
          out.writeln('اشتباهات رایج این درس:');
          for (final mistake in mistakes) {
            out.writeln('• ' + mistake);
          }
          out.writeln();
        } else {
          out.writeln('برای این فصل هنوز نکتهٔ اشتباهات رایج ثبت نشده است.');
        }
      }
    }

    out.write('این راهنما فقط محتوای ذخیره‌شدهٔ فهمینو را جست‌وجو می‌کند و پاسخ‌ساز اینترنتی نیست. محتوای درس‌ها را با کتاب رسمی مدرسه تطبیق بده.');
    return out.toString();
  }

  void _send() {
    final question = _controller.text.trim();
    if (question.isEmpty) return;

    _controller.clear();
    final answer = _answerLocally(question);
    setState(() {
      _visibleMessages.add(_ChatMessage(text: question, isUser: true));
      _visibleMessages.add(_ChatMessage(text: answer, isUser: false));
    });
    _scrollToBottom();
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('راهنمای آفلاین فهمینو'),
        actions: [
          IconButton(
            tooltip: 'گفت‌وگوی تازه',
            onPressed: () => setState(_visibleMessages.clear),
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
                    'راهنمای آفلاین بر پایهٔ محتوای همین برنامه؛ پرسش‌ها از دستگاه خارج نمی‌شوند. به Gemini یا سرویس ابری وصل نیست.',
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
                      }),
                    ),
                    const SizedBox(height: 8),
                    Builder(builder: (context) {
                      final subject = _selectedSubjectId == null
                          ? null
                          : _catalog[_selectedSubjectId];
                      final chapters = subject is Map<String, dynamic>
                          ? (subject['chapters'] as List<dynamic>? ?? [])
                              .whereType<Map<String, dynamic>>()
                              .toList()
                          : <Map<String, dynamic>>[];
                      if (chapters.isEmpty) return const SizedBox.shrink();
                      final selectedIndex = _selectedChapterIndex >= chapters.length
                          ? chapters.length - 1
                          : _selectedChapterIndex;
                      return DropdownButtonFormField<int>(
                        initialValue: selectedIndex,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'فصل یا درس',
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          for (var i = 0; i < chapters.length; i++)
                            DropdownMenuItem(
                              value: i,
                              child: Text(chapters[i]['title'] as String? ?? 'بخش ' + (i + 1).toString()),
                            ),
                        ],
                        onChanged: (value) => setState(() {
                          _selectedChapterIndex = value ?? 0;
                        }),
                      );
                    }),
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
                        hintText: 'سؤالت را بنویس...',
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
                    tooltip: 'پاسخ از محتوای فهمینو',
                    onPressed: _send,
                    icon: const Icon(Icons.search_rounded),
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
            Icon(Icons.offline_bolt_rounded,
                size: 54, color: theme.colorScheme.primary),
            const SizedBox(height: 14),
            Text('از کجا شروع کنیم؟', style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            const Text(
              'مثلاً بپرس: «عددهای گویا چیست؟» یا «این تمرین را مرحله‌به‌مرحله توضیح بده.»',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
