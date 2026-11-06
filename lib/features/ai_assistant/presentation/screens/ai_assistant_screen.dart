import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hamyar_hashtom_plus/features/ai_assistant/data/gemini_api_service.dart';
import 'package:hamyar_hashtom_plus/features/lessons/data/ai_lesson_cache.dart';

class AiAssistantScreen extends StatefulWidget {
  const AiAssistantScreen({super.key, this.studyContext, this.initialPrompt, this.lessonCacheKey});

  final Map<String, dynamic>? studyContext;
  final String? initialPrompt;
  final String? lessonCacheKey;

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
  bool _checkingConnection = false;
  bool _initialLessonSaved = false;
  bool? _connectionHealthy;
  String? _connectionStatus;
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

  String _clipText(Object? value, int maxLength) {
    final text = value?.toString() ?? '';
    return text.length <= maxLength
        ? text
        : '${text.substring(0, maxLength)}…';
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
      studyPoints.addAll(
        (section['examples'] as List<dynamic>? ?? []).whereType<String>(),
      );
    }
    final practiceQuestions = <String>[];
    for (final raw in [
      ...(chapter['questions'] as List<dynamic>? ?? []).take(1),
      ...(chapter['challengeQuestions'] as List<dynamic>? ?? []).take(2),
    ]) {
      if (raw is! Map) continue;
      final prompt = raw['question']?.toString() ?? '';
      final options = (raw['options'] as List<dynamic>? ?? []).whereType<String>();
      final answerIndex = raw['answer'];
      final answer = answerIndex is int && answerIndex >= 0 && answerIndex < options.length
          ? options.elementAt(answerIndex)
          : '';
      final explanation = raw['explanation']?.toString() ?? '';
      if (prompt.isNotEmpty) {
        practiceQuestions.add(
          'تمرین: $prompt | گزینه‌ها: ${options.join('؛ ')} | پاسخ: $answer | توضیح: $explanation',
        );
      }
    }
    final pageReferences = <String>[];
    final rawPageReferences = chapter['pageReferences'];
    if (rawPageReferences is List) {
      for (final raw in rawPageReferences.take(6)) {
        if (raw is String && raw.trim().isNotEmpty) {
          pageReferences.add(_clipText(raw, 160));
        } else if (raw is Map) {
          final page = raw['page'] ?? raw['pageNumber'] ?? raw['pages'];
          final title = raw['title']?.toString() ?? '';
          final status = raw['verificationStatus']?.toString() ?? 'نامشخص';
          if (page != null || title.isNotEmpty) {
            pageReferences.add(_clipText(
              'صفحه: ${page ?? 'نامشخص'}؛ ${title.isEmpty ? '' : '$title؛ '}وضعیت: $status',
              160,
            ));
          }
        }
      }
    }
    final bookSolutions = <String>[];
    for (final raw in (chapter['bookSolutions'] as List<dynamic>? ?? []).take(4)) {
      if (raw is! Map) continue;
      final page = raw['page'] ?? raw['pageNumber'] ?? 'نامشخص';
      final prompt = raw['question']?.toString() ?? raw['prompt']?.toString() ?? '';
      final answer = raw['answer']?.toString() ?? '';
      final explanation = raw['explanation']?.toString() ?? '';
      final status = raw['verificationStatus']?.toString() ?? 'نامشخص';
      if (answer.isNotEmpty) {
        bookSolutions.add(_clipText(
          'صفحه: $page | پرسش: $prompt | پاسخ: $answer | توضیح: $explanation | وضعیت تأیید: $status',
          900,
        ));
      }
    }

