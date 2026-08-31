import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../services/pcm_wav_recorder.dart';
import '../../services/podcast_voice_service.dart';

class PodcastVoiceEditorDialog extends StatefulWidget {
  const PodcastVoiceEditorDialog({
    super.key,
    required this.service,
    required this.allowedCses,
  });

  final PodcastVoiceService service;
  final List<String> allowedCses;

  @override
  State<PodcastVoiceEditorDialog> createState() =>
      _PodcastVoiceEditorDialogState();
}

enum _ClipKind { consent, sample }

class _PodcastVoiceEditorDialogState extends State<PodcastVoiceEditorDialog> {
  static const String _consentText =
      "Je confirme être la personne dont la voix est enregistrée et "
      "j'autorise la section CFDT Air France à utiliser cet enregistrement "
      "pour générer des podcasts syndicaux par synthèse vocale. Je comprends "
      "que je peux demander le retrait de cette autorisation.";

  static const String _sampleText =
      "Bonjour à toutes et à tous. Aujourd'hui, nous allons revenir sur "
      "plusieurs sujets importants concernant notre activité. Certains "
      "dossiers nécessitent quelques explications, et nous allons donc prendre "
      "le temps de les examiner ensemble. Quelles sont les décisions prises ? "
      "Quels changements faut-il retenir ? Nous vous donnerons les éléments "
      "essentiels, les dates, les chiffres et les points de vigilance. Notre "
      "objectif est de vous informer de façon claire, utile et accessible.";

  final _formKey = GlobalKey<FormState>();
  final _displayName = TextEditingController();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _roleLabel = TextEditingController();
  final PcmWavRecorder _recorder = PcmWavRecorder();
  final AudioPlayer _player = AudioPlayer();

  late String _cse;
  bool _consentAccepted = false;
  bool _saving = false;
  _ClipKind? _recording;
  Timer? _timer;
  Duration _recordingElapsed = Duration.zero;

  Uint8List? _consentBytes;
  Duration _consentDuration = Duration.zero;
  Uint8List? _sampleBytes;
  Duration _sampleDuration = Duration.zero;

  MicrophoneCheckResult? _microphoneCheck;
  bool _checkingMicrophone = false;
  bool _showMicrophoneHelp = false;

  bool get _microphoneReady => _microphoneCheck?.isReady == true;

  @override
  void initState() {
    super.initState();
    if (widget.allowedCses.isEmpty) {
      throw StateError('Aucun CSE administrable pour cette session.');
    }
    _cse = widget.allowedCses.first;
  }

  @override
  void dispose() {
    _timer?.cancel();
    _displayName.dispose();
    _firstName.dispose();
    _lastName.dispose();
    _roleLabel.dispose();
    _player.dispose();
    unawaited(_recorder.dispose());
    super.dispose();
  }

  Future<void> _checkMicrophone() async {
    if (_saving || _recording != null || _checkingMicrophone) return;

    setState(() {
      _checkingMicrophone = true;
      _microphoneCheck = null;
    });

    try {
      final result = await _recorder.checkMicrophone();

      if (!mounted) return;

      setState(() {
        _microphoneCheck = result;
        if (!result.isReady) _showMicrophoneHelp = true;
      });
    } catch (error) {
      if (!mounted) return;

      final result = PcmWavRecorder.classifyMicrophoneError(error);

      setState(() {
        _microphoneCheck = result;
        _showMicrophoneHelp = true;
      });
    } finally {
      if (mounted) {
        setState(() {
          _checkingMicrophone = false;
        });
      }
    }
  }

  String _microphoneHelpText() {
    if (!kIsWeb) {
      switch (defaultTargetPlatform) {
        case TargetPlatform.macOS:
          return 'Sur Mac : Réglages Système > Confidentialité et sécurité > '
              'Microphone, puis active la Console CFDT. Reviens ensuite ici '
              'et clique sur « Tester à nouveau ».';
        case TargetPlatform.windows:
          return 'Sous Windows : Paramètres > Confidentialité et sécurité > '
              'Microphone. Active l’accès au microphone pour les applications '
              'de bureau, puis clique sur « Tester à nouveau ».';
        default:
          return 'Vérifie dans les réglages du système que cette application '
              'est autorisée à utiliser le microphone, puis relance le test.';
      }
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.macOS:
        return '1. Dans Chrome : icône à gauche de l’adresse > Paramètres du '
            'site > Microphone > Autoriser. Dans Safari : Réglages > Sites '
            'web > Microphone > Autoriser pour cette console.\n'
            '2. Sur macOS : Réglages Système > Confidentialité et sécurité > '
            'Microphone, puis active le navigateur utilisé.\n'
            '3. Recharge la page si le navigateur le demande, puis clique sur '
            '« Tester à nouveau ».';
      case TargetPlatform.windows:
        return '1. Dans Chrome ou Edge : paramètres du site > Microphone > '
            'Autoriser pour cette console.\n'
            '2. Sous Windows : Paramètres > Confidentialité et sécurité > '
            'Microphone. Active « Accès au microphone » et l’accès pour les '
            'applications de bureau.\n'
            '3. Recharge la page si nécessaire, puis clique sur « Tester à '
            'nouveau ».';
      default:
        return 'Autorise le microphone pour cette console dans les paramètres '
            'du navigateur et dans les réglages de confidentialité du système, '
            'puis clique sur « Tester à nouveau ».';
    }
  }

