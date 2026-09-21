class PodcastAiStatuses {
  static const draft = 'draft';
  static const uploading = 'uploading';
  static const uploaded = 'uploaded';
  static const scriptReady = 'script_ready';
  static const generatingAudio = 'generating_audio';
  static const ready = 'ready';
  static const published = 'published';
  static const failed = 'failed';

  static const values = <String>[
    draft,
    uploading,
    uploaded,
    scriptReady,
    generatingAudio,
    ready,
    published,
    failed,
  ];

  static String label(String status) => switch (status) {
    draft => 'Brouillon',
    uploading => 'Import en cours',
    uploaded => 'PDF importé',
    scriptReady => 'Script prêt',
    generatingAudio => 'Audio en cours',
    ready => 'Prêt à publier',
    published => 'Publié',
    failed => 'Échec',
    _ => status,
  };
}

class PodcastAiVoiceOption {
  const PodcastAiVoiceOption({
    required this.id,
    required this.displayName,
    required this.cse,
    required this.provider,
    required this.providerStatus,
    required this.isActive,
    this.providerVoiceId,
  });

  final String id;
  final String displayName;
  final String cse;
  final String provider;
  final String providerStatus;
  final bool isActive;
  final String? providerVoiceId;

  bool get isReady =>
      isActive &&
      providerStatus == 'ready' &&
      (providerVoiceId ?? '').trim().isNotEmpty;

  factory PodcastAiVoiceOption.fromJson(Map<String, dynamic> json) =>
      PodcastAiVoiceOption(
        id: (json['id'] ?? '').toString().trim(),
        displayName: (json['display_name'] ?? '').toString().trim(),
        cse: (json['cse'] ?? '').toString().trim(),
        provider: (json['provider'] ?? '').toString().trim(),
        providerStatus: (json['provider_status'] ?? '').toString().trim(),
        isActive: json['is_active'] == true,
        providerVoiceId: json['provider_voice_id']?.toString(),
      );
}

class PodcastSpeakerVoiceConfig {
  const PodcastSpeakerVoiceConfig({
    required this.speaker,
    required this.source,
    required this.provider,
    required this.voice,
    required this.customVoiceId,
    required this.label,
  });

  const PodcastSpeakerVoiceConfig.standard({
    required this.speaker,
    required String standardVoice,
  }) : source = 'standard',
       provider = 'gemini',
       voice = standardVoice,
       customVoiceId = null,
       label = standardVoice;

  factory PodcastSpeakerVoiceConfig.custom({
    required String speaker,
    required PodcastAiVoiceOption option,
  }) => PodcastSpeakerVoiceConfig(
    speaker: speaker,
    source: 'custom',
    provider: option.provider,
    voice: null,
    customVoiceId: option.id,
    label: option.displayName,
  );

  final String speaker;
  final String source;
  final String provider;
  final String? voice;
  final String? customVoiceId;
  final String label;

  bool get isCustom => source == 'custom';

  Map<String, dynamic> toJson() => <String, dynamic>{
    'speaker': speaker,
    'source': source,
    'provider': provider,
    'voice': voice,
    'custom_voice_id': customVoiceId,
    'label': label,
  };

  factory PodcastSpeakerVoiceConfig.fromJson(
    dynamic value, {
    required String speaker,
    required String defaultVoice,
  }) {
    final map = value is Map
        ? Map<String, dynamic>.from(value)
        : <String, dynamic>{};
    if ((map['source'] ?? 'standard').toString() != 'custom') {
      return PodcastSpeakerVoiceConfig.standard(
        speaker: speaker,
        standardVoice: defaultVoice,
      );
    }
    final id = (map['custom_voice_id'] ?? '').toString().trim();
    if (id.isEmpty) {
      return PodcastSpeakerVoiceConfig.standard(
        speaker: speaker,
        standardVoice: defaultVoice,
      );
    }
    return PodcastSpeakerVoiceConfig(
      speaker: speaker,
      source: 'custom',
      provider: (map['provider'] ?? '').toString(),
      voice: null,
      customVoiceId: id,
      label: (map['label'] ?? 'Voix personnalisée').toString().trim(),
    );
  }
}

