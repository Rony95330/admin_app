import 'dart:math';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/podcast_voice.dart';

class PodcastVoiceAccess {
  const PodcastVoiceAccess({required this.role, required this.cse});

  final String role;
  final String cse;

  bool get isSuperuser => role == 'supuser';
  bool get isAdmin => role == 'adm' || isSuperuser;
}

class PodcastVoiceService {
  PodcastVoiceService({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  static const String storageBucket = 'podcast_voice_samples';

  static const List<String> canonicalCses = <String>[
    'CENTRAL',
    'CSE AIR FRANCE CARGO',
    'CSE EXPLOITATION AERIENNE',
    'CSE EXPLOITATION COURT COURRIER',
    'CSE EXPLOITATION HUB',
    'CSE INDUSTRIEL',
    'CSE PILOTAGE ECONOMIQUE',
    "CSE SYSTEMES D'INFORMATION",
  ];

  static const Map<String, String> _storageCseCodes = <String, String>{
    'CENTRAL': 'CENTRAL',
    'CSE AIR FRANCE CARGO': 'CARGO',
    'CSE EXPLOITATION AERIENNE': 'EA',
    'CSE EXPLOITATION COURT COURRIER': 'CC',
    'CSE EXPLOITATION HUB': 'HUB',
    'CSE INDUSTRIEL': 'DGI',
    'CSE PILOTAGE ECONOMIQUE': 'PILECO',
    "CSE SYSTEMES D'INFORMATION": 'SI',
  };

  final SupabaseClient _client;

  Future<PodcastVoiceAccess> loadAccess() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw const AuthException('Session expirée, reconnectez-vous.');
    }

    final raw = await _client.rpc('current_user_context');
    if (raw is! List || raw.isEmpty || raw.first is! Map) {
      throw const AuthException(
        'Contexte de sécurité administrateur introuvable.',
      );
    }

    final row = Map<String, dynamic>.from(raw.first as Map);
    final role = (row['role'] ?? '').toString().trim().toLowerCase();
    final cse = (row['cse'] ?? '').toString().trim();
    final access = PodcastVoiceAccess(role: role, cse: cse);
    if (!access.isAdmin) {
      throw const AuthException('Accès réservé aux administrateurs.');
    }
    return access;
  }

  Future<List<String>> allowedCses() async {
    final access = await loadAccess();
    if (access.isSuperuser) return canonicalCses;
    if (!canonicalCses.contains(access.cse)) {
      throw StateError('CSE administrateur non reconnu : ${access.cse}');
    }
    return <String>[access.cse];
  }

  Future<List<PodcastVoice>> listVoices({String? cse}) async {
    final dynamic response;
    if (cse == null || cse.trim().isEmpty) {
      response = await _client
          .from('podcast_voices')
          .select()
          .order('cse')
          .order('display_name');
    } else {
      response = await _client
          .from('podcast_voices')
          .select()
          .eq('cse', cse.trim())
          .order('display_name');
    }

    return (response as List<dynamic>)
        .map(
          (row) => PodcastVoice.fromJson(Map<String, dynamic>.from(row as Map)),
        )
        .toList(growable: false);
  }

