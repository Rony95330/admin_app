import 'dart:async';

import 'package:admin_app/models/podcast_ai_models.dart';
import 'package:admin_app/pages/admin/podcast_ai_studio_page.dart';
import 'package:admin_app/services/podcast_ai_service.dart';
import 'package:admin_app/services/podcast_voice_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

PodcastAiJob _job({String status = PodcastAiStatuses.scriptReady}) =>
    PodcastAiJob(
      id: 'job-shared',
      createdBy: 'admin-a',
      title: 'Compte rendu HUB partagé',
      cse: 'CSE EXPLOITATION HUB',
      requestedMinutes: 5,
      voiceConfig: const PodcastVoiceConfig.standard(),
      status: status,
      createdAt: DateTime.utc(2026, 9, 21),
      sourcePdfName: 'cr.pdf',
      sourcePdfPath: 'admin-a/job-shared/source.pdf',
      script: 'Camille : Bonjour.\nAlex : Bonjour.',
    );

class _FakeService implements PodcastAiStudioService {
  _FakeService({required this.access, this.jobs = const []});
  final PodcastVoiceAccess access;
  final List<PodcastAiJob> jobs;
  int generateScriptCalls = 0;
  Completer<PodcastAiJob>? generateCompleter;

  @override
  Future<PodcastVoiceAccess> loadAccess() async => access;
  @override
  Future<List<String>> allowedCses() async => access.isSuperuser
      ? PodcastVoiceService.canonicalCses
      : <String>[access.cse];
  @override
  Future<List<PodcastAiJob>> loadJobs({int limit = 100}) async => jobs;
  @override
  Future<PodcastAiJob> loadJob(String id) async => jobs.first;
  @override
  Future<List<PodcastAiVoiceOption>> loadReadyVoices(String cse) async =>
      const [];
  @override
  Future<PodcastAiJob> createFromPdf({
    required String title,
    required String cse,
    required int requestedMinutes,
    required PlatformFile pdf,
  }) => throw UnimplementedError();
  @override
  Future<String> getSourceUrl(String jobId) async =>
      'https://example.test/source.pdf';
  @override
  Future<PodcastAiJob> generateScript(String jobId) {
    generateScriptCalls++;
    return (generateCompleter ??= Completer<PodcastAiJob>()).future;
  }

  @override
  Future<PodcastAiJob> saveScript({
    required String jobId,
    required String title,
    required String script,
    required PodcastVoiceConfig voiceConfig,
  }) async => jobs.first;
  @override
  Future<void> generateAudio(String jobId) async {}
  @override
  Future<PodcastAiJob> publish(String jobId) async => jobs.first;
  @override
  Future<void> deleteJob(String jobId) async {}
}

void main() {
  group('statuts Studio Podcast', () {
    test('utilise uniquement les huit statuts backend', () {
      expect(PodcastAiStatuses.values, const <String>[
        'draft',
        'uploading',
        'uploaded',
        'script_ready',
        'generating_audio',
        'ready',
        'published',
        'failed',
      ]);
      expect(PodcastAiStatuses.label('script_ready'), 'Script prêt');
      expect(PodcastAiStatuses.label('published'), 'Publié');
    });

    test('les identifiants de voix restent sérialisés comme le mobile', () {
      const config = PodcastVoiceConfig.standard();
      expect(config.toJson()['speaker_1']['voice'], 'Kore');
      expect(config.toJson()['speaker_2']['voice'], 'Puck');
    });
  });

  testWidgets('refuse la page à un profil non administrateur', (tester) async {
    final service = _FakeService(
      access: const PodcastVoiceAccess(
        role: 'mili',
        cse: 'CSE EXPLOITATION HUB',
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: PodcastAiStudioPage(service: service)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Accès refusé'), findsOneWidget);
    expect(find.text('Nouveau podcast'), findsNothing);
  });

  testWidgets('affiche un job partagé sans filtrage created_by', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final service = _FakeService(
      access: const PodcastVoiceAccess(
        role: 'adm',
        cse: 'CSE EXPLOITATION HUB',
      ),
      jobs: <PodcastAiJob>[_job()],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: PodcastAiStudioPage(service: service)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Compte rendu HUB partagé'), findsOneWidget);
    expect(find.textContaining('Script prêt'), findsOneWidget);
  });

  testWidgets('bloque un double clic pendant la génération', (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final service = _FakeService(
      access: const PodcastVoiceAccess(
        role: 'adm',
        cse: 'CSE EXPLOITATION HUB',
      ),
      jobs: <PodcastAiJob>[_job()],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: PodcastAiStudioPage(service: service)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('open-job-shared')));
    await tester.pumpAndSettle();
    final button = find.widgetWithText(OutlinedButton, 'Générer le script');
    await tester.tap(button);
    await tester.pump();
    await tester.tap(button, warnIfMissed: false);
    await tester.pump();
    expect(service.generateScriptCalls, 1);
    service.generateCompleter!.complete(_job());
    await tester.pumpAndSettle();
  });
}
