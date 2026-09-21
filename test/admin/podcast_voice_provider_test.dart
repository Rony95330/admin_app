import 'package:admin_app/models/podcast_ai_models.dart';
import 'package:admin_app/models/podcast_voice.dart';
import 'package:admin_app/pages/admin/podcast_voice_admin_page.dart';
import 'package:admin_app/services/podcast_voice_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

PodcastVoice _voice({
  required String id,
  required String status,
  String? providerVoiceId,
  bool active = false,
}) => PodcastVoice(
  id: id,
  displayName: id,
  cse: 'CSE EXPLOITATION HUB',
  samplePath: 'user/HUB/$id/sample.wav',
  consentRecordingPath: 'user/HUB/$id/consent.wav',
  consentAccepted: true,
  consentAt: DateTime.utc(2026, 9, 21),
  provider: providerVoiceId == null ? null : 'elevenlabs',
  providerVoiceId: providerVoiceId,
  providerStatus: status,
  isActive: active,
  createdAt: DateTime.utc(2026, 9, 21),
);

class _FakeVoiceService extends PodcastVoiceService {
  _FakeVoiceService(this.voice, {this.registrationError = false})
    : super(providerInvoker: (_) async => <String, dynamic>{});

  PodcastVoice voice;
  final bool registrationError;
  String? registeredVoiceId;

  @override
  Future<List<String>> allowedCses() async => <String>['CSE EXPLOITATION HUB'];

  @override
  Future<List<PodcastVoice>> listVoices({String? cse}) async => <PodcastVoice>[
    voice,
  ];

  @override
  Future<String> registerVoice(String voiceId) async {
    registeredVoiceId = voiceId;
    if (registrationError) throw StateError('{"secret":"raw provider error"}');
    voice = _voice(
      id: voice.id,
      status: 'ready',
      providerVoiceId: 'eleven-voice-id',
    );
    return 'ready';
  }
}

Future<void> _pumpPage(WidgetTester tester, _FakeVoiceService service) async {
  await tester.binding.setSurfaceSize(const Size(1200, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: PodcastVoiceAdminPage(service: service)),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  test('register envoie exclusivement action register et voice_id', () async {
    Map<String, dynamic>? received;
    final service = PodcastVoiceService(
      providerInvoker: (body) async {
        received = body;
        return <String, dynamic>{
          'ok': true,
          'voice': <String, dynamic>{'provider_status': 'pending'},
        };
      },
    );
    expect(await service.registerVoice('voice-uuid'), 'pending');
    expect(received, <String, dynamic>{
      'action': 'register',
      'voice_id': 'voice-uuid',
    });
  });

  testWidgets('not_registered affiche Activer et désactive Active', (
    tester,
  ) async {
    final service = _FakeVoiceService(
      _voice(id: 'Ronan', status: 'not_registered'),
    );
    await _pumpPage(tester, service);
    expect(find.text('Non activée chez ElevenLabs'), findsOneWidget);
    expect(find.text('Activer chez ElevenLabs'), findsOneWidget);
    final toggle = tester.widget<Switch>(
      find.byKey(const ValueKey('active-Ronan')),
    );
    expect(toggle.onChanged, isNull);
  });

  testWidgets('pending ne permet pas une nouvelle activation', (tester) async {
    final service = _FakeVoiceService(_voice(id: 'Ronan', status: 'pending'));
    await _pumpPage(tester, service);
    expect(find.text('Activation en cours'), findsOneWidget);
    expect(find.text('Activer chez ElevenLabs'), findsNothing);
  });

  testWidgets('ready avec provider_voice_id active le toggle', (tester) async {
    final service = _FakeVoiceService(
      _voice(id: 'Ronan', status: 'ready', providerVoiceId: 'eleven-id'),
    );
    await _pumpPage(tester, service);
    expect(find.text('ElevenLabs prêt'), findsOneWidget);
    final toggle = tester.widget<Switch>(
      find.byKey(const ValueKey('active-Ronan')),
    );
    expect(toggle.onChanged, isNotNull);
  });

  testWidgets('succès ready rafraîchit la ligne', (tester) async {
    final service = _FakeVoiceService(
      _voice(id: 'Ronan', status: 'not_registered'),
    );
    await _pumpPage(tester, service);
    await tester.tap(find.byKey(const ValueKey('activate-Ronan')));
    await tester.pumpAndSettle();
    expect(service.registeredVoiceId, 'Ronan');
    expect(find.text('ElevenLabs prêt'), findsOneWidget);
    expect(find.text('Voix activée chez ElevenLabs.'), findsOneWidget);
  });

  testWidgets('erreur fournisseur reste lisible et sans JSON brut', (
    tester,
  ) async {
    final service = _FakeVoiceService(
      _voice(id: 'Ronan', status: 'not_registered'),
      registrationError: true,
    );
    await _pumpPage(tester, service);
    await tester.tap(find.byKey(const ValueKey('activate-Ronan')));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Activation ElevenLabs impossible'),
      findsOneWidget,
    );
    expect(find.textContaining('secret'), findsNothing);
  });

  test('Studio exclut une voix active mais non enregistrée', () {
    final option = PodcastAiVoiceOption.fromJson(<String, dynamic>{
      'id': 'voice-id',
      'display_name': 'Christophe',
      'cse': 'CSE EXPLOITATION HUB',
      'provider': 'elevenlabs',
      'provider_status': 'not_registered',
      'is_active': true,
    });
    expect(option.isReady, isFalse);
  });
}