  Future<PodcastVoice> createVoice({
    required String displayName,
    required String firstName,
    required String lastName,
    required String cse,
    required String roleLabel,
    required Uint8List sampleWav,
    required Duration sampleDuration,
    required Uint8List consentWav,
    required Duration consentDuration,
    required bool consentAccepted,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw const AuthException('Session expirée, reconnectez-vous.');
    }

    final normalizedCse = cse.trim();
    if (!canonicalCses.contains(normalizedCse)) {
      throw ArgumentError.value(cse, 'cse', 'CSE non reconnu.');
    }

    // Contrôle UX local ; la RLS reste l'autorité réelle côté serveur.
    final allowed = await allowedCses();
    if (!allowed.contains(normalizedCse)) {
      throw StateError("Vous n'êtes pas autorisé à gérer les voix de ce CSE.");
    }

    if (!consentAccepted) {
      throw StateError('Le consentement doit être accepté avant sauvegarde.');
    }
    if (sampleDuration < const Duration(seconds: 20)) {
      throw StateError(
        "L'échantillon de voix doit durer au moins 20 secondes.",
      );
    }
    if (sampleDuration > const Duration(seconds: 120)) {
      throw StateError("L'échantillon de voix ne doit pas dépasser 2 minutes.");
    }
    if (consentDuration < const Duration(seconds: 5)) {
      throw StateError(
        "L'enregistrement vocal du consentement doit durer au moins 5 secondes.",
      );
    }

    final storageCse = _storageCseCodes[normalizedCse];
    if (storageCse == null) {
      throw StateError('Code de stockage CSE introuvable.');
    }

    final id = _uuidV4();
    final basePath = '${user.id}/$storageCse/$id';
    final samplePath = '$basePath/sample.wav';
    final consentPath = '$basePath/consent.wav';
    final uploaded = <String>[];

    try {
      await _client.storage
          .from(storageBucket)
          .uploadBinary(
            samplePath,
            sampleWav,
            fileOptions: const FileOptions(
              contentType: 'audio/wav',
              cacheControl: '0',
              upsert: false,
            ),
          );
      uploaded.add(samplePath);

      await _client.storage
          .from(storageBucket)
          .uploadBinary(
            consentPath,
            consentWav,
            fileOptions: const FileOptions(
              contentType: 'audio/wav',
              cacheControl: '0',
              upsert: false,
            ),
          );
      uploaded.add(consentPath);

      // consent_at, consent_text_version, provider_status et is_active sont
      // imposés par PostgreSQL. Le client n'a pas de privilège d'écriture sur
      // ces colonnes sensibles.
      final row = await _client
          .from('podcast_voices')
          .insert({
            'id': id,
            'display_name': displayName.trim(),
            'first_name': _nullIfBlank(firstName),
            'last_name': _nullIfBlank(lastName),
            'cse': normalizedCse,
            'role_label': _nullIfBlank(roleLabel),
            'sample_path': samplePath,
            'sample_duration_seconds': sampleDuration.inSeconds,
            'consent_recording_path': consentPath,
            'created_by': user.id,
          })
          .select()
          .single();

      return PodcastVoice.fromJson(Map<String, dynamic>.from(row));
    } catch (_) {
      if (uploaded.isNotEmpty) {
        try {
          await _client.storage.from(storageBucket).remove(uploaded);
        } catch (_) {
          // Le bucket reste privé et CSE-scopé. Un éventuel objet orphelin
          // pourra être supprimé par un administrateur du même périmètre.
        }
      }
      rethrow;
    }
  }

  Future<PodcastVoice> setActive(PodcastVoice voice, bool active) async {
    final row = await _client
        .from('podcast_voices')
        .update({'is_active': active})
        .eq('id', voice.id)
        .select()
        .single();

    return PodcastVoice.fromJson(Map<String, dynamic>.from(row));
  }

  Future<String> createSampleSignedUrl(PodcastVoice voice) {
    return _client.storage
        .from(storageBucket)
        .createSignedUrl(voice.samplePath, 300);
  }

  Future<String> createConsentSignedUrl(PodcastVoice voice) {
    return _client.storage
        .from(storageBucket)
        .createSignedUrl(voice.consentRecordingPath, 300);
  }

  Future<void> deleteVoice(PodcastVoice voice) async {
    // On rend d'abord la voix inutilisable. Si le nettoyage Storage échoue,
    // la fiche reste présente mais inactive au lieu de laisser des fichiers
    // vocaux orphelins sans registre.
    if (voice.isActive) {
      await setActive(voice, false);
    }

    await _client.storage.from(storageBucket).remove(<String>[
      voice.samplePath,
      voice.consentRecordingPath,
    ]);

    final deleted = await _client
        .from('podcast_voices')
        .delete()
        .eq('id', voice.id)
        .select('id');
    if ((deleted as List).isEmpty) {
      throw StateError('Suppression refusée ou voix introuvable.');
    }
  }

  String? _nullIfBlank(String value) {
    final text = value.trim();
    return text.isEmpty ? null : text;
  }

  String _uuidV4() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-'
        '${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-'
        '${hex.substring(16, 20)}-'
        '${hex.substring(20)}';
  }
}
