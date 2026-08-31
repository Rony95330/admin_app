import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'home_banner_model.dart';

/// Version dédiée à la console d'administration.
/// Elle n'embarque volontairement aucun cache local de l'application mobile.
class HomeBannerService {
  HomeBannerService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  static const String _table = 'home_banners';
  static const String _bucket = 'home-banners';

  Future<List<HomeBanner>> fetchAllForAdmin() async {
    final rows = await _client
        .from(_table)
        .select()
        .order('archived_at', ascending: true)
        .order('sort_order')
        .order('created_at', ascending: false);
    return (rows as List)
        .map((e) => HomeBanner.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList(growable: false);
  }

  Future<HomeBanner> create(Map<String, dynamic> values) async {
    final payload = Map<String, dynamic>.from(values)
      ..remove('id')
      ..['created_by'] = _client.auth.currentUser?.id;
    final row = await _client.from(_table).insert(payload).select().single();
    return HomeBanner.fromMap(Map<String, dynamic>.from(row));
  }

  Future<HomeBanner> update(String id, Map<String, dynamic> values) async {
    final payload = Map<String, dynamic>.from(values)
      ..remove('id')
      ..remove('created_at')
      ..remove('updated_at');
    final row = await _client
        .from(_table)
        .update(payload)
        .eq('id', id)
        .select()
        .single();
    return HomeBanner.fromMap(Map<String, dynamic>.from(row));
  }

  Future<void> setActive(String id, bool active) async {
    await _client.from(_table).update({'is_active': active}).eq('id', id);
  }

  Future<void> archive(String id) async {
    await _client.from(_table).update({
      'archived_at': DateTime.now().toUtc().toIso8601String(),
      'is_active': false,
    }).eq('id', id);
  }

  Future<void> delete(HomeBanner banner) async {
    await _client.from(_table).delete().eq('id', banner.id);

    final ownedPaths = <String>{};
    final imagePath = banner.imageStoragePath?.trim() ?? '';
    if (imagePath.isNotEmpty) ownedPaths.add(imagePath);

    final actionValue = banner.actionValue?.trim() ?? '';
    const prefix = 'home-banners:';
    if (banner.actionType == 'pdf' && actionValue.startsWith(prefix)) {
      final path = actionValue.substring(prefix.length).trim();
      if (path.isNotEmpty) ownedPaths.add(path);
    }

    if (ownedPaths.isNotEmpty) {
      try {
        await _client.storage.from(_bucket).remove(ownedPaths.toList());
      } catch (_) {
        // La suppression de la ligne reste valide même si un ancien fichier manque.
      }
    }
  }

  Future<HomeBanner> duplicate(HomeBanner source) async {
    final payload = source.toMap(includeId: false)
      ..['title'] = '${source.title} — copie'
      ..['is_active'] = false
      ..['archived_at'] = null
      ..['sort_order'] = source.sortOrder + 1
      ..['created_by'] = _client.auth.currentUser?.id;
    final row = await _client.from(_table).insert(payload).select().single();
    return HomeBanner.fromMap(Map<String, dynamic>.from(row));
  }

  Future<void> reorder(List<HomeBanner> banners) async {
    for (var i = 0; i < banners.length; i++) {
      await _client
          .from(_table)
          .update({'sort_order': (i + 1) * 10})
          .eq('id', banners[i].id);
    }
  }

  Future<String> uploadActionPdf({
    required String fileName,
    required Uint8List bytes,
  }) async {
    final safeName = fileName
        .trim()
        .replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_')
        .replaceAll(RegExp(r'_+'), '_');
    final normalizedName = safeName.toLowerCase().endsWith('.pdf')
        ? safeName
        : '$safeName.pdf';
    final storagePath =
        'documents/${DateTime.now().millisecondsSinceEpoch}_$normalizedName';
    await _client.storage.from(_bucket).uploadBinary(
          storagePath,
          bytes,
          fileOptions: const FileOptions(
            upsert: false,
            contentType: 'application/pdf',
          ),
        );
    return '$_bucket:$storagePath';
  }

  Future<List<Map<String, dynamic>>> fetchActionChoices(
    String actionType,
  ) async {
    switch (actionType) {
      case 'tract':
        final rows = await _client
            .from('articles')
            .select('id,title,description,pdf_url,thumb_url,storage_path,cse,published_at')
            .order('published_at', ascending: false)
            .limit(1000);
        return List<Map<String, dynamic>>.from(rows as List);
      case 'press_review':
        final rows = await _client
            .from('revue_presse')
            .select()
            .order('date_publication', ascending: false)
            .limit(1000);
        return List<Map<String, dynamic>>.from(rows as List);
      case 'podcast':
        final rows = await _client
            .from('podcasts')
            .select('id,title,description,audio_url,audio_path,cse,duration_seconds,published_at,is_active')
            .eq('is_active', true)
            .order('published_at', ascending: false)
            .limit(1000);
        return List<Map<String, dynamic>>.from(rows as List);
      default:
        return const <Map<String, dynamic>>[];
    }
  }

  Future<String?> resolveActionTitle({
    required String actionType,
    required String actionValue,
  }) async {
    final value = actionValue.trim();
    if (value.isEmpty) return null;
    try {
      switch (actionType) {
        case 'tract':
          final id = int.tryParse(value);
          if (id == null) return null;
          final row = await _client.from('articles').select('title').eq('id', id).maybeSingle();
          return row?['title']?.toString().trim();
        case 'press_review':
          final id = int.tryParse(value);
          if (id == null) return null;
          final row = await _client.from('revue_presse').select('titre').eq('id', id).maybeSingle();
          return row?['titre']?.toString().trim();
        case 'podcast':
          final row = await _client.from('podcasts').select('title').eq('id', value).maybeSingle();
          return row?['title']?.toString().trim();
        case 'pdf':
          final separator = value.lastIndexOf('/');
          return separator >= 0 ? value.substring(separator + 1) : value;
        default:
          return null;
      }
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>> stats(String bannerId) async {
    final result = await _client.rpc(
      'home_banner_stats',
      params: {'p_banner_id': bannerId},
    );
    if (result is List && result.isNotEmpty) {
      return Map<String, dynamic>.from(result.first as Map);
    }
    if (result is Map) return Map<String, dynamic>.from(result);
    return const <String, dynamic>{};
  }
}
