import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hamyar_hashtom_plus/features/ai_assistant/data/gemini_api_service.dart';

class AiAssistantScreen extends StatefulWidget {
  const AiAssistantScreen({super.key});

  @override
  State<AiAssistantScreen> createState() => _AiAssistantScreenState();
}

class _AiAssistantScreenState extends State<AiAssistantScreen> {
  static const _urlKey = 'fahmino_gemini_worker_url';
  static const _defaultWorkerUrl =
      'https://fahmino-api-2.tahamrh2.workers.dev';
  final _input = TextEditingController();
  final _urlInput = TextEditingController();
  final _scroll = ScrollController();
  final _service = GeminiApiService();
  final List<_ChatMessage> _messages = [];
  bool _loading = false;
  bool _ready = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadUrl();
  }

  Future<void> _loadUrl() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _urlInput.text = prefs.getString(_urlKey) ?? _defaultWorkerUrl;
    } catch (_) {
      _urlInput.text = _defaultWorkerUrl;
      _error = 'تنظیمات اتصال بارگذاری نشد؛ آدرس پیش‌فرض نمایش داده شد.';
    } finally {
      if (mounted) setState(() => _ready = true);
    }
  }

  Future<void> _saveUrl() async {
    final value = _urlInput.text.trim().replaceFirst(RegExp(r'/+$'), '');
    final uri = Uri.tryParse(value);
    if (uri == null ||
        uri.scheme != 'https' ||
        !uri.hasAuthority ||
        uri.userInfo.isNotEmpty ||
        (uri.path.isNotEmpty && uri.path != '/') ||
        uri.hasQuery ||
        uri.hasFragment) {
      setState(() => _error = 'فقط آدرس پایهٔ معتبر HTTPS را وارد کن.');
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_urlKey, value);
      if (mounted) {
        setState(() => _error = null);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('آدرس سرور ذخیره شد.')),
        );
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'ذخیرهٔ آدرس انجام نشد؛ دوباره تلاش کن.');
    }
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _loading) return;
    if (_urlInput.text.trim().isEmpty) {
      setState(() => _error = 'ابتدا آدرس Worker را در تنظیمات همین صفحه وارد کن.');
      return;
    }

    _input.clear();
    setState(() {
      _error = null;
      _messages.add(_ChatMessage(text: text, isUser: true));
      _loading = true;
    });
    _scrollToBottom();

    final history = prepareGeminiHistory(
      _messages
          .map((m) => {
                'role': m.isUser ? 'user' : 'model',
                'text': m.text,
              })
          .toList(),
    );

    try {
      final answer = await _service.sendMessages(
        workerUrl: _urlInput.text,
        messages: history,
      );
      if (!mounted) return;
      setState(() => _messages.add(_ChatMessage(text: answer, isUser: false)));
    } on GeminiApiException catch (e) {
      if (mounted) {
        setState(() {
          if (_messages.isNotEmpty && _messages.last.isUser) {
            _messages.removeLast();
          }
          _input.text = text;
          _error = e.message;
        });
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
        _scrollToBottom();
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _input.dispose();
    _urlInput.dispose();
    _scroll.dispose();
    _service.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('دستیار هوشمند'),
        actions: [
          IconButton(
            tooltip: 'تنظیمات اتصال',
            onPressed: _showConnectionInfo,
            icon: const Icon(Icons.settings_ethernet_rounded),
          ),
          IconButton(
            tooltip: 'گفت‌وگوی جدید',
            onPressed: _loading
                ? null
                : () => setState(() {
                      _messages.clear();
                      _error = null;
                    }),
            icon: const Icon(Icons.add_comment_outlined),
          ),
        ],
      ),
      body: !_ready
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _connectionPanel(theme),
                Expanded(
                  child: _messages.isEmpty
                      ? _emptyState(theme)
                      : ListView.builder(
                          controller: _scroll,
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                          itemCount: _messages.length + (_loading ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index == _messages.length) {
                              return const _Bubble(
                                text: 'در حال فکر کردن…',
                                isUser: false,
                                pending: true,
                              );
                            }
                            final message = _messages[index];
                            return _Bubble(
                              text: message.text,
                              isUser: message.isUser,
                            );
                          },
                        ),
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: Text(_error!,
                        style: TextStyle(color: theme.colorScheme.error)),
                  ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _input,
                            minLines: 1,
                            maxLines: 4,
                            maxLength: 3000,
                            textInputAction: TextInputAction.send,
                            onSubmitted: (_) => _send(),
                            decoration: const InputDecoration(
                              hintText: 'سؤالت را درباره درس‌ها بپرس…',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filled(
                          onPressed: _loading ? null : _send,
                          icon: const Icon(Icons.send_rounded),
                          tooltip: 'ارسال پیام',
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _connectionPanel(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Material(
        color: theme.colorScheme.surfaceContainerHighest.withAlpha(100),
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.lock_outline,
                      size: 18, color: theme.colorScheme.primary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'اتصال به Gemini',
                      style: theme.textTheme.labelLarge,
                    ),
                  ),
                  TextButton(onPressed: _saveUrl, child: const Text('ذخیره')),
                ],
              ),
              TextField(
                controller: _urlInput,
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(
                  isDense: true,
                  hintText: 'https://your-worker.workers.dev',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 5),
              Text(
                'پیام‌ها برای پاسخ‌گویی به Gemini فرستاده می‌شوند؛ اطلاعات شخصی وارد نکن و کلید API را اینجا ننویس. مصرف سرویس تابع سهمیه و تنظیمات حساب است؛ فعال‌سازی را با والد یا سرپرست انجام بده.',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _emptyState(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.auto_awesome_rounded,
                size: 54, color: theme.colorScheme.primary),
            const SizedBox(height: 14),
            Text('سلام! من دستیار هوشمند فهمینو هستم.',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              'می‌توانی دربارهٔ ریاضی، علوم، فارسی، انگلیسی و دیگر درس‌های هشتم سؤال بپرسی.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 10),
            Text(
              'پاسخ‌های هوش مصنوعی ممکن است اشتباه باشند؛ با کتاب درسی هم بررسی کن.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  void _showConnectionInfo() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تنظیم اتصال'),
        content: const Text(
          'آدرس HTTPS مربوط به Cloudflare Worker را در کادر بالای صفحه وارد و ذخیره کن. کلید Gemini فقط باید در Secretهای سرور نگهداری شود؛ آن را اینجا یا در GitHub ننویس. پیش از فعال‌سازی، سهمیه و احتمال هزینه را با والد یا سرپرست بررسی کن.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('متوجه شدم')),
        ],
      ),
    );
  }
}

class _ChatMessage {
  const _ChatMessage({required this.text, required this.isUser});
  final String text;
  final bool isUser;
}

class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.text,
    required this.isUser,
    this.pending = false,
  });

  final String text;
  final bool isUser;
  final bool pending;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = isUser
        ? theme.colorScheme.primaryContainer
        : theme.colorScheme.surfaceContainerHighest;
    return Align(
      alignment:
          isUser ? AlignmentDirectional.centerEnd : AlignmentDirectional.centerStart,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 340),
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(17),
        ),
        child: SelectableText(
          text,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: isUser
                ? theme.colorScheme.onPrimaryContainer
                : theme.colorScheme.onSurface,
          ),
        ),
      ),
    );
  }
}
