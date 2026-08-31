import 'package:supabase_flutter/supabase_flutter.dart';

class AdminDataException implements Exception {
  const AdminDataException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Accès aux données sensibles de la console via la fonction serveur
/// `admin-data`. La clé service_role reste ainsi exclusivement côté Supabase.
class AdminDataService {
  AdminDataService({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<List<Map<String, dynamic>>> list(String resource) async {
    final data = await _invoke(<String, dynamic>{
      'action': 'list',
      'resource': resource,
    });

    final rawRows = data['rows'];
    if (rawRows is! List) return const <Map<String, dynamic>>[];
    return rawRows
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
  }

  Future<Map<String, dynamic>> save({
    required String resource,
    required Map<String, dynamic> row,
    required bool isNew,
  }) async {
    final data = await _invoke(<String, dynamic>{
      'action': 'save',
      'resource': resource,
      'is_new': isNew,
      'row': row,
    });
    final rawRow = data['row'];
    if (rawRow is! Map) return Map<String, dynamic>.from(row);
    return Map<String, dynamic>.from(rawRow);
  }

  Future<void> delete({
    required String resource,
    required dynamic primaryValue,
  }) async {
    await _invoke(<String, dynamic>{
      'action': 'delete',
      'resource': resource,
      'primary_value': primaryValue,
    });
  }

  Future<Map<String, dynamic>> sendNotification(String outboxId) async {
    final data = await _invoke(<String, dynamic>{
      'action': 'send_notification',
      'outbox_id': outboxId,
    });
    final rawDelivery = data['delivery'];
    if (rawDelivery is! Map) return const <String, dynamic>{};
    return Map<String, dynamic>.from(rawDelivery);
  }

  Future<Map<String, dynamic>> _invoke(Map<String, dynamic> body) async {
    final response = await _client.functions.invoke('admin-data', body: body);

    final raw = response.data;
    if (raw is! Map) {
      throw const AdminDataException(
        'Réponse serveur invalide. Vérifiez le déploiement de admin-data.',
      );
    }

    final data = Map<String, dynamic>.from(raw);
    if (response.status < 200 || response.status >= 300 || data['ok'] != true) {
      throw AdminDataException(
        (data['message'] ?? 'Le service d’administration est indisponible.')
            .toString(),
      );
    }
    return data;
  }
}
