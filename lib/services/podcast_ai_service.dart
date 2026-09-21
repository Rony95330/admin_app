import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/podcast_ai_models.dart';
import 'podcast_voice_service.dart';

class PodcastAiException implements Exception {
  const PodcastAiException(this.message);
  final String message;
  @override
  String toString() => message;
}

abstract class PodcastAiStudioService {
  Future<PodcastVoiceAccess> loadAccess();
  Future<List<String>> allowedCses();
  Future<List<PodcastAiJob>> loadJobs({int limit = 100});
  Future<PodcastAiJob> loadJob(String id);
  Future<List<PodcastAiVoiceOption>> loadReadyVoices(String cse);
  Future<PodcastAiJob> createFromPdf({
    required String title,
    required String cse,
    required int requestedMinutes,
    required PlatformFile pdf,
  });
  Future<String> getSourceUrl(String jobId);
  Future<PodcastAiJob> generateScript(String jobId);
  Future<PodcastAiJob> saveScript({
    required String jobId,
    required String title,
    required String script,
    required PodcastVoiceConfig voiceConfig,
  });
  Future<void> generateAudio(String jobId);
  Future<PodcastAiJob> publish(String jobId);
  Future<void> deleteJob(String jobId);
}

Future<PodcastAiJob> persistVoicesBeforeAudio({
  required PodcastAiStudioService service,
  required PodcastAiJob job,
  required String title,
  required String canonicalScript,
  required PodcastVoiceConfig selectedVoices,
}) async {
  final saved = await service.saveScript(
    jobId: job.id,
    title: title,
    script: canonicalScript,
    voiceConfig: selectedVoices,
  );
  if (!saved.voiceConfig.sameSelectionAs(selectedVoices)) {
    throw const PodcastAiException(
      'Les voix enregistrées ne correspondent pas à la sélection affichée.',
    );
  }
  await service.generateAudio(saved.id);
  return saved;
}