  void _markMicrophoneFailure(Object error) {
    final result = PcmWavRecorder.classifyMicrophoneError(error);
    if (!mounted) return;
    setState(() {
      _microphoneCheck = result;
      _showMicrophoneHelp = true;
    });
  }

  Future<void> _toggleRecording(_ClipKind kind) async {
    if (_saving) return;

    if (_recording == null && !_microphoneReady) {
      _showError(
        'Vérifie d’abord le microphone avec le bouton « Vérifier mon microphone ».',
      );
      return;
    }

    try {
      if (_recording == null) {
        await _player.stop();
        await _recorder.start();
        if (!mounted) return;
        setState(() {
          _recording = kind;
          _recordingElapsed = Duration.zero;
        });
        _timer?.cancel();
        _timer = Timer.periodic(const Duration(seconds: 1), (_) {
          if (!mounted || _recording == null) return;
          setState(() {
            _recordingElapsed += const Duration(seconds: 1);
          });
        });
        return;
      }

      if (_recording != kind) {
        _showError("Arrête d'abord l'autre enregistrement.");
        return;
      }

      final result = await _recorder.stop();
      _timer?.cancel();
      if (!mounted) return;
      setState(() {
        if (kind == _ClipKind.consent) {
          _consentBytes = result.bytes;
          _consentDuration = result.duration;
        } else {
          _sampleBytes = result.bytes;
          _sampleDuration = result.duration;
        }
        _recording = null;
        _recordingElapsed = Duration.zero;
      });
    } catch (error) {
      _timer?.cancel();
      if (mounted) {
        setState(() {
          _recording = null;
          _recordingElapsed = Duration.zero;
        });
        _markMicrophoneFailure(error);
        _showError(
          'Le microphone est indisponible. Consulte l’aide puis teste-le à nouveau.',
        );
      }
    }
  }

  Future<void> _play(Uint8List? bytes) async {
    if (bytes == null || _recording != null) return;
    try {
      await _player.stop();
      await _player.play(BytesSource(bytes, mimeType: 'audio/wav'));
    } catch (error) {
      _showError('Lecture impossible : $error');
    }
  }

