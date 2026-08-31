import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import '../../models/podcast_voice.dart';
import '../../services/podcast_voice_service.dart';
import 'podcast_voice_editor_dialog.dart';

class PodcastVoiceAdminPage extends StatefulWidget {
  const PodcastVoiceAdminPage({super.key});

  @override
  State<PodcastVoiceAdminPage> createState() => _PodcastVoiceAdminPageState();
}

class _PodcastVoiceAdminPageState extends State<PodcastVoiceAdminPage> {
  final PodcastVoiceService _service = PodcastVoiceService();
  final AudioPlayer _player = AudioPlayer();

  List<PodcastVoice> _voices = const [];
  List<String> _allowedCses = const [];
  bool _loading = true;
  String? _error;
  static const String _allCses = '__ALL_CSE__';
  String _selectedCseFilter = _allCses;
  String? _playingVoiceId;
  final Set<String> _workingIds = <String>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      if (_allowedCses.isEmpty) {
        _allowedCses = await _service.allowedCses();
      }
      final voices = await _service.listVoices(
        cse: _selectedCseFilter == _allCses ? null : _selectedCseFilter,
      );
      if (!mounted) return;
      setState(() => _voices = voices);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _createVoice() async {
    final created = await showDialog<PodcastVoice>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PodcastVoiceEditorDialog(
        service: _service,
        allowedCses: _allowedCses,
      ),
    );
    if (created != null) {
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Voix « ${created.displayName} » enregistrée pour ${created.cse}.',
          ),
        ),
      );
    }
  }

  Future<void> _play(PodcastVoice voice) async {
    if (_workingIds.contains(voice.id)) return;
    setState(() {
      _workingIds.add(voice.id);
      _playingVoiceId = voice.id;
    });
    try {
      final url = await _service.createSampleSignedUrl(voice);
      await _player.stop();
      await _player.play(UrlSource(url));
    } catch (error) {
      _showError('Lecture impossible : $error');
    } finally {
      if (mounted) {
        setState(() => _workingIds.remove(voice.id));
      }
    }
  }

  Future<void> _toggleActive(PodcastVoice voice, bool value) async {
    if (_workingIds.contains(voice.id)) return;
    setState(() => _workingIds.add(voice.id));
    try {
      await _service.setActive(voice, value);
      await _load();
    } catch (error) {
      _showError('Mise à jour impossible : $error');
    } finally {
      if (mounted) setState(() => _workingIds.remove(voice.id));
    }
  }

  Future<void> _delete(PodcastVoice voice) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer cette voix ?'),
        content: Text(
          'La voix « ${voice.displayName} » (${voice.cse}) ainsi que ses '
          'enregistrements privés seront supprimés. Cette action est définitive.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _workingIds.add(voice.id));
    try {
      await _service.deleteVoice(voice);
      await _load();
    } catch (error) {
      _showError('Suppression impossible : $error');
    } finally {
      if (mounted) setState(() => _workingIds.remove(voice.id));
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

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 720;
                final title = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Voix Podcast',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Bibliothèque privée des voix, classée par CSE.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                );
                final button = FilledButton.icon(
                  onPressed: _loading ? null : _createVoice,
                  icon: const Icon(Icons.mic_rounded),
                  label: const Text('Enregistrer une voix'),
                );
                if (compact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [title, const SizedBox(height: 14), button],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: title),
                    const SizedBox(width: 16),
                    button,
                  ],
                );
              },
            ),
            const SizedBox(height: 18),
            _filterBar(),
            const SizedBox(height: 16),
            Expanded(child: _body()),
          ],
        ),
      ),
    );
  }

  Widget _filterBar() {
    return Wrap(
      spacing: 12,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 320,
          child: DropdownButtonFormField<String>(
            initialValue: _selectedCseFilter,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Filtrer par CSE',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            items: <DropdownMenuItem<String>>[
              const DropdownMenuItem<String>(
                value: _allCses,
                child: Text('Tous les CSE autorisés'),
              ),
              ..._allowedCses.map(
                (cse) => DropdownMenuItem<String>(value: cse, child: Text(cse)),
              ),
            ],
            onChanged: _loading
                ? null
                : (value) {
                    if (value == null) return;
                    setState(() => _selectedCseFilter = value);
                    _load();
                  },
          ),
        ),
        OutlinedButton.icon(
          onPressed: _loading ? null : _load,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Actualiser'),
        ),
        Chip(label: Text('${_voices.length} voix')),
      ],
    );
  }

  Widget _body() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, size: 42),
              const SizedBox(height: 10),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Réessayer'),
              ),
            ],
          ),
        ),
      );
    }
    if (_voices.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.mic_none_rounded, size: 54),
            const SizedBox(height: 12),
            const Text('Aucune voix enregistrée pour ce périmètre.'),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _allowedCses.isEmpty ? null : _createVoice,
              icon: const Icon(Icons.add),
              label: const Text('Ajouter la première voix'),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      itemCount: _voices.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) => _voiceCard(_voices[index]),
    );
  }

  Widget _voiceCard(PodcastVoice voice) {
    final theme = Theme.of(context);
    final working = _workingIds.contains(voice.id);
    final consentOk = voice.consentAccepted && voice.consentAt != null;

    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 760;
            final identity = Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 24,
                  child: Text(
                    voice.displayName.isEmpty
                        ? '?'
                        : voice.displayName.substring(0, 1).toUpperCase(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        voice.displayName,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if ((voice.roleLabel ?? '').isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(voice.roleLabel!),
                      ],
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 7,
                        runSpacing: 7,
                        children: [
                          Chip(
                            avatar: const Icon(
                              Icons.apartment_rounded,
                              size: 16,
                            ),
                            label: Text(voice.cse),
                          ),
                          Chip(
                            avatar: Icon(
                              consentOk
                                  ? Icons.verified_outlined
                                  : Icons.warning_amber_rounded,
                              size: 16,
                            ),
                            label: Text(
                              consentOk
                                  ? 'Consentement OK'
                                  : 'Consentement incomplet',
                            ),
                          ),
                          Chip(
                            avatar: const Icon(
                              Icons.graphic_eq_rounded,
                              size: 16,
                            ),
                            label: Text(voice.providerStatusLabel),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            );

            final actions = Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              alignment: compact ? WrapAlignment.start : WrapAlignment.end,
              children: [
                OutlinedButton.icon(
                  onPressed: working ? null : () => _play(voice),
                  icon: Icon(
                    _playingVoiceId == voice.id
                        ? Icons.volume_up_rounded
                        : Icons.play_arrow_rounded,
                  ),
                  label: const Text('Écouter'),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Active'),
                    Switch(
                      value: voice.isActive,
                      onChanged: working
                          ? null
                          : (value) => _toggleActive(voice, value),
                    ),
                  ],
                ),
                IconButton(
                  tooltip: 'Supprimer',
                  onPressed: working ? null : () => _delete(voice),
                  icon: const Icon(Icons.delete_outline_rounded),
                ),
              ],
            );

            if (compact) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [identity, const SizedBox(height: 12), actions],
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(child: identity),
                const SizedBox(width: 16),
                actions,
              ],
            );
          },
        ),
      ),
    );
  }
}
