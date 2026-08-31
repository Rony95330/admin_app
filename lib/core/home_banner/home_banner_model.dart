class HomeBanner {
  const HomeBanner({
    required this.id,
    required this.title,
    required this.style,
    required this.iconName,
    required this.actionType,
    required this.audiences,
    required this.platforms,
    required this.isActive,
    required this.isDismissible,
    required this.sortOrder,
    required this.createdAt,
    required this.updatedAt,
    this.message,
    this.actionValue,
    this.actionLabel,
    this.startsAt,
    this.endsAt,
    this.imageStoragePath,
    this.archivedAt,
  });

  final String id;
  final String title;
  final String? message;
  final String style;
  final String iconName;
  final String actionType;
  final String? actionValue;
  final String? actionLabel;
  final List<String> audiences;
  final List<String> platforms;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final bool isActive;
  final bool isDismissible;
  final int sortOrder;
  final String? imageStoragePath;
  final DateTime? archivedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory HomeBanner.fromMap(Map<String, dynamic> map) {
    DateTime? nullableDate(dynamic value) =>
        value == null ? null : DateTime.tryParse(value.toString())?.toLocal();

    DateTime requiredDate(dynamic value) =>
        DateTime.tryParse(value?.toString() ?? '')?.toLocal() ?? DateTime.now();

    return HomeBanner(
      id: map['id'] as String,
      title: (map['title'] as String?)?.trim() ?? '',
      message: (map['message'] as String?)?.trim(),
      style: (map['style'] as String?) ?? 'info',
      iconName: (map['icon_name'] as String?) ?? 'campaign',
      actionType: (map['action_type'] as String?) ?? 'none',
      actionValue: (map['action_value'] as String?)?.trim(),
      actionLabel: (map['action_label'] as String?)?.trim(),
      audiences: List<String>.from(map['audiences'] as List? ?? const ['all']),
      platforms: List<String>.from(map['platforms'] as List? ?? const ['all']),
      startsAt: nullableDate(map['starts_at']),
      endsAt: nullableDate(map['ends_at']),
      isActive: map['is_active'] as bool? ?? false,
      isDismissible: map['is_dismissible'] as bool? ?? true,
      sortOrder: (map['sort_order'] as num?)?.toInt() ?? 100,
      imageStoragePath: map['image_storage_path'] as String?,
      archivedAt: nullableDate(map['archived_at']),
      createdAt: requiredDate(map['created_at']),
      updatedAt: requiredDate(map['updated_at']),
    );
  }

  Map<String, dynamic> toMap({bool includeId = true}) {
    return <String, dynamic>{
      if (includeId) 'id': id,
      'title': title.trim(),
      'message': _nullIfBlank(message),
      'style': style,
      'icon_name': iconName,
      'action_type': actionType,
      'action_value': actionType == 'none' ? null : _nullIfBlank(actionValue),
      'action_label': _nullIfBlank(actionLabel),
      'audiences': audiences.isEmpty ? const ['all'] : audiences,
      'platforms': platforms.isEmpty ? const ['all'] : platforms,
      'starts_at': startsAt?.toUtc().toIso8601String(),
      'ends_at': endsAt?.toUtc().toIso8601String(),
      'is_active': isActive,
      'is_dismissible': isDismissible,
      'sort_order': sortOrder,
      'image_storage_path': _nullIfBlank(imageStoragePath),
      'archived_at': archivedAt?.toUtc().toIso8601String(),
    };
  }

  bool isVisibleFor({
    required String platform,
    required Set<String> userAudiences,
    DateTime? now,
  }) {
    final current = now ?? DateTime.now();
    if (!isActive || archivedAt != null) return false;
    if (startsAt != null && current.isBefore(startsAt!)) return false;
    if (endsAt != null && !current.isBefore(endsAt!)) return false;

    final platformOk = platforms.contains('all') || platforms.contains(platform);
    if (!platformOk) return false;

    if (audiences.contains('all')) return true;
    return audiences.any(userAudiences.contains);
  }

  static String? _nullIfBlank(String? value) {
    final v = value?.trim();
    return v == null || v.isEmpty ? null : v;
  }
}
