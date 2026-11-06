import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

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
  bool _sending = false;

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
      request.add(utf8.encode(jsonEncode({'messages': messages})));

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
              child: const Text(
                'می‌توانی دربارهٔ درس‌ها سؤال بپرسی یا برای فهم بهتر یک مبحث، مثال و تمرین بخواهی. پاسخ هوش مصنوعی ممکن است اشتباه باشد؛ جواب‌های کتاب‌محور را با کتاب درسی بررسی کن.',
                textAlign: TextAlign.center,
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
