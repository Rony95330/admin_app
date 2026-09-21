import 'package:admin_app/models/podcast_ai_models.dart';
import 'package:admin_app/services/podcast_ai_service.dart';
import 'package:admin_app/services/podcast_voice_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_test/flutter_test.dart';

PodcastAiVoiceOption voice(String id, String name) => PodcastAiVoiceOption(
  id: id,
  displayName: name,
  cse: 'CSE EXPLOITATION HUB',
  provider: 'elevenlabs',
  providerStatus: 'ready',
  isActive: true,
  providerVoiceId: 'provider-$id',
);

PodcastAiJob job(PodcastVoiceConfig config) => PodcastAiJob(
  id: 'job',
  createdBy: 'admin',
  title: 'Titre',
  cse: 'CSE EXPLOITATION HUB',
  requestedMinutes: 5,
  voiceConfig: config,
  status: PodcastAiStatuses.scriptReady,
  createdAt: DateTime.utc(2026),
  script: 'Camille: Bonjour\nAlex: Salut',
);

class FakeService implements PodcastAiStudioService {
  FakeService(this.current);
  PodcastAiJob current;
  final calls = <String>[];
  bool persistWrongConfig = false;
  @override
  Future<PodcastAiJob> saveScript({
    required String jobId,
    required String title,
    required String script,
    required PodcastVoiceConfig voiceConfig,
  }) async {
    calls.add('save');
    current = job(
      persistWrongConfig ? const PodcastVoiceConfig.standard() : voiceConfig,
    );
    return current;
  }

  @override
  Future<void> generateAudio(String jobId) async {
    calls.add('audio');
  }

  @override
  Future<List<String>> allowedCses() => throw UnimplementedError();
  @override
  Future<PodcastAiJob> createFromPdf({
    required String title,
    required String cse,
    required int requestedMinutes,
    required PlatformFile pdf,
  }) => throw UnimplementedError();
  @override
  Future<void> deleteJob(String jobId) => throw UnimplementedError();
  @override
  Future<PodcastAiJob> generateScript(String jobId) =>
      throw UnimplementedError();
  @override
  Future<String> getSourceUrl(String jobId) => throw UnimplementedError();
  @override
  Future<PodcastVoiceAccess> loadAccess() => throw UnimplementedError();
  @override
  Future<PodcastAiJob> loadJob(String id) => throw UnimplementedError();
  @override
  Future<List<PodcastAiJob>> loadJobs({int limit = 100}) =>
      throw UnimplementedError();
  @override
  Future<List<PodcastAiVoiceOption>> loadReadyVoices(String cse) =>
      throw UnimplementedError();
  @override
  Future<PodcastAiJob> publish(String jobId) => throw UnimplementedError();
}

