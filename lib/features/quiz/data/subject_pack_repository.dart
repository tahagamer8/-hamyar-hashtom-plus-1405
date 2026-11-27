import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:hamyar_hashtom_plus/features/quiz/domain/subject_pack.dart';

/// Loads the bundled subject packs for the exam sections.
///
/// Packs under assets/content/subjects/ win over the legacy catalog entry of
/// the same subject. Malformed packs are skipped instead of failing the whole
/// list.
class SubjectPackRepository {
  const SubjectPackRepository(this._bundle);

  final AssetBundle _bundle;

  static const String _prefix = 'assets/content/subjects/';
  static const String _suffix = '.json';

  Future<List<SubjectPack>> loadAll() async {
    final catalog = await _loadCatalog();
    final ids = <String>{...catalog.keys};
    try {
      final manifest = await AssetManifest.loadFromAssetBundle(_bundle);
      final found = manifest
          .listAssets()
          .where((asset) => asset.startsWith(_prefix) && asset.endsWith(_suffix))
          .map((asset) =>
              asset.substring(_prefix.length, asset.length - _suffix.length))
          .toList()
        ..sort();
      ids.addAll(found);
    } catch (_) {
      // Without a manifest only the catalog subjects are listed.
    }
    final packs = <SubjectPack>[];
    for (final id in ids) {
      final pack = await _loadPack(id, catalog[id]);
      if (pack != null) {
        packs.add(pack);
      }
    }
    return packs;
  }

  Future<Map<String, dynamic>> _loadCatalog() async {
    try {
      final raw = await _bundle.loadString('assets/content/catalog_fa.json');
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } catch (_) {
      // A missing catalog only removes the legacy fallback.
    }
    return const <String, dynamic>{};
  }

  Future<SubjectPack?> _loadPack(String id, Object? legacy) async {
    try {
      final raw = await _bundle.loadString('$_prefix$id$_suffix');
      final pack = _parse(id, jsonDecode(raw));
      if (pack != null) {
        return pack;
      }
    } catch (_) {
      // Fall back to the legacy catalog entry below.
    }
    return _parse(id, legacy);
  }

  SubjectPack? _parse(String id, Object? raw) {
    if (raw is! Map) {
      return null;
    }
    final declaredId = raw['subjectId'];
    if (declaredId != null && declaredId != id) {
      return null;
    }
    final title = raw['title'];
    final chapters = raw['chapters'];
    if (title is! String || title.trim().isEmpty) {
      return null;
    }
    if (chapters is! List || chapters.isEmpty) {
      return null;
    }
    final parsed = <Map<String, dynamic>>[];
    for (final chapter in chapters) {
      if (chapter is Map) {
        parsed.add(Map<String, dynamic>.from(chapter));
      }
    }
    if (parsed.isEmpty) {
      return null;
    }
    return SubjectPack(id: id, title: title, chapters: parsed);
  }
}