class PodcastVoiceConfig {
  const PodcastVoiceConfig({
    required this.version,
    required this.speaker1,
    required this.speaker2,
  });

  const PodcastVoiceConfig.standard()
    : version = 1,
      speaker1 = const PodcastSpeakerVoiceConfig.standard(
        speaker: 'Camille',
        standardVoice: 'Kore',
      ),
      speaker2 = const PodcastSpeakerVoiceConfig.standard(
        speaker: 'Alex',
        standardVoice: 'Puck',
      );

  final int version;
  final PodcastSpeakerVoiceConfig speaker1;
  final PodcastSpeakerVoiceConfig speaker2;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'version': version,
    'speaker_1': speaker1.toJson(),
    'speaker_2': speaker2.toJson(),
  };

  bool sameSelectionAs(PodcastVoiceConfig other) =>
      speaker1.source == other.speaker1.source &&
      speaker1.provider == other.speaker1.provider &&
      speaker1.voice == other.speaker1.voice &&
      speaker1.customVoiceId == other.speaker1.customVoiceId &&
      speaker2.source == other.speaker2.source &&
      speaker2.provider == other.speaker2.provider &&
      speaker2.voice == other.speaker2.voice &&
      speaker2.customVoiceId == other.speaker2.customVoiceId;

  String displayScript(String canonical) => _mapSpeakerLabels(
    canonical,
    fromSpeaker1: 'Camille',
    toSpeaker1: speaker1.isCustom ? speaker1.label : 'Camille',
    fromSpeaker2: 'Alex',
    toSpeaker2: speaker2.isCustom ? speaker2.label : 'Alex',
  );

  String canonicalScript(String displayed) => _mapSpeakerLabels(
    displayed,
    fromSpeaker1: speaker1.isCustom ? speaker1.label : 'Camille',
    toSpeaker1: 'Camille',
    fromSpeaker2: speaker2.isCustom ? speaker2.label : 'Alex',
    toSpeaker2: 'Alex',
  );

  static String _mapSpeakerLabels(
    String script, {
    required String fromSpeaker1,
    required String toSpeaker1,
    required String fromSpeaker2,
    required String toSpeaker2,
  }) {
    final replacements = <String, String>{
      fromSpeaker1: toSpeaker1,
      fromSpeaker2: toSpeaker2,
    };
    final alternatives =
        replacements.keys.map(RegExp.escape).toList(growable: false)
          ..sort((a, b) => b.length.compareTo(a.length));
    final markerPattern = RegExp('(${alternatives.join('|')})\\s*:');
    final matches = markerPattern
        .allMatches(script)
        .where((match) {
          if (match.start == 0) return true;
          final previous = script.substring(match.start - 1, match.start);
          return !RegExp(r'[A-Za-zÀ-ÖØ-öø-ÿ0-9_]').hasMatch(previous);
        })
        .toList(growable: false);

    if (matches.isEmpty) return script;

    final sections = <String>[];
    final preamble = script.substring(0, matches.first.start).trim();
    if (preamble.isNotEmpty) sections.add(preamble);

    for (var index = 0; index < matches.length; index++) {
      final match = matches[index];
      final nextStart = index + 1 < matches.length
          ? matches[index + 1].start
          : script.length;
      final label = match.group(1)!;
      final speech = _replaceIdentityTokens(
        script.substring(match.end, nextStart).trim(),
        replacements,
      );
      final mappedLabel = replacements[label]!;
      sections.add(speech.isEmpty ? '$mappedLabel:' : '$mappedLabel: $speech');
    }

    return sections.join('\n\n');
  }

  /// Replaces generic dialogue identities only as complete lexical tokens.
  /// Speaker markers are handled separately so Camille/Alex remain the stable
  /// canonical routing keys when the displayed script is saved.
  static String _replaceIdentityTokens(
    String text,
    Map<String, String> replacements,
  ) {
    final alternatives =
        replacements.keys.map(RegExp.escape).toList(growable: false)
          ..sort((a, b) => b.length.compareTo(a.length));
    final tokenPattern = RegExp(
      '(^|[^A-Za-zÀ-ÖØ-öø-ÿ0-9_])(${alternatives.join('|')})'
      r'(?=$|[^A-Za-zÀ-ÖØ-öø-ÿ0-9_])',
    );
    return text.replaceAllMapped(
      tokenPattern,
      (match) => '${match.group(1)}${replacements[match.group(2)]}',
    );
  }

  factory PodcastVoiceConfig.fromJson(dynamic value) {
    final map = value is Map
        ? Map<String, dynamic>.from(value)
        : <String, dynamic>{};
    return PodcastVoiceConfig(
      version: int.tryParse('${map['version'] ?? 1}') ?? 1,
      speaker1: PodcastSpeakerVoiceConfig.fromJson(
        map['speaker_1'],
        speaker: 'Camille',
        defaultVoice: 'Kore',
      ),
      speaker2: PodcastSpeakerVoiceConfig.fromJson(
        map['speaker_2'],
        speaker: 'Alex',
        defaultVoice: 'Puck',
      ),
    );
  }
}

