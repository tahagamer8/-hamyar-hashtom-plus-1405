import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hamyar_hashtom_plus/features/ai_assistant/data/gemini_api_service.dart';

class AiAssistantScreen extends StatefulWidget {
  const AiAssistantScreen({super.key, this.studyContext});

  final Map<String, dynamic>? studyContext;

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
  Map<String, dynamic>? _activeStudyContext;
  Future<Map<String, dynamic>>? _catalogFuture;
  String? _selectedStudyKey;
  bool _loading = false;
  bool _ready = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _activeStudyContext = widget.studyContext;
    _loadUrl();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _catalogFuture ??= DefaultAssetBundle.of(context)
        .loadString('assets/content/catalog_fa.json')
        .then((raw) {
      final catalog = jsonDecode(raw) as Map<String, dynamic>;
      _resolveInitialStudySelection(catalog);
      return catalog;
    });
  }

  void _resolveInitialStudySelection(Map<String, dynamic> catalog) {
    final context = _activeStudyContext;
    if (context == null) return;
    for (final subjectEntry in catalog.entries) {
      final subject = subjectEntry.value as Map<String, dynamic>;
      final chapters = (subject['chapters'] as List<dynamic>? ?? []);
      for (var index = 0; index < chapters.length; index++) {
        final chapter = chapters[index] as Map<String, dynamic>;
        if ((subject['title']?.toString() ?? '') == context['subjectTitle'] &&
            (chapter['title']?.toString() ?? '') == context['chapterTitle']) {
          _selectedStudyKey = '${subjectEntry.key}::$index';
          _activeStudyContext = _makeStudyContext(subject, chapter);
          return;
        }
      }
    }
  }

  Map<String, dynamic> _makeStudyContext(
    Map<String, dynamic> subject,
    Map<String, dynamic> chapter,
  ) {
    final studyPoints = <String>[
      ...(chapter['points'] as List<dynamic>? ?? []).whereType<String>(),
    ];
    final sections = (chapter['learningSections'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>();
    for (final section in sections) {
      final title = section['title']?.toString() ?? '';
      final content = section['content']?.toString() ?? '';
      if (title.isNotEmpty) studyPoints.add('بخش آموزشی: $title');
      if (content.isNotEmpty) {
        studyPoints.add(content.length > 400 ? content.substring(0, 400) : content);
      }
      studyPoints.addAll(
        (section['keyPoints'] as List<dynamic>? ?? []).whereType<String>(),
      );
    }
    return {
      'subjectTitle': subject['title']?.toString() ?? 'درس',
      'chapterTitle': chapter['title']?.toString() ?? 'فصل',
      'summary': chapter['summary']?.toString() ?? '',
      'points': studyPoints.take(8).map((point) =>
          point.length > 400 ? point.substring(0, 400) : point).toList(),
      'example': chapter['example']?.toString() ?? '',
      'solutionSteps': (chapter['solutionSteps'] as List<dynamic>? ?? [])
          .whereType<String>().take(8).toList(),
      'sourceLabel': 'محتوای فعلی فهمینو؛ ممکن است هنوز با چاپ رسمی تطبیق کامل نشده باشد',
    };
  }

  Widget _studyPicker(ThemeData theme) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _catalogFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();
        final options = <DropdownMenuItem<String>>[];
        final lookup = <String, Map<String, dynamic>>{};
        for (final entry in snapshot.data!.entries) {
          final subject = entry.value as Map<String, dynamic>;
          final chapters = (subject['chapters'] as List<dynamic>? ?? []);
          for (var index = 0; index < chapters.length; index++) {
            final chapter = chapters[index] as Map<String, dynamic>;
            final key = '${entry.key}::$index';
            lookup[key] = {
              'subjectId': entry.key,
              'subject': subject,
              'chapter': chapter,
            };
            options.add(DropdownMenuItem<String>(
              value: key,
              child: Text(
                '${subject['title'] ?? entry.key} — ${chapter['title'] ?? 'فصل'}',
                overflow: TextOverflow.ellipsis,
              ),
            ));
          }
        }
        final selected = lookup.containsKey(_selectedStudyKey)
            ? _selectedStudyKey
            : null;
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
          child: Card(
            margin: EdgeInsets.zero,
            child: ExpansionTile(
              initiallyExpanded: selected == null,
              leading: Icon(Icons.menu_book_rounded, color: theme.colorScheme.primary),
              title: const Text('پایه و فصل موردنظر را انتخاب کن'),
              subtitle: Text(selected == null
                  ? 'برای پاسخ دقیق‌تر، زمینهٔ کتاب را مشخص کن'
                  : 'فصل انتخاب‌شده به دستیار فرستاده می‌شود'),
              childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              children: [
                DropdownButtonFormField<String>(
                  key: ValueKey(selected),
                  initialValue: selected,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'درس و فصل',
                    border: OutlineInputBorder(),
                  ),
                  items: options,
                  onChanged: (key) {
                    if (key == null) return;
                    final selectedData = lookup[key]!;
                    setState(() {
                      _selectedStudyKey = key;
                      _activeStudyContext = _makeStudyContext(
                        selectedData['subject'] as Map<String, dynamic>,
                        selectedData['chapter'] as Map<String, dynamic>,
                      );
                    });
                  },
                ),
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: TextButton.icon(
                    onPressed: () => setState(() {
                      _selectedStudyKey = null;
                      _activeStudyContext = null;
                    }),
                    icon: const Icon(Icons.close_rounded),
                    label: const Text('حذف زمینهٔ درسی'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
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
        studyContext: _activeStudyContext,
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
                _studyPicker(theme),
                if (_activeStudyContext != null)
                  _studyContextPanel(theme),
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
      child: Card(
        margin: EdgeInsets.zero,
        child: ExpansionTile(
          initiallyExpanded: false,
          leading: Icon(Icons.cloud_done_outlined, color: theme.colorScheme.primary),
          title: const Text('اتصال هوش مصنوعی'),
          subtitle: const Text('تنظیم سرور فهمینو و وضعیت حریم خصوصی'),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          children: [
            TextField(
              controller: _urlInput,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                isDense: true,
                labelText: 'آدرس پایهٔ سرور',
                hintText: 'https://your-worker.workers.dev',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: FilledButton.tonalIcon(
                onPressed: _saveUrl,
                icon: const Icon(Icons.save_outlined),
                label: const Text('ذخیرهٔ آدرس'),
              ),
            ),
            Text(
              'پیام‌ها برای پاسخ‌گویی به Gemini فرستاده می‌شوند. اطلاعات شخصی یا کلید API را وارد نکن. فعال‌سازی سرویس و بررسی سهمیه یا هزینه باید با والد یا سرپرست انجام شود.',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _studyContextPanel(ThemeData theme) {
    final subject = _activeStudyContext?['subjectTitle']?.toString() ?? 'درس';
    final chapter = _activeStudyContext?['chapterTitle']?.toString() ?? 'فصل';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: theme.colorScheme.primaryContainer.withAlpha(100),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(Icons.menu_book_rounded, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'زمینهٔ گفتگو: $subject — $chapter',
                style: theme.textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyState(ThemeData theme) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.auto_awesome_rounded,
                    size: 48, color: theme.colorScheme.primary),
                const SizedBox(height: 12),
                Text(
                  'سلام! من دستیار هوشمند فهمینو هستم.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium,
                ),
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
