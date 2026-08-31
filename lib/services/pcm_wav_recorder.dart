import 'dart:async';
import 'dart:typed_data';

import 'package:record/record.dart';

class RecordedWav {
  const RecordedWav({required this.bytes, required this.duration});

  final Uint8List bytes;
  final Duration duration;
}

enum MicrophoneCheckStatus {
  ready,
  permissionDenied,
  unavailable,
  busy,
  insecureContext,
  unknownError,
}

class MicrophoneCheckResult {
  const MicrophoneCheckResult({
    required this.status,
    required this.title,
    required this.message,
    this.inputLevel = 0,
    this.technicalDetails,
  });

  final MicrophoneCheckStatus status;
  final String title;
  final String message;

  /// Niveau instantané normalisé de 0 à 1 mesuré pendant le test.
  final double inputLevel;

  /// Détail destiné au diagnostic, jamais affiché comme message principal.
  final String? technicalDetails;

  bool get isReady => status == MicrophoneCheckStatus.ready;
}

/// Enregistre un flux PCM16 mono 24 kHz puis l'encapsule dans un WAV.
///
/// Ce choix évite les chemins de fichiers locaux et fonctionne aussi dans
/// Flutter Web, ce qui est adapté à la console d'administration.
class PcmWavRecorder {
  static const int sampleRate = 24000;
  static const int channels = 1;
  static const int bytesPerSample = 2;

  final AudioRecorder _recorder = AudioRecorder();

  BytesBuilder _buffer = BytesBuilder(copy: false);
  StreamSubscription<Uint8List>? _subscription;
  Completer<void>? _streamDone;
  bool _recording = false;

  bool get isRecording => _recording;

  static const RecordConfig _recordConfig = RecordConfig(
    encoder: AudioEncoder.pcm16bits,
    sampleRate: sampleRate,
    numChannels: channels,
    // Pour une voix destinée à être clonée/synthétisée, on conserve
    // l'empreinte naturelle et on évite les traitements agressifs.
    echoCancel: false,
    noiseSuppress: false,
    autoGain: false,
  );

  /// Vérifie réellement que le navigateur / système autorise le micro.
  ///
  /// `hasPermission()` seul n'est pas suffisant sur tous les navigateurs :
  /// on ouvre donc brièvement un flux audio, on mesure son niveau puis on le
  /// referme immédiatement. Aucun fichier n'est conservé par ce test.
  Future<MicrophoneCheckResult> checkMicrophone() async {
    if (_recording) {
      return const MicrophoneCheckResult(
        status: MicrophoneCheckStatus.busy,
        title: 'Microphone déjà utilisé',
        message: 'Arrête l’enregistrement en cours puis relance le test.',
      );
    }

    StreamSubscription<Uint8List>? probeSubscription;
    var probeStarted = false;
    var peak = 0.0;

    try {
      final hasPermission = await _recorder.hasPermission().timeout(
        const Duration(seconds: 6),
        onTimeout: () => false,
      );
      if (!hasPermission) {
        return const MicrophoneCheckResult(
          status: MicrophoneCheckStatus.permissionDenied,
          title: 'Microphone non autorisé',
          message:
              'Le navigateur ou le système n’a pas autorisé l’accès au microphone. '
              'Vérifie les autorisations puis clique sur « Tester à nouveau ». '
              'Si le problème persiste, essaie un autre navigateur.',
        );
      }

      final stream = await _recorder.startStream(_recordConfig);
      probeStarted = true;

      probeSubscription = stream.listen((chunk) {
        final chunkPeak = _pcm16Peak(chunk);
        if (chunkPeak > peak) peak = chunkPeak;
      }, cancelOnError: false);

      // Une durée courte suffit pour confirmer l'ouverture du périphérique et
      // obtenir un niveau sonore indicatif sans gêner l'utilisateur.
      await Future<void>.delayed(const Duration(milliseconds: 850));

      return MicrophoneCheckResult(
        status: MicrophoneCheckStatus.ready,
        title: 'Microphone prêt',
        message: peak > 0.01
            ? 'Le microphone est accessible et un signal sonore a été détecté.'
            : 'Le microphone est accessible. Aucun son notable n’a été détecté pendant le test.',
        inputLevel: peak.clamp(0.0, 1.0).toDouble(),
      );
    } catch (error) {
      return classifyMicrophoneError(error);
    } finally {
      if (probeStarted) {
        try {
          await _recorder.stop();
        } catch (_) {
          // Le test doit rester sans effet de bord même si le backend audio
          // a déjà fermé le flux après une erreur.
        }
      }
      await probeSubscription?.cancel();
    }
  }

