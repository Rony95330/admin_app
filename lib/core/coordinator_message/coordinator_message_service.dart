import 'package:supabase_flutter/supabase_flutter.dart';

import 'coordinator_message_model.dart';

/// Service admin : pas de cache SharedPreferences, uniquement les opérations
/// nécessaires à la console d'administration.
class CoordinatorMessageService {
  CoordinatorMessageService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;
  static const String _table = 'coordinator_messages';

  Future<List<CoordinatorMessage>> fetchAllForAdmin() async {
    final rows = await _client
        .from(_table)
        .select()
        .order('archived_at', ascending: true)
        .order('cse')
        .order('published_from', ascending: false);
    return (rows as List)
        .map((row) => CoordinatorMessage.fromMap(
              Map<String, dynamic>.from(row as Map),
            ))
        .toList(growable: false);
  }

  Future<List<String>> fetchCseChoices() async {
    final values = <String>{};
    try {
      final rows = await _client.from('liste_cse').select('cse').order('cse');
      for (final row in rows as List) {
        final cse = (row as Map<String, dynamic>)['cse']?.toString().trim();
        if (cse != null && cse.isNotEmpty) values.add(cse);
      }
    } catch (_) {}

    if (values.isEmpty) {
      final rows = await _client.from('members').select('cse').order('cse');
      for (final row in rows as List) {
        final cse = (row as Map<String, dynamic>)['cse']?.toString().trim();
        if (cse != null && cse.isNotEmpty) values.add(cse);
      }
    }

    final result = values.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return result;
  }

  Future<List<CoordinatorMemberChoice>> fetchMembers(String cse) async {
    final normalizedCse = cse.trim();
    if (normalizedCse.isEmpty) return const <CoordinatorMemberChoice>[];
    final rows = await _client
        .from('members')
        .select('id,name,role,cse,photo_url,order_index')
        .eq('cse', normalizedCse)
        .order('order_index', ascending: true, nullsFirst: false)
        .order('name');
    return (rows as List)
        .map((row) => CoordinatorMemberChoice.fromMap(
              Map<String, dynamic>.from(row as Map),
            ))
        .where((member) => member.id > 0 && member.name.isNotEmpty)
        .toList(growable: false);
  }

  Future<CoordinatorMessage> create(Map<String, dynamic> values) async {
    final payload = Map<String, dynamic>.from(values)
      ..remove('id')
      ..['created_by'] = _client.auth.currentUser?.id;
    final row = await _client.from(_table).insert(payload).select().single();
    return CoordinatorMessage.fromMap(Map<String, dynamic>.from(row));
  }

  Future<CoordinatorMessage> update(
    String id,
    Map<String, dynamic> values,
  ) async {
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
    return CoordinatorMessage.fromMap(Map<String, dynamic>.from(row));
  }

  Future<void> setActive(CoordinatorMessage message, bool active) async {
    await _client.from(_table).update({'is_active': active}).eq('id', message.id);
  }

  Future<void> delete(String id) async {
    await _client.from(_table).delete().eq('id', id);
  }
}
