import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

class VideoLibraryScreen extends StatefulWidget {
  const VideoLibraryScreen({
    super.key,
    required this.subjectId,
    required this.subjectTitle,
  });

  final String subjectId;
  final String subjectTitle;

  @override
  State<VideoLibraryScreen> createState() => _VideoLibraryScreenState();
}

class _VideoLibraryScreenState extends State<VideoLibraryScreen> {
  late final Future<List<Map<String, dynamic>>> _videosFuture;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _videosFuture = _loadVideos();
  }

  Future<List<Map<String, dynamic>>> _loadVideos() async {
    final raw = await rootBundle.loadString(
      'assets/content/video_lessons_fa.json',
    );
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic> || decoded['videos'] is! List) {
      throw const FormatException('فهرست ویدئوهای فهمینو معتبر نیست.');
    }

    return (decoded['videos'] as List<dynamic>)
        .whereType<Map<String, dynamic>>()
        .where((video) => video['subjectId'] == widget.subjectId)
        .where(_hasSafeExternalSource)
        .toList(growable: false);
  }

  bool _hasSafeExternalSource(Map<String, dynamic> video) {
    final rawUrl = video['url'];
    if (rawUrl is! String) return false;
    final uri = Uri.tryParse(rawUrl);
    return uri != null &&
        uri.scheme == 'https' &&
        const {'telewebion.net', 'telewebion.ir', 'tv7.ir'}.contains(uri.host);
  }

  Future<void> _openVideo(Map<String, dynamic> video) async {
    final uri = Uri.parse(video['url'] as String);
    final opened = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('باز کردن منبع ویدئو ممکن نشد.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text('ویدئوهای ${widget.subjectTitle}')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _videosFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'فهرست ویدئوها بارگذاری نشد. بعداً دوباره امتحان کن.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final videos = snapshot.data ?? const <Map<String, dynamic>>[];
          final normalizedQuery = _query.trim().toLowerCase();
          final filtered = videos.where((video) {
            final title = (video['title'] as String? ?? '').toLowerCase();
            final lesson = (video['lesson'] as String? ?? '').toLowerCase();
            return normalizedQuery.isEmpty ||
                title.contains(normalizedQuery) ||
                lesson.contains(normalizedQuery);
          }).toList(growable: false);

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
            children: [
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: theme.colorScheme.secondaryContainer.withAlpha(110),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.ondemand_video_rounded,
                        color: theme.colorScheme.primary, size: 26),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'ویدئوها از آرشیو شبکهٔ آموزش و میزبان اصلی باز می‌شوند. '
                        'فهمینو نسخهٔ ویدئوها را دانلود یا بازنشر نمی‌کند.',
                        style: theme.textTheme.bodySmall?.copyWith(height: 1.7),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                textDirection: TextDirection.rtl,
                decoration: InputDecoration(
                  hintText: 'جست‌وجو در عنوان ویدئو یا مبحث...',
                  prefixIcon: const Icon(Icons.search_rounded),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onChanged: (value) => setState(() => _query = value),
              ),
              const SizedBox(height: 14),
              if (filtered.isEmpty) ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      children: [
                        const Icon(Icons.video_library_outlined, size: 38),
                        const SizedBox(height: 10),
                        Text(
                          videos.isEmpty
                              ? 'هنوز ویدئوی دارای منبع قابل‌تأیید برای این درس ثبت نشده است.'
                              : 'ویدئویی با این عبارت پیدا نشد.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.titleSmall,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'منابع جدید فقط پس از بررسی ارتباط با کتاب هشتم و قابل‌استناد بودن میزبان اضافه می‌شوند.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall,
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: () => launchUrl(
                            Uri.parse('https://tv7.ir/tvschool'),
                            mode: LaunchMode.externalApplication,
                          ),
                          icon: const Icon(Icons.open_in_new_rounded),
                          label: const Text('آرشیو مدرسهٔ تلویزیونی ایران'),
                        ),
                      ],
                    ),
                  ),
                ),
              ] else ...[
                Text(
                  '${filtered.length} ویدئوی آموزشی',
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: 10),
                for (final video in filtered)
                  Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () => _openVideo(video),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primaryContainer,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Icon(
                                Icons.play_circle_fill_rounded,
                                color: theme.colorScheme.primary,
                                size: 30,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    video['title'] as String? ?? 'ویدئوی آموزشی',
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  if (video['lesson'] is String) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      video['lesson'] as String,
                                      style: theme.textTheme.bodySmall,
                                    ),
                                  ],
                                  const SizedBox(height: 5),
                                  Text(
                                    '${video['sourceName'] ?? 'منبع آموزشی'}'
                                    '${video['published'] is String ? ' • ${video['published']}' : ''}',
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 6),
                            Icon(Icons.open_in_new_rounded,
                                color: theme.colorScheme.primary),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
              const SizedBox(height: 8),
              Text(
                'یادآوری: پیوندها به میزبان اصلی می‌روند؛ در صورت حذف یا جابه‌جایی ویدئو، ممکن است پیوند تغییر کند.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
