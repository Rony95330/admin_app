class CoordinatorMessage {
  const CoordinatorMessage({
    required this.id,
    required this.cse,
    required this.coordinatorName,
    required this.body,
    required this.isActive,
    required this.sortOrder,
    required this.createdAt,
    required this.updatedAt,
    this.coordinatorMemberId,
    this.coordinatorRole,
    this.coordinatorPhotoUrl,
    this.headline,
    this.publishedFrom,
    this.publishedUntil,
    this.archivedAt,
  });

  final String id;
  final String cse;
  final int? coordinatorMemberId;
  final String coordinatorName;
  final String? coordinatorRole;
  final String? coordinatorPhotoUrl;
  final String? headline;
  final String body;
  final DateTime? publishedFrom;
  final DateTime? publishedUntil;
  final bool isActive;
  final int sortOrder;
  final DateTime? archivedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  String get initials {
    final parts = coordinatorName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return 'CFDT';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  String get excerpt {
    final normalized = body.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.length <= 150) return normalized;
    return '${normalized.substring(0, 147).trimRight()}…';
  }

  bool isVisibleAt([DateTime? now]) {
    final current = now ?? DateTime.now();
    if (!isActive || archivedAt != null) return false;
    if (publishedFrom != null && current.isBefore(publishedFrom!)) return false;
    if (publishedUntil != null && !current.isBefore(publishedUntil!)) {
      return false;
    }
    return true;
  }

  factory CoordinatorMessage.fromMap(Map<String, dynamic> map) {
    DateTime? nullableDate(dynamic value) =>
        value == null ? null : DateTime.tryParse(value.toString())?.toLocal();

    DateTime requiredDate(dynamic value) =>
        DateTime.tryParse(value?.toString() ?? '')?.toLocal() ?? DateTime.now();

    return CoordinatorMessage(
      id: map['id']?.toString() ?? '',
      cse: map['cse']?.toString().trim() ?? '',
      coordinatorMemberId:
          int.tryParse(map['coordinator_member_id']?.toString() ?? ''),
      coordinatorName: map['coordinator_name']?.toString().trim() ?? '',
      coordinatorRole: _nullableText(map['coordinator_role']),
      coordinatorPhotoUrl: _nullableText(map['coordinator_photo_url']),
      headline: _nullableText(map['headline']),
      body: map['body']?.toString().trim() ?? '',
      publishedFrom: nullableDate(map['published_from']),
      publishedUntil: nullableDate(map['published_until']),
      isActive: map['is_active'] as bool? ?? false,
      sortOrder: (map['sort_order'] as num?)?.toInt() ?? 100,
      archivedAt: nullableDate(map['archived_at']),
      createdAt: requiredDate(map['created_at']),
      updatedAt: requiredDate(map['updated_at']),
    );
  }

  Map<String, dynamic> toMap({
    bool includeId = true,
    bool includeSystemFields = false,
  }) {
    return <String, dynamic>{
      if (includeId) 'id': id,
      'cse': cse.trim(),
      'coordinator_member_id': coordinatorMemberId,
      'coordinator_name': coordinatorName.trim(),
      'coordinator_role': _nullableText(coordinatorRole),
      'coordinator_photo_url': _nullableText(coordinatorPhotoUrl),
      'headline': _nullableText(headline),
      'body': body.trim(),
      'published_from': publishedFrom?.toUtc().toIso8601String(),
      'published_until': publishedUntil?.toUtc().toIso8601String(),
      'is_active': isActive,
      'sort_order': sortOrder,
      'archived_at': archivedAt?.toUtc().toIso8601String(),
      if (includeSystemFields)
        'created_at': createdAt.toUtc().toIso8601String(),
      if (includeSystemFields)
        'updated_at': updatedAt.toUtc().toIso8601String(),
    };
  }

  static String? _nullableText(dynamic value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }
}

class CoordinatorMemberChoice {
  const CoordinatorMemberChoice({
    required this.id,
    required this.name,
    required this.role,
    required this.cse,
    required this.photoUrl,
  });

  final int id;
  final String name;
  final String role;
  final String cse;
  final String photoUrl;

  factory CoordinatorMemberChoice.fromMap(Map<String, dynamic> map) {
    return CoordinatorMemberChoice(
      id: int.tryParse(map['id']?.toString() ?? '') ?? 0,
      name: map['name']?.toString().trim() ?? '',
      role: map['role']?.toString().trim() ?? '',
      cse: map['cse']?.toString().trim() ?? '',
      photoUrl: map['photo_url']?.toString().trim() ?? '',
    );
  }
}