  /// Transforme les erreurs navigateur / OS les plus courantes en messages
  /// compréhensibles pour un administrateur non technique.
  static MicrophoneCheckResult classifyMicrophoneError(Object error) {
    final technical = error.toString();
    final lower = technical.toLowerCase();

    if (lower.contains('notallowederror') ||
        lower.contains('permission denied') ||
        lower.contains('permissiondenied') ||
        lower.contains('microphone permission') ||
        lower.contains('autorisation') && lower.contains('refus')) {
      return MicrophoneCheckResult(
        status: MicrophoneCheckStatus.permissionDenied,
        title: 'Microphone bloqué',
        message:
            'Le navigateur ou le système refuse l’accès au microphone. Vérifie les autorisations puis clique sur « Tester à nouveau ».',
        technicalDetails: technical,
      );
    }

    if (lower.contains('notfounderror') ||
        lower.contains('device not found') ||
        lower.contains('no input device') ||
        lower.contains('aucun microphone')) {
      return MicrophoneCheckResult(
        status: MicrophoneCheckStatus.unavailable,
        title: 'Aucun microphone détecté',
        message:
            'Aucun périphérique d’entrée audio n’est disponible. Vérifie qu’un microphone est connecté et activé.',
        technicalDetails: technical,
      );
    }

    if (lower.contains('notreadableerror') ||
        lower.contains('trackstarterror') ||
        lower.contains('device busy') ||
        lower.contains('in use') ||
        lower.contains('could not start')) {
      return MicrophoneCheckResult(
        status: MicrophoneCheckStatus.busy,
        title: 'Microphone indisponible',
        message:
            'Le microphone semble utilisé ou verrouillé par une autre application. Ferme les applications audio/visioconférence puis réessaie.',
        technicalDetails: technical,
      );
    }

    if (lower.contains('securityerror') ||
        lower.contains('secure context') ||
        lower.contains('https required')) {
      return MicrophoneCheckResult(
        status: MicrophoneCheckStatus.insecureContext,
        title: 'Contexte Web non autorisé',
        message:
            'Le navigateur exige une connexion sécurisée pour accéder au microphone. Utilise l’adresse HTTPS officielle de la console.',
        technicalDetails: technical,
      );
    }

    return MicrophoneCheckResult(
      status: MicrophoneCheckStatus.unknownError,
      title: 'Microphone indisponible',
      message:
          'Le test du microphone a échoué. Vérifie les autorisations du navigateur et du système puis réessaie.',
      technicalDetails: technical,
    );
  }

  Future<void> start() async {
    if (_recording) {
      throw StateError('Un enregistrement est déjà en cours.');
    }

    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      throw StateError(
        "L'autorisation d'utiliser le microphone a été refusée.",
      );
    }

    _buffer = BytesBuilder(copy: false);
    _streamDone = Completer<void>();

    final stream = await _recorder.startStream(_recordConfig);

    _subscription = stream.listen(
      _buffer.add,
      onError: (Object error, StackTrace stackTrace) {
        if (!(_streamDone?.isCompleted ?? true)) {
          _streamDone!.completeError(error, stackTrace);
        }
      },
      onDone: () {
        if (!(_streamDone?.isCompleted ?? true)) {
          _streamDone!.complete();
        }
      },
      cancelOnError: false,
    );
    _recording = true;
  }

  Future<RecordedWav> stop() async {
    if (!_recording) {
      throw StateError("Aucun enregistrement n'est en cours.");
    }

    try {
      await _recorder.stop();
      try {
        await _streamDone?.future.timeout(const Duration(seconds: 2));
      } on TimeoutException {
        // Certains backends ferment le flux après l'appel stop avec un léger
        // décalage. Les octets déjà reçus restent exploitables.
      }
    } finally {
      await _subscription?.cancel();
      _subscription = null;
      _recording = false;
    }

    final pcm = _buffer.toBytes();
    if (pcm.isEmpty) {
      throw StateError("L'enregistrement audio est vide.");
    }

    final durationMs =
        (pcm.length * 1000) ~/ (sampleRate * channels * bytesPerSample);

    return RecordedWav(
      bytes: _wavFromPcm16(pcm),
      duration: Duration(milliseconds: durationMs),
    );
  }

  Future<void> cancel() async {
    if (_recording) {
      await _recorder.cancel();
    }
    await _subscription?.cancel();
    _subscription = null;
    _recording = false;
    _buffer = BytesBuilder(copy: false);
  }

  Future<void> dispose() async {
    await cancel();
    await _recorder.dispose();
  }

  static double _pcm16Peak(Uint8List bytes) {
    if (bytes.length < 2) return 0;

    final usableLength = bytes.length - (bytes.length % 2);
    final data = ByteData.sublistView(bytes, 0, usableLength);
    var maxSample = 0;

    for (var offset = 0; offset < usableLength; offset += 2) {
      final sample = data.getInt16(offset, Endian.little).abs();
      if (sample > maxSample) maxSample = sample;
    }

    return maxSample / 32768.0;
  }

  Uint8List _wavFromPcm16(Uint8List pcm) {
    final output = Uint8List(44 + pcm.length);
    final view = ByteData.sublistView(output);

    void writeAscii(int offset, String value) {
      for (var index = 0; index < value.length; index++) {
        output[offset + index] = value.codeUnitAt(index);
      }
    }

    writeAscii(0, 'RIFF');
    view.setUint32(4, 36 + pcm.length, Endian.little);
    writeAscii(8, 'WAVE');
    writeAscii(12, 'fmt ');
    view.setUint32(16, 16, Endian.little);
    view.setUint16(20, 1, Endian.little); // PCM
    view.setUint16(22, channels, Endian.little);
    view.setUint32(24, sampleRate, Endian.little);
    view.setUint32(28, sampleRate * channels * bytesPerSample, Endian.little);
    view.setUint16(32, channels * bytesPerSample, Endian.little);
    view.setUint16(34, bytesPerSample * 8, Endian.little);
    writeAscii(36, 'data');
    view.setUint32(40, pcm.length, Endian.little);
    output.setRange(44, output.length, pcm);

    return output;
  }
}