class SupabasePodcastAiService implements PodcastAiStudioService {
  SupabasePodcastAiService({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  static const sourceBucket = 'podcast_sources';
  static const audioBucket = 'podcast_ai_audio';
  static const publishedBucket = 'podcasts';
  static const functionName = 'podcast-ai';

  final SupabaseClient _client;

  PodcastVoiceService get _voiceService => PodcastVoiceService(client: _client);

  @override
  Future<PodcastVoiceAccess> loadAccess() => _voiceService.loadAccess();

  @override
  Future<List<String>> allowedCses() => _voiceService.allowedCses();

  @override
  Future<List<PodcastAiJob>> loadJobs({int limit = 100}) async {
    final rows = await _client
        .from('podcast_ai_jobs')
        .select()
        .order('created_at', ascending: false)
        .limit(limit);
    return Future.wait(
      (rows as List).whereType<Map>().map((row) async {
        final data = Map<String, dynamic>.from(row);
        await _hydrateAudio(data);
        return PodcastAiJob.fromJson(data);
      }),
    );
  }

  @override
  Future<PodcastAiJob> loadJob(String id) async {
    final row = await _client
        .from('podcast_ai_jobs')
        .select()
        .eq('id', id)
        .single();
    final data = Map<String, dynamic>.from(row);
    await _hydrateAudio(data);
    return PodcastAiJob.fromJson(data);
  }

  Future<void> _hydrateAudio(Map<String, dynamic> row) async {
    final path = (row['audio_path'] ?? '').toString().trim();
    if (path.isEmpty) return;
    final bucket = row['status'] == PodcastAiStatuses.published
        ? publishedBucket
        : audioBucket;
    try {
      final signedUrl = await _client.storage
          .from(bucket)
          .createSignedUrl(path, 3600);
      final marker = Uri.encodeComponent(
        (row['updated_at'] ?? DateTime.now().toUtc().toIso8601String())
            .toString(),
      );
      row['audio_url'] =
          '$signedUrl${signedUrl.contains('?') ? '&' : '?'}v=$marker';
    } catch (_) {
      row['audio_url'] = null;
    }
  }

  @override
  Future<List<PodcastAiVoiceOption>> loadReadyVoices(String cse) async {
    final rows = await _client
        .from('podcast_voices')
        .select(
          'id,display_name,cse,provider,provider_voice_id,provider_status,is_active',
        )
        .eq('cse', cse.trim())
        .eq('is_active', true)
        .eq('provider_status', 'ready')
        .not('provider_voice_id', 'is', null)
        .order('display_name');
    return (rows as List)
        .whereType<Map>()
        .map(
          (row) =>
              PodcastAiVoiceOption.fromJson(Map<String, dynamic>.from(row)),
        )
        .where(
          (voice) =>
              voice.id.isNotEmpty &&
              voice.isReady &&
              (voice.providerVoiceId ?? '').trim().isNotEmpty,
        )
        .toList(growable: false);
  }

  @override
  Future<PodcastAiJob> createFromPdf({
    required String title,
    required String cse,
    required int requestedMinutes,
    required PlatformFile pdf,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw const PodcastAiException('Session expirée.');
    final allowed = await allowedCses();
    if (!allowed.contains(cse.trim())) {
      throw const PodcastAiException('Accès refusé pour ce CSE.');
    }
    if (pdf.size > 20 * 1024 * 1024) {
      throw const PodcastAiException('Le PDF dépasse la limite de 20 Mo.');
    }
    final Uint8List? bytes = pdf.bytes;
    if (bytes == null || bytes.isEmpty) {
      throw const PodcastAiException('Impossible de lire ce PDF.');
    }
    final inserted = await _client
        .from('podcast_ai_jobs')
        .insert({
          'created_by': user.id,
          'title': title.trim(),
          'cse': cse.trim(),
          'requested_minutes': requestedMinutes,
          'source_pdf_name': pdf.name,
          'status': PodcastAiStatuses.uploading,
        })
        .select()
        .single();
    final job = PodcastAiJob.fromJson(Map<String, dynamic>.from(inserted));
    final objectPath = '${user.id}/${job.id}/source.pdf';
    try {
      await _client.storage
          .from(sourceBucket)
          .uploadBinary(
            objectPath,
            bytes,
            fileOptions: const FileOptions(
              contentType: 'application/pdf',
              cacheControl: '0',
              upsert: false,
            ),
          );
      final updated = await _client
          .from('podcast_ai_jobs')
          .update({
            'source_pdf_path': objectPath,
            'status': PodcastAiStatuses.uploaded,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', job.id)
          .select()
          .single();
      return PodcastAiJob.fromJson(Map<String, dynamic>.from(updated));
    } catch (_) {
      try {
        await _client.storage.from(sourceBucket).remove(<String>[objectPath]);
        await _client.from('podcast_ai_jobs').delete().eq('id', job.id);
      } catch (_) {}
      throw const PodcastAiException('Import du PDF impossible.');
    }
  }

  @override
  Future<String> getSourceUrl(String jobId) async {
    final data = await _invoke(<String, dynamic>{
      'action': 'source_url',
      'job_id': jobId,
    });
    final url = (data['url'] ?? '').toString().trim();
    if (url.isEmpty) throw const PodcastAiException('Source indisponible.');
    return url;
  }

  @override
  Future<PodcastAiJob> generateScript(String jobId) async => _jobFromResponse(
    await _invoke(<String, dynamic>{
      'action': 'generate_script',
      'job_id': jobId,
    }),
  );

  @override
  Future<PodcastAiJob> saveScript({
    required String jobId,
    required String title,
    required String script,
    required PodcastVoiceConfig voiceConfig,
  }) async {
    final row = await _client
        .from('podcast_ai_jobs')
        .update({
          'title': title.trim(),
          'script': script.trim(),
          'voice_config': voiceConfig.toJson(),
          'status': PodcastAiStatuses.scriptReady,
          'audio_url': null,
          'error_message': null,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', jobId)
        .select()
        .single();
    return PodcastAiJob.fromJson(Map<String, dynamic>.from(row));
  }

  @override
  Future<void> generateAudio(String jobId) async {
    await _invoke(<String, dynamic>{
      'action': 'generate_audio',
      'job_id': jobId,
    });
  }

  @override
  Future<PodcastAiJob> publish(String jobId) async => _jobFromResponse(
    await _invoke(<String, dynamic>{'action': 'publish', 'job_id': jobId}),
  );

  @override
  Future<void> deleteJob(String jobId) async {
    await _invoke(<String, dynamic>{'action': 'delete_job', 'job_id': jobId});
  }

  Future<Map<String, dynamic>> _invoke(Map<String, dynamic> body) async {
    try {
      final response = await _client.functions.invoke(functionName, body: body);
      final raw = response.data;
      if (raw is! Map) {
        throw const PodcastAiException('Réponse serveur invalide.');
      }
      final data = Map<String, dynamic>.from(raw);
      if (response.status < 200 ||
          response.status >= 300 ||
          data['ok'] != true) {
        throw PodcastAiException(_safeMessage(data['message']));
      }
      return data;
    } on PodcastAiException {
      rethrow;
    } catch (_) {
      throw const PodcastAiException('Le Studio Podcast est indisponible.');
    }
  }

  String _safeMessage(dynamic raw) {
    final message = raw?.toString().trim() ?? '';
    const allowed = <String>[
      'Accès refusé',
      'Source',
      'Voix',
      'voix',
      'Génération',
      'Audio',
      'Publication',
      'déjà publié',
      'Suppression',
      'Validez',
      'limite',
      'budget',
      'désactivée',
    ];
    return allowed.any(message.contains)
        ? message
        : 'L’action demandée n’a pas pu être réalisée.';
  }

  PodcastAiJob _jobFromResponse(Map<String, dynamic> data) {
    final raw = data['job'];
    if (raw is! Map) {
      throw const PodcastAiException('Projet podcast introuvable.');
    }
    return PodcastAiJob.fromJson(Map<String, dynamic>.from(raw));
  }
}