void main() {
  final selected = PodcastVoiceConfig(
    version: 1,
    speaker1: PodcastSpeakerVoiceConfig.custom(
      speaker: 'Camille',
      option: voice('11111111-1111-4111-8111-111111111111', 'Christophe'),
    ),
    speaker2: PodcastSpeakerVoiceConfig.custom(
      speaker: 'Alex',
      option: voice('22222222-2222-4222-8222-222222222222', 'Anissa'),
    ),
  );

  test('sérialise et recharge Christophe et Anissa comme voix custom', () {
    final json = selected.toJson();
    expect(
      json['speaker_1']['custom_voice_id'],
      '11111111-1111-4111-8111-111111111111',
    );
    expect(json['speaker_1']['label'], 'Christophe');
    expect(PodcastVoiceConfig.fromJson(json).sameSelectionAs(selected), isTrue);
  });

  test('affiche les noms choisis tout en conservant le script canonique', () {
    final displayed = selected.displayScript('Camille: Bonjour\nAlex: Salut');
    expect(displayed, 'Christophe: Bonjour\n\nAnissa: Salut');
    expect(
      selected.canonicalScript(displayed),
      'Camille: Bonjour\n\nAlex: Salut',
    );
  });

  group('mapping visuel des locuteurs', () {
    test('affiche Anissa et Christophe dans les labels et les mentions', () {
      final anissaChristophe = PodcastVoiceConfig(
        version: 1,
        speaker1: PodcastSpeakerVoiceConfig.custom(
          speaker: 'Camille',
          option: voice('22222222-2222-4222-8222-222222222222', 'Anissa'),
        ),
        speaker2: PodcastSpeakerVoiceConfig.custom(
          speaker: 'Alex',
          option: voice('11111111-1111-4111-8111-111111111111', 'Christophe'),
        ),
      );
      expect(
        anissaChristophe.displayScript(
          'Camille: Bonjour Alex. Alex: Bonjour Camille.',
        ),
        'Anissa: Bonjour Christophe.\n\nChristophe: Bonjour Anissa.',
      );
    });

    test('remplace tous les tours présents sur une seule ligne', () {
      const canonical =
          'Camille: Bonjour. Alex: Salut. Camille: Suite. Alex: Fin.';
      final displayed = selected.displayScript(canonical);
      expect(
        displayed,
        'Christophe: Bonjour.\n\nAnissa: Salut.\n\n'
        'Christophe: Suite.\n\nAnissa: Fin.',
      );
      expect(RegExp(r'\b(?:Camille|Alex)\s*:').hasMatch(displayed), isFalse);
    });

    test('remplace tous les tours multiligne', () {
      const canonical =
          'Camille: Un.\nAlex: Deux.\nCamille: Trois.\nAlex: Quatre.';
      final displayed = selected.displayScript(canonical);
      expect(RegExp(r'Christophe\s*:').allMatches(displayed), hasLength(2));
      expect(RegExp(r'Anissa\s*:').allMatches(displayed), hasLength(2));
    });

    test('projette Camille prononcé dans une réplique', () {
      expect(
        selected.displayScript('Alex: Bonjour Camille !'),
        'Anissa: Bonjour Christophe !',
      );
    });

    test('projette Alex prononcé dans une réplique', () {
      expect(
        selected.displayScript('Camille: Bonjour Alex !'),
        'Christophe: Bonjour Anissa !',
      );
    });

    test('projette labels et mentions avec le bon slot', () {
      const canonical = 'Camille: Bonjour Alex. Alex: Bonjour Camille.';
      expect(
        selected.displayScript(canonical),
        'Christophe: Bonjour Anissa.\n\nAnissa: Bonjour Christophe.',
      );
    });

    test('respecte les frontières lexicales', () {
      expect(
        selected.displayScript(
          'Camille: Alexandre travaille avec Alexis et CamilleDurand.',
        ),
        'Christophe: Alexandre travaille avec Alexis et CamilleDurand.',
      );
    });

    test('conversion inverse et aller-retour restent canoniques', () {
      const canonical = 'Camille: Bonjour Anissa ! Alex: Bonjour Christophe !';
      final displayed = selected.displayScript(canonical);
      expect(
        selected.canonicalScript(displayed),
        'Camille: Bonjour Alex !\n\nAlex: Bonjour Camille !',
      );
    });

    test('un changement de voix remappe les labels sans toucher au texte', () {
      final changed = PodcastVoiceConfig(
        version: 1,
        speaker1: PodcastSpeakerVoiceConfig.custom(
          speaker: 'Camille',
          option: voice('33333333-3333-4333-8333-333333333333', 'Ronan'),
        ),
        speaker2: PodcastSpeakerVoiceConfig.custom(
          speaker: 'Alex',
          option: voice('11111111-1111-4111-8111-111111111111', 'Christophe'),
        ),
      );
      final oldDisplay = selected.displayScript(
        'Camille: Bonjour Anissa ! Alex: Bonjour Christophe !',
      );
      final remapped = changed.displayScript(
        selected.canonicalScript(oldDisplay),
      );
      expect(
        remapped,
        'Ronan: Bonjour Christophe !\n\nChristophe: Bonjour Ronan !',
      );
    });
  });

  test('sauvegarde les voix avant generate_audio', () async {
    final service = FakeService(job(const PodcastVoiceConfig.standard()));
    await persistVoicesBeforeAudio(
      service: service,
      job: service.current,
      title: 'Titre',
      canonicalScript: 'Camille: A\nAlex: B',
      selectedVoices: selected,
    );
    expect(service.calls, ['save', 'audio']);
  });

  test(
    'bloque generate_audio si la base ne confirme pas la sélection',
    () async {
      final service = FakeService(job(const PodcastVoiceConfig.standard()))
        ..persistWrongConfig = true;
      await expectLater(
        persistVoicesBeforeAudio(
          service: service,
          job: service.current,
          title: 'Titre',
          canonicalScript: 'Camille: A\nAlex: B',
          selectedVoices: selected,
        ),
        throwsA(isA<PodcastAiException>()),
      );
      expect(service.calls, ['save']);
    },
  );
}
