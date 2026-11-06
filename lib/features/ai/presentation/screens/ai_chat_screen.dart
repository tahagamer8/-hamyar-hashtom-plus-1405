import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const _assistantEndpoint = 'https://fahmino-api-2.tahamrh2.workers.dev/api/chat';

class AiChatScreen extends StatefulWidget {
  const AiChatScreen({super.key});

  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends State<AiChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _visibleMessages = <_ChatMessage>[];
  final _history = <Map<String, String>>[];
  Map<String, dynamic> _catalog = {};
  String? _selectedSubjectId;
  int _selectedChapterIndex = 0;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _loadCatalog();
  }

  Future<void> _loadCatalog() async {
    try {
      final raw = await rootBundle.loadString('assets/content/catalog_fa.json');
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return;
      if (!mounted) return;
      setState(() {
        _catalog = decoded;
        _selectedSubjectId = decoded.isEmpty ? null : decoded.keys.first;
      });
    } catch (_) {
      // The chat remains usable without local study context.
    }
  }

  Map<String, dynamic>? _buildStudyContext() {
    final id = _selectedSubjectId;
    final subject = id == null ? null : _catalog[id];
    if (subject is! Map<String, dynamic>) return null;
    final chapters = (subject['chapters'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .toList();
    if (chapters.isEmpty) {
      return {
        'subjectTitle': subject['title'] as String? ?? 'درس',
        'alignmentStatus': 'not_verified_against_1405_1406_pdf',
        'contentVerificationStatus': 'not_verified_against_1405_1406_pdf',
        'bookScope': 'محتوای تألیفی فهمینو برای پایه هشتم',
      };
    }
    final index = _selectedChapterIndex >= chapters.length
        ? chapters.length - 1
        : _selectedChapterIndex;
    final chapter = chapters[index];
    final questions = (chapter['questions'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .take(4)
        .map((question) => question['question'])
        .whereType<String>()
        .toList();
    return {
      'subjectTitle': subject['title'] as String? ?? 'درس',
      'chapterTitle': chapter['title'] as String? ?? '',
      'bookChapterTitle': chapter['title'] as String? ?? '',
      'bookScope': 'محتوای تألیفی فهمینو برای پایه هشتم؛ نه متن رسمی کتاب',
      'alignmentStatus': 'not_verified_against_1405_1406_pdf',
      'contentVerificationStatus': 'not_verified_against_1405_1406_pdf',
      'summary': chapter['summary'] as String? ?? '',
      'example': chapter['example'] as String? ?? '',
      'points': (chapter['points'] as List<dynamic>? ?? []).whereType<String>().take(8).toList(),
      'solutionSteps': (chapter['solutionSteps'] as List<dynamic>? ?? []).whereType<String>().take(8).toList(),
      'practiceQuestions': questions,
    };
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
    if (text.length > 3000) {
      _showMessage('هر پیام باید حداکثر ۳۰۰۰ نویسه باشد.');
      return;
    }

    _controller.clear();
    setState(() {
      _sending = true;
      _visibleMessages.add(_ChatMessage(text: text, isUser: true));
    });
    _scrollToBottom();

    final messages = <Map<String, String>>[
      ..._history,
      {'role': 'user', 'text': text},
    ];
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 10);

    try {
      final request = await client
          .postUrl(Uri.parse(_assistantEndpoint))
          .timeout(const Duration(seconds: 12));
      request.headers.contentType = ContentType.json;
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      final studyContext = _buildStudyContext();
      request.add(utf8.encode(jsonEncode({
        'messages': messages,
        if (studyContext != null) 'studyContext': studyContext,
      })));

      final response = await request.close().timeout(const Duration(seconds: 28));
      final responseText = await response
          .transform(utf8.decoder)
          .join()
          .timeout(const Duration(seconds: 5));
      final decoded = jsonDecode(responseText);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('پاسخ سرور قابل خواندن نیست.');
      }

      if (response.statusCode < 200 || response.statusCode >= 300) {
        final message = decoded['error'] is String
            ? decoded['error'] as String
            : 'ارتباط با دستیار برقرار نشد. دوباره تلاش کن.';
        throw HttpException(message);
      }

      final answer = decoded['answer'];
      if (answer is! String || answer.trim().isEmpty) {
        throw const FormatException('پاسخ متنی دریافت نشد.');
      }

      _history
        ..add({'role': 'user', 'text': text})
        ..add({'role': 'model', 'text': answer});
      while (_history.length > 10) {
        _history.removeRange(0, 2);
      }

      if (!mounted) return;
      setState(() {
        _visibleMessages.add(_ChatMessage(
          text: answer,
          isUser: false,
          truncated: decoded['truncated'] == true,
        ));
      });
      _scrollToBottom();
    } on SocketException {
      _showMessage('اتصال اینترنت برقرار نیست. اتصال را بررسی کن.');
    } on HttpException catch (error) {
      _showMessage(error.message);
    } on FormatException {
      _showMessage('پاسخ سرور نامعتبر بود. کمی بعد دوباره تلاش کن.');
    } on Exception {
      _showMessage('در دریافت پاسخ مشکلی پیش آمد. دوباره تلاش کن.');
    } finally {
      client.close(force: true);
      if (mounted) setState(() => _sending = false);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
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
        title: const Text('دستیار هوشمند فهمینو'),
        actions: [
          IconButton(
            tooltip: 'گفت‌وگوی تازه',
            onPressed: _sending
                ? null
                : () => setState(() {
                      _history.clear();
                      _visibleMessages.clear();
                    }),
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
                    'می‌توانی دربارهٔ درس‌ها سؤال بپرسی یا برای فهم بهتر یک مبحث، مثال و تمرین بخواهی. پاسخ هوش مصنوعی ممکن است اشتباه باشد؛ جواب‌های کتاب‌محور را با کتاب درسی بررسی کن.',
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
                      onChanged: _sending
                          ? null
                          : (value) => setState(() {
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
                              child: Text(chapters[i]['title'] as String? ?? 'بخش \${i + 1}'),
                            ),
                        ],
                        onChanged: _sending
                            ? null
                            : (value) => setState(() {
                                  _selectedChapterIndex = value ?? 0;
                                }),
                      );
                    }),
                    const SizedBox(height: 4),
                    Text(
                      'محتوای انتخاب‌شده هنوز با PDF رسمی ۱۴۰۵–۱۴۰۶ تأیید نهایی نشده است.',
                      style: theme.textTheme.bodySmall,
                      textAlign: TextAlign.center,
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
                      itemCount: _visibleMessages.length + (_sending ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (_sending && index == _visibleMessages.length) {
                          return const _TypingIndicator();
                        }
                        return _MessageBubble(message: _visibleMessages[index]);
                      },
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
                      maxLength: 3000,
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
                    tooltip: 'ارسال پیام',
                    onPressed: _sending ? null : _send,
                    icon: _sending
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send_rounded),
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
  const _ChatMessage({
    required this.text,
    required this.isUser,
    this.truncated = false,
  });

  final String text;
  final bool isUser;
  final bool truncated;
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
          maxWidth: MediaQuery.sizeOf(context).width * .86,
        ),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SelectableText(
              message.text,
              textDirection: TextDirection.rtl,
              style: theme.textTheme.bodyMedium,
            ),
            if (message.truncated)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'برای ادامهٔ پاسخ، «ادامه بده» را بفرست.',
                  style: theme.textTheme.bodySmall,
                ),
              ),
          ],
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
            Icon(Icons.auto_awesome_rounded,
                size: 54, color: theme.colorScheme.primary),
            const SizedBox(height: 14),
            Text('از کجا شروع کنیم؟', style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            const Text(
              'مثلاً بپرس: «عددهای گویا را با یک مثال توضیح بده.»',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _TypingIndicator extends StatelessWidget {
  const _TypingIndicator();

  @override
  Widget build(BuildContext context) => const Align(
        alignment: Alignment.centerRight,
        child: Padding(
          padding: EdgeInsets.all(12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 10),
              Text('فهمینو در حال پاسخ‌گویی است...'),
            ],
          ),
        ),
      );
}