    return {
      'subjectTitle': _clipText(subject['title'] ?? 'درس', 100),
      'chapterTitle': _clipText(chapter['title'] ?? 'فصل', 100),
      'bookChapterTitle': _clipText(chapter['bookChapterTitle'], 160),
      'bookScope': _clipText(chapter['bookScope'], 300),
      'alignmentStatus': _clipText(
        chapter['alignmentStatus'] ?? 'not_verified_against_1405_1406_pdf',
        80,
      ),
      'summary': _clipText(chapter['summary'], 900),
      'points': studyPoints.take(6).map((point) => _clipText(point, 180)).toList(),
      'example': _clipText(chapter['example'], 400),
      'solutionSteps': (chapter['solutionSteps'] as List<dynamic>? ?? [])
          .whereType<String>()
          .take(5)
          .map((step) => _clipText(step, 180))
          .toList(),
      'practiceQuestions': practiceQuestions
          .take(3)
          .map((question) => _clipText(question, 350))
          .toList(),
      'pageReferences': pageReferences,
      'bookSolutions': bookSolutions,
      'contentVerificationStatus': _clipText(
        chapter['verificationStatus'] ?? 'not_verified_against_official_textbook',
        80,
      ),
      'sourceLabel': _clipText(
        chapter['source'] is Map
            ? (chapter['source'] as Map)['title'] ??
                'محتوای فعلی فهمینو؛ منبع نیازمند بررسی است'
            : 'محتوای تألیفی فهمینو؛ نیازمند تطبیق با کتاب رسمی',
        160,
      ),
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
      if (mounted) {
        setState(() => _ready = true);
        final prompt = widget.initialPrompt?.trim();
        if (prompt != null && prompt.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _messages.isEmpty) _askSuggested(prompt);
          });
        }
      }
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

  Future<void> _checkConnection() async {
    if (_checkingConnection) return;
    setState(() {
      _checkingConnection = true;
      _connectionStatus = null;
    });
    try {
      final health = await _service.checkHealth(workerUrl: _urlInput.text);
      if (!mounted) return;
      final configured = health['geminiSecretConfigured'] == true &&
          health['rateLimiterConfigured'] == true;
      setState(() {
        _connectionHealthy = configured;
        _connectionStatus = configured
            ? 'سرور پاسخ می‌دهد و تنظیمات لازم روی Cloudflare وجود دارد.'
            : 'سرور پاسخ می‌دهد، اما بخشی از تنظیمات آن کامل نیست.';
      });
    } on GeminiApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _connectionHealthy = false;
        _connectionStatus = e.message;
      });
    } finally {
      if (mounted) setState(() => _checkingConnection = false);
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
      final cacheKey = widget.lessonCacheKey?.trim();
      if (!_initialLessonSaved &&
          widget.initialPrompt?.trim().isNotEmpty == true &&
          cacheKey != null &&
          cacheKey.isNotEmpty) {
        try {
          await AiLessonCache.save(lessonKey: cacheKey, content: answer);
          _initialLessonSaved = true;
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('درسنامهٔ تکمیلی روی همین دستگاه ذخیره شد.')),
            );
          }
        } catch (_) {
          if (mounted) {
            setState(() => _error = 'پاسخ دریافت شد، اما ذخیرهٔ محلی آن انجام نشد.');
          }
        }
      }
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

  void _askSuggested(String prompt) {
    if (_loading) return;
    _input.text = prompt;
    _send();
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
                    padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(26),
                        border: Border.all(
                          color: theme.colorScheme.outlineVariant.withAlpha(110),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: theme.colorScheme.shadow.withAlpha(12),
                            blurRadius: 14,
                            offset: const Offset(0, -3),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 6, 8, 6),
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
                                  hintText: 'سؤالت را اینجا بنویس…',
                                  border: InputBorder.none,
                                  counterText: '',
                                  filled: true,
                                  fillColor: Colors.transparent,
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 12,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            IconButton.filled(
                              onPressed: _loading ? null : _send,
                              tooltip: 'ارسال پیام',
                              icon: const Icon(Icons.arrow_upward_rounded),
                              style: IconButton.styleFrom(
                                minimumSize: const Size(48, 48),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(17),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
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
          title: const Text('اتصال امن به Gemini'),
          subtitle: const Text('از مسیر Cloudflare Worker فهمینو'),
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
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: _checkingConnection ? null : _checkConnection,
                  icon: _checkingConnection
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.wifi_tethering_rounded),
                  label: Text(_checkingConnection ? 'در حال بررسی' : 'بررسی سرور'),
                ),
                FilledButton.tonalIcon(
                  onPressed: _saveUrl,
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('ذخیرهٔ آدرس'),
                ),
              ],
            ),
            if (_connectionStatus != null) ...[
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    _connectionHealthy == true
                        ? Icons.check_circle_outline_rounded
                        : Icons.info_outline_rounded,
                    size: 18,
                    color: _connectionHealthy == true
                        ? theme.colorScheme.primary
                        : theme.colorScheme.error,
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      _connectionStatus!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: _connectionHealthy == true
                            ? theme.colorScheme.primary
                            : theme.colorScheme.error,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            Text(
              'این بررسی فقط دسترسی به Worker و وجود تنظیمات سرور را می‌سنجد؛ اعتبار کلید یا پاسخ واقعی Gemini را آزمایش نمی‌کند. پیام‌ها برای پاسخ‌گویی به Gemini فرستاده می‌شوند. کلید API را در برنامه وارد نکن و دربارهٔ سهمیه و هزینه با والد یا سرپرست هماهنگ کن.',
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
    final scope = _activeStudyContext?['bookScope']?.toString() ?? '';
    final unverified = _activeStudyContext?['alignmentStatus'] ==
        'not_verified_against_1405_1406_pdf';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.colorScheme.primaryContainer.withAlpha(90),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.colorScheme.primary.withAlpha(35)),
        ),
        child: Row(
          children: [
            Icon(Icons.menu_book_rounded, color: theme.colorScheme.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$subject — $chapter', style: theme.textTheme.labelLarge),
                  if (scope.isNotEmpty)
                    Text(scope, style: theme.textTheme.bodySmall),
                  Text(
                    unverified
                        ? 'محتوای این فصل هنوز با PDF چاپ ۱۴۰۵–۱۴۰۶ تأیید نشده'
                        : 'زمینهٔ درسی برای پاسخ‌گویی فعال است',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: unverified
                          ? theme.colorScheme.error
                          : theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyState(ThemeData theme) {
    final colors = theme.colorScheme;
    final suggestions = <({IconData icon, String title, String prompt})>[
      (icon: Icons.menu_book_rounded, title: 'درسنامهٔ کامل فصل', prompt: 'برای فصل انتخاب‌شده یک درسنامهٔ کامل و منظم تهیه کن: هدف‌های یادگیری، پیش‌نیازها، آموزش مفهومی مرحله‌به‌مرحله، دست‌کم دو مثال مستقل و حل‌شده، اشتباه‌های رایج و پنج تمرین تألیفی از متوسط تا دشوار با پاسخ تشریحی. اگر بخشی از محتوای کتاب را نداری، آن را آموزش تکمیلی تألیفی فهمینو معرفی کن و شماره صفحه یا متن رسمی حدس نزن.'),
      (icon: Icons.calculate_rounded, title: 'حل مسئلهٔ چندمرحله‌ای', prompt: 'از فصل انتخاب‌شده یک مسئلهٔ دشوار و چندمرحله‌ای طرح کن؛ ابتدا فقط صورت سؤال را بده، بعد از پاسخ من راه‌حل مرحله‌به‌مرحله و بررسی نهایی را توضیح بده.'),
      (icon: Icons.quiz_rounded, title: 'آزمون سطح بالا', prompt: 'از فصل انتخاب‌شده یک آزمون دشوار و مفهومی در سطح تیزهوشان طراحی کن؛ سؤال‌ها متنوع و چندمرحله‌ای باشند و پاسخ‌ها را تا وقتی جواب نداده‌ام فاش نکن.'),
      (icon: Icons.edit_note_rounded, title: 'تمرین تشریحی', prompt: 'از فصل انتخاب‌شده پنج تمرین تشریحی مستقل از متوسط تا دشوار طراحی کن؛ هر بار فقط یک سؤال بپرس و پس از پاسخ من، دقیق تصحیح کن و اشکال‌ها را توضیح بده.'),
    ];    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: AlignmentDirectional.topStart,
                end: AlignmentDirectional.bottomEnd,
                colors: [
                  colors.primary,
                  Color.lerp(colors.primary, colors.tertiary, 0.55)!,
                ],
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: colors.primary.withAlpha(45),
                  blurRadius: 22,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(35),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.auto_awesome_rounded,
                      color: Colors.white, size: 27),
                ),
                const SizedBox(height: 18),
                Text(
                  'یادگیری، با گفت‌وگو ساده‌تر می‌شود',
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'از دستیار فهمینو بخواه مفهوم‌ها را توضیح دهد، مسئله‌ها را مرحله‌به‌مرحله حل کند یا از تو آزمون بگیرد.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withAlpha(235),
                    height: 1.8,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    const Icon(Icons.shield_outlined,
                        color: Colors.white, size: 16),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'پاسخ‌ها را با کتاب و منبع درسی بررسی کن.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.white.withAlpha(225),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          Text('از کجا شروع کنیم؟', style: theme.textTheme.titleMedium),
          const SizedBox(height: 10),
          for (final item in suggestions)
            Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: Material(
                color: colors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(17),
                child: InkWell(
                  borderRadius: BorderRadius.circular(17),
                  onTap: () => _askSuggested(item.prompt),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 13),
                    child: Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: colors.primaryContainer,
                            borderRadius: BorderRadius.circular(13),
                          ),
                          child: Icon(item.icon, color: colors.primary),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(item.title,
                              style: theme.textTheme.titleSmall),
                        ),
                        Icon(Icons.arrow_back_ios_new_rounded,
                            size: 16, color: colors.onSurfaceVariant),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
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
    final colors = theme.colorScheme;
    final bubbleColor = isUser
        ? colors.primaryContainer
        : colors.surfaceContainerHighest;
    final bubbleTextColor =
        isUser ? colors.onPrimaryContainer : colors.onSurface;

    final message = Flexible(
      child: Column(
        crossAxisAlignment:
            isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 4, end: 4, bottom: 4),
            child: Text(
              isUser ? 'شما' : 'فهمینو',
              style: theme.textTheme.labelSmall?.copyWith(
                color: colors.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Container(
            constraints: const BoxConstraints(maxWidth: 300),
            margin: const EdgeInsets.symmetric(vertical: 2),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: bubbleColor,
              borderRadius: BorderRadiusDirectional.only(
                topStart: const Radius.circular(19),
                topEnd: const Radius.circular(19),
                bottomStart: Radius.circular(isUser ? 19 : 5),
                bottomEnd: Radius.circular(isUser ? 5 : 19),
              ),
            ),
            child: pending
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 15,
                        height: 15,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: bubbleTextColor,
                        ),
                      ),
                      const SizedBox(width: 9),
                      Text(text, style: theme.textTheme.bodyMedium),
                    ],
                  )
                : SelectableText(
                    text,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: bubbleTextColor,
                      height: 1.7,
                    ),
                  ),
          ),
        ],
      ),
    );

    final avatar = CircleAvatar(
      radius: 15,
      backgroundColor: isUser ? colors.tertiaryContainer : colors.primaryContainer,
      child: Icon(
        isUser ? Icons.person_outline_rounded : Icons.auto_awesome_rounded,
        size: 17,
        color: isUser ? colors.onTertiaryContainer : colors.primary,
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: isUser
            ? [message, const SizedBox(width: 8), avatar]
            : [avatar, const SizedBox(width: 8), message],
      ),
    );
  }
}