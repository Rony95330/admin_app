import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Service d'administration du module Élections Pro.
/// Le suivi de participation/votants reste indépendant.
class ElectionService {
  ElectionService({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  static const String _bucket = 'elections';

  Future<void> _signInto(
    Map<String, dynamic> row,
    String pathKey,
    String urlKey,
  ) async {
    final storagePath = row[pathKey]?.toString().trim() ?? '';
    if (storagePath.isEmpty) return;

    row[urlKey] = await _client.storage
        .from(_bucket)
        .createSignedUrl(storagePath, 60 * 60);
  }

  Future<void> _hydrateMediaUrls(Map<String, dynamic> row) async {
    await _signInto(row, 'hero_storage_path', 'hero_image_url');
    await _signInto(row, 'media_storage_path', 'media_url');
    await _signInto(row, 'cover_storage_path', 'cover_image_url');
    await _signInto(row, 'photo_storage_path', 'photo_url');
  }

  Future<List<String>> adminListCse() async {
    final raw = await _client.rpc('get_manageable_election_cse');
    return (raw as List)
        .whereType<Map>()
        .map((e) => e['cse']?.toString().trim() ?? '')
        .where((e) => e.isNotEmpty)
        .toList(growable: false);
  }

  Future<List<Map<String, dynamic>>> adminListCampaigns() async {
    final raw = await _client.rpc('get_manageable_election_campaigns');
    final rows = List<Map<String, dynamic>>.from(raw as List);

    for (final row in rows) {
      await _hydrateMediaUrls(row);
    }

    return rows;
  }

  Future<Map<String, dynamic>> adminGetCampaign(String campaignId) async {
    final raw = await _client
        .from('election_campaigns')
        .select()
        .eq('id', campaignId)
        .single();
    final row = Map<String, dynamic>.from(raw);
    await _hydrateMediaUrls(row);
    return row;
  }

  Future<String> adminCreateCampaign(Map<String, dynamic> payload) async {
    final raw = await _client
        .from('election_campaigns')
        .insert(payload)
        .select('id')
        .single();
    return raw['id'].toString();
  }

  Future<void> adminUpdateCampaign(
    String campaignId,
    Map<String, dynamic> payload,
  ) async {
    await _client
        .from('election_campaigns')
        .update(payload)
        .eq('id', campaignId);
  }

  Future<void> adminDeleteCampaign(String campaignId) async {
    await _client.from('election_campaigns').delete().eq('id', campaignId);
  }

  Future<String> adminDuplicateCampaign({
    required String campaignId,
    required String title,
    required String slug,
    int? electionYear,
  }) async {
    final raw = await _client.rpc(
      'duplicate_election_campaign',
      params: {
        'p_campaign_id': campaignId,
        'p_new_title': title,
        'p_new_slug': slug,
        'p_new_year': electionYear,
      },
    );
    return raw.toString();
  }

  Future<List<Map<String, dynamic>>> adminListPublications(
    String campaignId,
  ) async {
    final raw = await _client
        .from('election_publications')
        .select()
        .eq('campaign_id', campaignId)
        .order('is_featured', ascending: false)
        .order('sort_order')
        .order('created_at', ascending: false);
    final rows = List<Map<String, dynamic>>.from(raw);

    for (final row in rows) {
      await _hydrateMediaUrls(row);
    }

    return rows;
  }

  Future<void> adminCreatePublication(Map<String, dynamic> payload) async {
    await _client.from('election_publications').insert(payload);
  }

  Future<void> adminUpdatePublication(
    String publicationId,
    Map<String, dynamic> payload,
  ) async {
    await _client
        .from('election_publications')
        .update(payload)
        .eq('id', publicationId);
  }

  Future<void> adminDeletePublication(String publicationId) async {
    await _client
        .from('election_publications')
        .delete()
        .eq('id', publicationId);
  }

  Future<void> adminReorderPublications(
    List<Map<String, dynamic>> publications,
  ) async {
    for (var i = 0; i < publications.length; i++) {
      await adminUpdatePublication(publications[i]['id'].toString(), {
        'sort_order': (i + 1) * 10,
      });
    }
  }

  Future<List<Map<String, dynamic>>> adminListSections(
    String campaignId,
  ) async {
    final raw = await _client
        .from('election_sections')
        .select()
        .eq('campaign_id', campaignId)
        .order('sort_order')
        .order('created_at');
    return List<Map<String, dynamic>>.from(raw);
  }

  Future<void> adminCreateSection(Map<String, dynamic> payload) async {
    await _client.from('election_sections').insert(payload);
  }

  Future<void> adminUpdateSection(
    String sectionId,
    Map<String, dynamic> payload,
  ) async {
    await _client.from('election_sections').update(payload).eq('id', sectionId);
  }

  Future<void> adminDeleteSection(String sectionId) async {
    await _client.from('election_sections').delete().eq('id', sectionId);
  }

  Future<void> adminReorderSections(List<Map<String, dynamic>> sections) async {
    for (var i = 0; i < sections.length; i++) {
      await adminUpdateSection(sections[i]['id'].toString(), {
        'sort_order': (i + 1) * 10,
      });
    }
  }

  Future<List<Map<String, dynamic>>> adminListItems(String sectionId) async {
    final raw = await _client
        .from('election_content_items')
        .select()
        .eq('section_id', sectionId)
        .order('sort_order')
        .order('created_at');
    return List<Map<String, dynamic>>.from(raw);
  }

  Future<void> adminCreateItem(Map<String, dynamic> payload) async {
    await _client.from('election_content_items').insert(payload);
  }

  Future<void> adminUpdateItem(
    String itemId,
    Map<String, dynamic> payload,
  ) async {
    await _client
        .from('election_content_items')
        .update(payload)
        .eq('id', itemId);
  }

  Future<void> adminDeleteItem(String itemId) async {
    await _client.from('election_content_items').delete().eq('id', itemId);
  }

  Future<void> adminReorderItems(List<Map<String, dynamic>> items) async {
    for (var i = 0; i < items.length; i++) {
      await adminUpdateItem(items[i]['id'].toString(), {
        'sort_order': (i + 1) * 10,
      });
    }
  }

  Future<List<Map<String, dynamic>>> adminListCandidates(
    String campaignId,
  ) async {
    final raw = await _client
        .from('election_candidates')
        .select()
        .eq('campaign_id', campaignId)
        .order('sort_order')
        .order('list_position')
        .order('last_name');
    final rows = List<Map<String, dynamic>>.from(raw);

    for (final row in rows) {
      await _hydrateMediaUrls(row);
    }

    return rows;
  }

  Future<void> adminCreateCandidate(Map<String, dynamic> payload) async {
    await _client.from('election_candidates').insert(payload);
  }

  Future<void> adminUpdateCandidate(
    String candidateId,
    Map<String, dynamic> payload,
  ) async {
    await _client
        .from('election_candidates')
        .update(payload)
        .eq('id', candidateId);
  }

  Future<void> adminDeleteCandidate(String candidateId) async {
    await _client.from('election_candidates').delete().eq('id', candidateId);
  }

  Future<void> adminReorderCandidates(
    List<Map<String, dynamic>> candidates,
  ) async {
    for (var i = 0; i < candidates.length; i++) {
      await adminUpdateCandidate(candidates[i]['id'].toString(), {
        'sort_order': (i + 1) * 10,
      });
    }
  }

  Future<({String path, String url})> uploadCampaignFile({
    required String campaignId,
    required String category,
    required String fileName,
    required Uint8List bytes,
    required String contentType,
  }) async {
    final safeName = _safeFileName(fileName);
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final path = 'campaigns/$campaignId/$category/${stamp}_$safeName';

    await _client.storage
        .from(_bucket)
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: contentType, upsert: false),
        );

    final url = await _client.storage
        .from(_bucket)
        .createSignedUrl(path, 60 * 60);
    return (path: path, url: url);
  }

  Future<void> deleteCampaignFile(String? storagePath) async {
    final path = storagePath?.trim() ?? '';
    if (path.isEmpty) return;
    await _client.storage.from(_bucket).remove([path]);
  }

  String _safeFileName(String input) {
    final trimmed = input.trim().replaceAll(' ', '_');
    final safe = trimmed.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '');
    return safe.isEmpty ? 'fichier' : safe;
  }
}
