class PodcastVoice {
  const PodcastVoice({
    required this.id,
    required this.displayName,
    required this.cse,
    required this.samplePath,
    required this.consentRecordingPath,
    required this.consentAccepted,
    required this.providerStatus,
    required this.isActive,
    required this.createdAt,
    this.firstName,
    this.lastName,
    this.roleLabel,
    this.sampleDurationSeconds,
    this.consentAt,
    this.provider,
    this.providerVoiceId,
    this.providerConsentId,
  });

  final String id;
  final String displayName;
  final String? firstName;
  final String? lastName;
  final String cse;
  final String? roleLabel;
  final String samplePath;
  final String consentRecordingPath;
  final int? sampleDurationSeconds;
  final bool consentAccepted;
  final DateTime? consentAt;
  final String? provider;
  final String? providerVoiceId;
  final String? providerConsentId;
  final String providerStatus;
  final bool isActive;
  final DateTime createdAt;

  factory PodcastVoice.fromJson(Map<String, dynamic> json) {
    return PodcastVoice(
      id: (json['id'] ?? '').toString(),
      displayName: (json['display_name'] ?? '').toString(),
      firstName: _nullableText(json['first_name']),
      lastName: _nullableText(json['last_name']),
      cse: (json['cse'] ?? '').toString(),
      roleLabel: _nullableText(json['role_label']),
      samplePath: (json['sample_path'] ?? '').toString(),
      consentRecordingPath: (json['consent_recording_path'] ?? '').toString(),
      sampleDurationSeconds: _nullableInt(json['sample_duration_seconds']),
      consentAccepted: json['consent_accepted'] == true,
      consentAt: _nullableDate(json['consent_at']),
      provider: _nullableText(json['provider']),
      providerVoiceId: _nullableText(json['provider_voice_id']),
      providerConsentId: _nullableText(json['provider_consent_id']),
      providerStatus: (json['provider_status'] ?? 'not_registered').toString(),
      isActive: json['is_active'] == true,
      createdAt: _nullableDate(json['created_at']) ?? DateTime.now(),
    );
  }

  String get personLabel {
    final parts = <String>[
      if ((firstName ?? '').trim().isNotEmpty) firstName!.trim(),
      if ((lastName ?? '').trim().isNotEmpty) lastName!.trim(),
    ];
    return parts.isEmpty ? displayName : parts.join(' ');
  }

  String get providerStatusLabel {
    switch (providerStatus) {
      case 'pending':
        return 'Enregistrement fournisseur en cours';
      case 'ready':
        return 'Voix prête';
      case 'failed':
        return 'Erreur fournisseur';
      default:
        return 'Enregistrée localement';
    }
  }

  static String? _nullableText(dynamic value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? null : text;
  }

  static int? _nullableInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    return int.tryParse(value.toString());
  }

  static DateTime? _nullableDate(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }
}
