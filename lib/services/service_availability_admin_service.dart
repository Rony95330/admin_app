import 'package:supabase_flutter/supabase_flutter.dart';

class ServiceAvailabilityStatus {
  const ServiceAvailabilityStatus({
    required this.target,
    required this.mode,
    required this.updatedAt,
    this.publicMessage,
  });

  final String target;
  final String mode;
  final String? publicMessage;
  final DateTime? updatedAt;

  bool get isActive => mode == 'active';

  factory ServiceAvailabilityStatus.fromMap(Map<String, dynamic> map) {
    return ServiceAvailabilityStatus(
      target: map['target']?.toString() ?? '',
      mode: map['mode']?.toString() ?? 'active',
      publicMessage: map['public_message']?.toString(),
      updatedAt: DateTime.tryParse(map['updated_at']?.toString() ?? ''),
    );
  }
}

class ServiceAvailabilityAuditItem {
  const ServiceAvailabilityAuditItem({
    required this.id,
    required this.target,
    required this.oldMode,
    required this.newMode,
    required this.changedAt,
    this.oldMessage,
    this.newMessage,
  });

  final int id;
  final String target;
  final String? oldMode;
  final String? newMode;
  final String? oldMessage;
  final String? newMessage;
  final DateTime? changedAt;

  factory ServiceAvailabilityAuditItem.fromMap(Map<String, dynamic> map) {
    return ServiceAvailabilityAuditItem(
      id: (map['id'] as num?)?.toInt() ?? 0,
      target: map['target']?.toString() ?? '',
      oldMode: map['old_mode']?.toString(),
      newMode: map['new_mode']?.toString(),
      oldMessage: map['old_message']?.toString(),
      newMessage: map['new_message']?.toString(),
      changedAt: DateTime.tryParse(map['changed_at']?.toString() ?? ''),
    );
  }
}

class ServiceAvailabilityAdminService {
  ServiceAvailabilityAdminService({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<bool> isSuperuser() async {
    final result = await _client.rpc('security_current_role');
    return result?.toString() == 'supuser';
  }

  Future<ServiceAvailabilityStatus> getStatus(String target) async {
    final dynamic response = await _client.rpc(
      'get_app_runtime_control',
      params: <String, dynamic>{'p_target': target},
    );

    final row = _firstMap(response);

    if (row == null) {
      throw StateError('Statut introuvable pour $target.');
    }

    return ServiceAvailabilityStatus.fromMap(<String, dynamic>{
      ...row,
      'target': target,
    });
  }

  Future<List<ServiceAvailabilityStatus>> getAllStatuses() async {
    final statuses = await Future.wait<ServiceAvailabilityStatus>(
      <Future<ServiceAvailabilityStatus>>[
        getStatus('mobile'),
        getStatus('admin'),
      ],
    );

    return statuses;
  }

  Future<void> setStatus({
    required String target,
    required String mode,
    String? publicMessage,
  }) async {
    if (target == 'admin' && mode != 'active') {
      throw StateError('La console admin ne peut pas se désactiver elle-même.');
    }

    await _client.rpc(
      'set_app_runtime_control',
      params: <String, dynamic>{
        'p_target': target,
        'p_mode': mode,
        'p_public_message': publicMessage,
      },
    );
  }

  Future<List<ServiceAvailabilityAuditItem>> getAudit({int limit = 30}) async {
    final dynamic response = await _client.rpc(
      'get_app_runtime_control_audit',
      params: <String, dynamic>{'p_limit': limit},
    );

    if (response is! List) {
      return const <ServiceAvailabilityAuditItem>[];
    }

    return response
        .whereType<Map>()
        .map(
          (Map row) => ServiceAvailabilityAuditItem.fromMap(
            Map<String, dynamic>.from(row),
          ),
        )
        .toList();
  }

  Map<String, dynamic>? _firstMap(dynamic response) {
    if (response is List && response.isNotEmpty && response.first is Map) {
      return Map<String, dynamic>.from(response.first as Map);
    }

    if (response is Map) {
      return Map<String, dynamic>.from(response);
    }

    return null;
  }
}