class PodcastAiJob {
  const PodcastAiJob({
    required this.id,
    required this.createdBy,
    required this.title,
    required this.cse,
    required this.requestedMinutes,
    required this.voiceConfig,
    required this.status,
    required this.createdAt,
    this.updatedAt,
    this.sourcePdfName,
    this.sourcePdfPath,
    this.script,
    this.audioPath,
    this.audioUrl,
    this.errorMessage,
    this.publishedPodcastId,
  });

  final String id;
  final String createdBy;
  final String title;
  final String cse;
  final int requestedMinutes;
  final PodcastVoiceConfig voiceConfig;
  final String status;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? sourcePdfName;
  final String? sourcePdfPath;
  final String? script;
  final String? audioPath;
  final String? audioUrl;
  final String? errorMessage;
  final String? publishedPodcastId;

  bool get hasAudio =>
      (status == PodcastAiStatuses.ready || isPublished) &&
      ((audioPath ?? '').isNotEmpty || (audioUrl ?? '').isNotEmpty);
  bool get isPublished => status == PodcastAiStatuses.published;
  bool get canDelete =>
      !isPublished && status != PodcastAiStatuses.generatingAudio;

  factory PodcastAiJob.fromJson(Map<String, dynamic> json) => PodcastAiJob(
    id: (json['id'] ?? '').toString(),
    createdBy: (json['created_by'] ?? '').toString(),
    title: (json['title'] ?? 'Podcast CFDT').toString(),
    cse: (json['cse'] ?? '').toString(),
    requestedMinutes: int.tryParse('${json['requested_minutes'] ?? 5}') ?? 5,
    voiceConfig: PodcastVoiceConfig.fromJson(json['voice_config']),
    status: (json['status'] ?? PodcastAiStatuses.draft).toString(),
    createdAt:
        DateTime.tryParse('${json['created_at'] ?? ''}') ?? DateTime.now(),
    updatedAt: DateTime.tryParse('${json['updated_at'] ?? ''}'),
    sourcePdfName: json['source_pdf_name']?.toString(),
    sourcePdfPath: json['source_pdf_path']?.toString(),
    script: json['script']?.toString(),
    audioPath: json['audio_path']?.toString(),
    audioUrl: json['audio_url']?.toString(),
    errorMessage: json['error_message']?.toString(),
    publishedPodcastId: json['published_podcast_id']?.toString(),
  );
}
