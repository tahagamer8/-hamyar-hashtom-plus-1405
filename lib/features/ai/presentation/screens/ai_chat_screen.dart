import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
  int _selectedChapterIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadCatalog();
  }

  Future<void> _loadCatalog() async {
    try {
      final raw = await rootBundle.loadString('assets/content/catalog_fa.json');
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic> || !mounted) return;
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
      .replaceAll(RegExp('[^0-9a-zA-Zء-ي]+'), ' ')
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
    final normalized = _normalise(text);
    return tokens.where(normalized.contains).length;
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
      ].join(' ');
      scored.add((chapter: chapter, index: i, score: _score(searchable, tokens)));
    }

    scored.sort((a, b) => b.score.compareTo(a.score));
    final fallbackIndex = _selectedChapterIndex >= scored.length
        ? scored.length - 1
        : _selectedChapterIndex;
    final best = scored.first.score > 0
        ? scored.take(2).toList()
        : [scored[fallbackIndex]];

    final asksForExample = RegExp('مثال|حل|مرحله|گام|محاسبه|تمرین').hasMatch(question);
    final asksForQuestions = RegExp('سوال|سؤال|آزمون|تست|تمرین').hasMatch(question);
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
    }

    out.write('یادآوری: محتوای فعلی هنوز با نسخه رسمی کتاب‌های ۱۴۰۵–۱۴۰۶ صفحه‌به‌صفحه تأیید نشده است؛ برای پاسخ قطعی کتابی، متن کتاب را هم بررسی کن.');
    return out.toString();
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();
    final answer = _answerLocally(text);
    setState(() {
      _visibleMessages
        ..add(_ChatMessage(text: text, isUser: true))
        ..add(_ChatMessage(text: answer, isUser: false));
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
        title: const Text('دستیار آفلاین فهمینو'),
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
                    'این بخش بدون اینترنت کار می‌کند و فقط محتوای ذخیره‌شده در فهمینو را جست‌وجو می‌کند. پیام‌ها از دستگاه خارج نمی‌شوند؛ پاسخ‌ها تولید هوش مصنوعی نیستند.',
                    textAlign: TextAlign.center,
                  ),
                  if (_catalog.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      value: _selectedSubjectId,
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
                        _selectedChapterIndex = 0;
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
                        value: selectedIndex,
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
                        hintText: 'درباره درس انتخاب‌شده بپرس...',
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
                    tooltip: 'جست‌وجوی محلی',
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
              'مثلاً بپرس: «عددهای گویا چیست؟» یا «مراحل حل مثال این فصل را نشان بده.»',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