  Future<void> _save() async {
    if (_saving || _recording != null) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    if (!_consentAccepted) {
      _showError('Le consentement doit être accepté.');
      return;
    }
    if (_consentBytes == null ||
        _consentDuration < const Duration(seconds: 5)) {
      _showError('Enregistre au moins 5 secondes de consentement vocal.');
      return;
    }
    if (_sampleBytes == null || _sampleDuration < const Duration(seconds: 20)) {
      _showError('Enregistre au moins 20 secondes de voix.');
      return;
    }
    if (_sampleDuration > const Duration(seconds: 120)) {
      _showError("L'échantillon ne doit pas dépasser 2 minutes.");
      return;
    }

    setState(() => _saving = true);
    try {
      final voice = await widget.service.createVoice(
        displayName: _displayName.text,
        firstName: _firstName.text,
        lastName: _lastName.text,
        cse: _cse,
        roleLabel: _roleLabel.text,
        sampleWav: _sampleBytes!,
        sampleDuration: _sampleDuration,
        consentWav: _consentBytes!,
        consentDuration: _consentDuration,
        consentAccepted: _consentAccepted,
      );
      if (!mounted) return;
      Navigator.of(context).pop(voice);
    } catch (error) {
      _showError('Enregistrement impossible : $error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 860, maxHeight: 820),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 16, 12),
              child: Row(
                children: [
                  Icon(
                    Icons.record_voice_over_outlined,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Enregistrer une voix Podcast',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Fermer',
                    onPressed: _saving || _recording != null
                        ? null
                        : () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _sectionTitle('1. Vérification du microphone'),
                      const SizedBox(height: 12),
                      _microphoneCheckCard(),
                      const SizedBox(height: 28),
                      _sectionTitle('2. Personne et CSE'),
                      const SizedBox(height: 12),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final wide = constraints.maxWidth >= 620;
                          final fields = <Widget>[
                            _textField(
                              controller: _displayName,
                              label: "Nom d'affichage de la voix *",
                              hint: 'Ex. Sophie',
                              required: true,
                            ),
                            _textField(
                              controller: _roleLabel,
                              label: 'Fonction',
                              hint: 'Ex. élue CSE, coordinateur…',
                            ),
                          ];
                          return wide
                              ? Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(child: fields[0]),
                                    const SizedBox(width: 12),
                                    Expanded(child: fields[1]),
                                  ],
                                )
                              : Column(
                                  children: [
                                    fields[0],
                                    const SizedBox(height: 12),
                                    fields[1],
                                  ],
                                );
                        },
                      ),
                      const SizedBox(height: 12),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final wide = constraints.maxWidth >= 620;
                          final first = _textField(
                            controller: _firstName,
                            label: 'Prénom',
                          );
                          final last = _textField(
                            controller: _lastName,
                            label: 'Nom',
                          );
                          return wide
                              ? Row(
                                  children: [
                                    Expanded(child: first),
                                    const SizedBox(width: 12),
                                    Expanded(child: last),
                                  ],
                                )
                              : Column(
                                  children: [
                                    first,
                                    const SizedBox(height: 12),
                                    last,
                                  ],
                                );
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: _cse,
                        decoration: const InputDecoration(
                          labelText: 'CSE *',
                          border: OutlineInputBorder(),
                        ),
                        isExpanded: true,
                        items: widget.allowedCses
                            .map(
                              (value) => DropdownMenuItem(
                                value: value,
                                child: Text(value),
                              ),
                            )
                            .toList(growable: false),
                        onChanged: _saving
                            ? null
                            : (value) {
                                if (value != null) setState(() => _cse = value);
                              },
                      ),
                      const SizedBox(height: 28),
                      _sectionTitle('3. Consentement'),
                      const SizedBox(height: 10),
                      _instructionCard(
                        icon: Icons.verified_user_outlined,
                        title: 'Texte à lire à voix haute',
                        text: _consentText,
                      ),
                      const SizedBox(height: 12),
                      _recordingRow(
                        kind: _ClipKind.consent,
                        label: 'Consentement vocal',
                        duration: _consentDuration,
                        bytes: _consentBytes,
                        minSeconds: 5,
                      ),
                      CheckboxListTile(
                        value: _consentAccepted,
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        title: const Text(
                          "Je confirme que la personne a compris et accepté l'utilisation de sa voix pour les podcasts CFDT Air France.",
                        ),
                        subtitle: const Text(
                          'Consentement interne – version voice-consent-v1. Un consentement spécifique du fournisseur vocal pourra être demandé lors de la création de la voix synthétique.',
                        ),
                        onChanged: _saving
                            ? null
                            : (value) => setState(
                                () => _consentAccepted = value == true,
                              ),
                      ),
                      const SizedBox(height: 28),
                      _sectionTitle('4. Échantillon de voix'),
                      const SizedBox(height: 10),
                      _instructionCard(
                        icon: Icons.mic_none_rounded,
                        title: 'Texte conseillé',
                        text: _sampleText,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Enregistre dans une pièce calme, à distance constante du micro. Minimum 20 s, idéalement 30 à 60 s.',
                        style: theme.textTheme.bodySmall,
                      ),
                      const SizedBox(height: 12),
                      _recordingRow(
                        kind: _ClipKind.sample,
                        label: 'Échantillon principal',
                        duration: _sampleDuration,
                        bytes: _sampleBytes,
                        minSeconds: 20,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _saving || _recording != null
                        ? null
                        : () => Navigator.of(context).pop(),
                    child: const Text('Annuler'),
                  ),
                  const SizedBox(width: 10),
                  FilledButton.icon(
                    onPressed: _saving || _recording != null ? null : _save,
                    icon: _saving
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_outlined),
                    label: Text(_saving ? 'Enregistrement…' : 'Enregistrer'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: Theme.of(
        context,
      ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
    );
  }

  Widget _instructionCard({
    required IconData icon,
    required String title,
    required String text,
  }) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: theme.colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 5),
                SelectableText(text),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _microphoneCheckCard() {
    final theme = Theme.of(context);
    final result = _microphoneCheck;
    final ready = result?.isReady == true;
    final blocked = result != null && !ready;
    final inputLevel = ready ? result!.inputLevel : 0.0;

    final IconData icon;
    final String title;
    final String message;

    if (_checkingMicrophone) {
      icon = Icons.mic_none_rounded;
      title = 'Vérification en cours…';
      message = 'La console teste brièvement l’accès au microphone.';
    } else if (ready) {
      icon = Icons.check_circle_rounded;
      title = result!.title;
      message = result.message;
    } else if (blocked) {
      icon = Icons.mic_off_rounded;
      title = result.title;
      message = result.message;
    } else {
      icon = Icons.mic_none_rounded;
      title = 'Microphone à vérifier';
      message =
          'Avant tout enregistrement, vérifie que le navigateur et le '
          'système autorisent correctement le microphone.';
    }

    final statusColor = ready
        ? theme.colorScheme.primary
        : blocked
        ? theme.colorScheme.error
        : theme.colorScheme.secondary;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: statusColor.withValues(alpha: 0.45)),
        borderRadius: BorderRadius.circular(14),
        color: statusColor.withValues(alpha: 0.06),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_checkingMicrophone)
                SizedBox.square(
                  dimension: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: statusColor,
                  ),
                )
              else
                Icon(icon, color: statusColor),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: statusColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(message),
                  ],
                ),
              ),
            ],
          ),
          if (ready) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                const Icon(Icons.graphic_eq_rounded, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(
                      minHeight: 8,
                      value: inputLevel.clamp(0.0, 1.0).toDouble(),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '${(inputLevel * 100).round()} %',
                  style: theme.textTheme.labelMedium,
                ),
              ],
            ),
            const SizedBox(height: 5),
            Text(
              'Niveau détecté pendant le test instantané.',
              style: theme.textTheme.bodySmall,
            ),
          ],
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              FilledButton.tonalIcon(
                onPressed: _saving || _recording != null || _checkingMicrophone
                    ? null
                    : _checkMicrophone,
                icon: const Icon(Icons.mic_rounded),
                label: Text(
                  result == null
                      ? 'Vérifier mon microphone'
                      : 'Tester à nouveau',
                ),
              ),
              OutlinedButton.icon(
                onPressed: _checkingMicrophone
                    ? null
                    : () => setState(
                        () => _showMicrophoneHelp = !_showMicrophoneHelp,
                      ),
                icon: const Icon(Icons.help_outline_rounded),
                label: Text(
                  _showMicrophoneHelp ? 'Masquer l’aide' : 'Afficher l’aide',
                ),
              ),
            ],
          ),
          if (_showMicrophoneHelp || blocked) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Comment autoriser le microphone',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  SelectableText(_microphoneHelpText()),
                  if (blocked &&
                      (result.technicalDetails?.trim().isNotEmpty ??
                          false)) ...[
                    const SizedBox(height: 10),
                    ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      childrenPadding: EdgeInsets.zero,
                      title: const Text('Détail technique'),
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: SelectableText(result.technicalDetails!),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _recordingRow({
    required _ClipKind kind,
    required String label,
    required Duration duration,
    required Uint8List? bytes,
    required int minSeconds,
  }) {
    final recordingThis = _recording == kind;
    final recordingOther = _recording != null && !recordingThis;
    final shownDuration = recordingThis ? _recordingElapsed : duration;
    final ready = bytes != null && duration.inSeconds >= minSeconds;

    return Wrap(
      spacing: 10,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        FilledButton.tonalIcon(
          onPressed: _saving || recordingOther || !_microphoneReady
              ? null
              : () => _toggleRecording(kind),
          icon: Icon(recordingThis ? Icons.stop_rounded : Icons.mic_rounded),
          label: Text(recordingThis ? 'Arrêter' : 'Enregistrer $label'),
        ),
        OutlinedButton.icon(
          onPressed: bytes == null || _recording != null || _saving
              ? null
              : () => _play(bytes),
          icon: const Icon(Icons.play_arrow_rounded),
          label: const Text('Écouter'),
        ),
        Chip(
          avatar: Icon(
            recordingThis
                ? Icons.fiber_manual_record_rounded
                : ready
                ? Icons.check_circle_outline
                : Icons.schedule,
            size: 18,
          ),
          label: Text(
            '${_formatDuration(shownDuration)}'
            '${ready ? ' • prêt' : ' • min ${minSeconds}s'}',
          ),
        ),
      ],
    );
  }

  Widget _textField({
    required TextEditingController controller,
    required String label,
    String? hint,
    bool required = false,
  }) {
    return TextFormField(
      controller: controller,
      enabled: !_saving,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: const OutlineInputBorder(),
      ),
      validator: required
          ? (value) => (value ?? '').trim().isEmpty ? 'Champ obligatoire' : null
          : null,
    );
  }

  String _formatDuration(Duration value) {
    final minutes = value.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}
