import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/podcast_ai_models.dart';
import '../../services/podcast_ai_service.dart';
import '../../services/podcast_voice_service.dart';

class PodcastAiStudioPage extends StatefulWidget {
  const PodcastAiStudioPage({super.key, this.service});

  final PodcastAiStudioService? service;

  @override
  State<PodcastAiStudioPage> createState() => _PodcastAiStudioPageState();
}

class _PodcastAiStudioPageState extends State<PodcastAiStudioPage> {
  late final PodcastAiStudioService _service =
      widget.service ?? SupabasePodcastAiService();
  List<PodcastAiJob> _jobs = const [];
  List<String> _cses = const [];
  PodcastVoiceAccess? _access;
  bool _loading = true;
  String? _error;
  String _status = '';
  String _cse = '';
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final access = await _service.loadAccess();
      final results = await Future.wait<dynamic>([
        _service.allowedCses(),
        _service.loadJobs(),
      ]);
      if (!mounted) return;
      setState(() {
        _access = access;
        _cses = results[0] as List<String>;
        _jobs = results[1] as List<PodcastAiJob>;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Accès refusé ou Studio Podcast indisponible.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<PodcastAiJob> get _visibleJobs {
    final query = _search.text.trim().toLowerCase();
    return _jobs
        .where((job) {
          if (_status.isNotEmpty && job.status != _status) return false;
          if (_cse.isNotEmpty && job.cse != _cse) return false;
          if (query.isNotEmpty &&
              !job.title.toLowerCase().contains(query) &&
              !job.cse.toLowerCase().contains(query)) {
            return false;
          }
          return true;
        })
        .toList(growable: false);
  }

  Future<void> _create() async {
    final created = await showDialog<PodcastAiJob>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _CreatePodcastDialog(
        service: _service,
        cses: _cses,
        access: _access!,
      ),
    );
    if (created != null) {
      await _load();
      if (mounted) await _open(created);
    }
  }

  Future<void> _open(PodcastAiJob job) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _PodcastJobDialog(service: _service, initialJob: job),
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null || _access == null || !_access!.isAdmin) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_outline_rounded, size: 48),
            const SizedBox(height: 12),
            Text(_error ?? 'Accès refusé'),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh),
              label: const Text('Réessayer'),
            ),
          ],
        ),
      );
    }
    final jobs = _visibleJobs;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 16,
              runSpacing: 12,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Studio Podcast',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Projets IA partagés selon votre rôle et votre CSE.',
                    ),
                  ],
                ),
                Wrap(
                  spacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _load,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Actualiser'),
                    ),
                    FilledButton.icon(
                      onPressed: _cses.isEmpty ? null : _create,
                      icon: const Icon(Icons.add),
                      label: const Text('Nouveau podcast'),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: 320,
                  child: TextField(
                    controller: _search,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      labelText: 'Rechercher',
                    ),
                  ),
                ),
                SizedBox(
                  width: 250,
                  child: DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue: _status,
                    decoration: const InputDecoration(labelText: 'Statut'),
                    items: [
                      const DropdownMenuItem(
                        value: '',
                        child: Text('Tous les statuts'),
                      ),
                      ...PodcastAiStatuses.values.map(
                        (s) => DropdownMenuItem(
                          value: s,
                          child: Text(PodcastAiStatuses.label(s)),
                        ),
                      ),
                    ],
                    onChanged: (v) => setState(() => _status = v ?? ''),
                  ),
                ),
                if (_access!.isSuperuser)
                  SizedBox(
                    width: 300,
                    child: DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: _cse,
                      decoration: const InputDecoration(labelText: 'CSE'),
                      items: [
                        const DropdownMenuItem(
                          value: '',
                          child: Text('Tous les CSE'),
                        ),
                        ..._cses.map(
                          (c) => DropdownMenuItem(value: c, child: Text(c)),
                        ),
                      ],
                      onChanged: (v) => setState(() => _cse = v ?? ''),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: jobs.isEmpty
                  ? const Center(child: Text('Aucun projet dans ce périmètre.'))
                  : LayoutBuilder(
                      builder: (context, constraints) =>
                          constraints.maxWidth >= 980
                          ? _table(jobs)
                          : _cards(jobs),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _table(List<PodcastAiJob> jobs) => Card(
    child: SingleChildScrollView(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: const [
            DataColumn(label: Text('Titre')),
            DataColumn(label: Text('CSE')),
            DataColumn(label: Text('Statut')),
            DataColumn(label: Text('Créateur')),
            DataColumn(label: Text('Source PDF')),
            DataColumn(label: Text('Voix')),
            DataColumn(label: Text('Date')),
            DataColumn(label: Text('Durée')),
            DataColumn(label: Text('Audio')),
            DataColumn(label: Text('Actions')),
          ],
          rows: jobs
              .map(
                (job) => DataRow(
                  cells: [
                    DataCell(
                      SizedBox(
                        width: 190,
                        child: Text(
                          job.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    DataCell(SizedBox(width: 170, child: Text(job.cse))),
                    DataCell(_StatusChip(job.status)),
                    DataCell(Text(_creatorLabel(job.createdBy))),
                    DataCell(
                      SizedBox(
                        width: 150,
                        child: Text(
                          job.sourcePdfName ?? '—',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    DataCell(Text(_voiceSummary(job.voiceConfig))),
                    DataCell(
                      Text(
                        DateFormat(
                          'dd/MM/yyyy HH:mm',
                        ).format(job.createdAt.toLocal()),
                      ),
                    ),
                    DataCell(Text('${job.requestedMinutes} min')),
                    DataCell(
                      Icon(
                        job.hasAudio
                            ? Icons.check_circle_outline
                            : Icons.remove,
                        color: job.hasAudio ? Colors.green : null,
                      ),
                    ),
                    DataCell(
                      IconButton(
                        key: ValueKey('open-${job.id}'),
                        tooltip: 'Ouvrir',
                        onPressed: () => _open(job),
                        icon: const Icon(Icons.open_in_new),
                      ),
                    ),
                  ],
                ),
              )
              .toList(),
        ),
      ),
    ),
  );

  Widget _cards(List<PodcastAiJob> jobs) => ListView.separated(
    itemCount: jobs.length,
    separatorBuilder: (_, _) => const SizedBox(height: 10),
    itemBuilder: (_, index) {
      final job = jobs[index];
      return Card(
        child: ListTile(
          key: ValueKey('open-${job.id}'),
          onTap: () => _open(job),
          leading: const CircleAvatar(child: Icon(Icons.podcasts)),
          title: Text(job.title),
          subtitle: Text(
            '${job.cse}\n${PodcastAiStatuses.label(job.status)} • ${job.requestedMinutes} min • ${job.sourcePdfName ?? 'sans PDF'}',
          ),
          isThreeLine: true,
          trailing: const Icon(Icons.chevron_right),
        ),
      );
    },
  );
}

String _creatorLabel(String id) {
  final clean = id.trim();
  if (clean.isEmpty) return '—';
  return clean.length <= 8 ? clean : '…${clean.substring(clean.length - 8)}';
}

String _voiceSummary(PodcastVoiceConfig config) {
  String one(PodcastSpeakerVoiceConfig voice) =>
      voice.isCustom ? 'personnalisée' : (voice.voice ?? 'standard');
  return '${one(config.speaker1)} / ${one(config.speaker2)}';
}

class _StatusChip extends StatelessWidget {
  const _StatusChip(this.status);
  final String status;
  @override
  Widget build(BuildContext context) => Chip(
    label: Text(PodcastAiStatuses.label(status)),
    visualDensity: VisualDensity.compact,
  );
}

class _CreatePodcastDialog extends StatefulWidget {
  const _CreatePodcastDialog({
    required this.service,
    required this.cses,
    required this.access,
  });
  final PodcastAiStudioService service;
  final List<String> cses;
  final PodcastVoiceAccess access;
  @override
  State<_CreatePodcastDialog> createState() => _CreatePodcastDialogState();
}

class _CreatePodcastDialogState extends State<_CreatePodcastDialog> {
  final _title = TextEditingController();
  PlatformFile? _pdf;
  late String _cse = widget.access.isSuperuser
      ? widget.cses.first
      : widget.access.cse;
  int _minutes = 5;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
      withData: true,
    );
    if (result != null && mounted) setState(() => _pdf = result.files.single);
  }

  Future<void> _submit() async {
    if (_busy) return;
    if (_title.text.trim().isEmpty || _pdf == null) {
      setState(() => _error = 'Renseignez le titre et choisissez un PDF.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final job = await widget.service.createFromPdf(
        title: _title.text,
        cse: _cse,
        requestedMinutes: _minutes,
        pdf: _pdf!,
      );
      if (mounted) Navigator.of(context).pop(job);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Création ou import du PDF impossible.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Nouveau podcast IA'),
    content: SizedBox(
      width: 560,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _title,
              enabled: !_busy,
              decoration: const InputDecoration(labelText: 'Titre'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _cse,
              decoration: const InputDecoration(labelText: 'CSE'),
              items: widget.cses
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: _busy || !widget.access.isSuperuser
                  ? null
                  : (v) => setState(() => _cse = v!),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: Text(_pdf?.name ?? 'Aucun PDF sélectionné')),
                OutlinedButton.icon(
                  onPressed: _busy ? null : _pick,
                  icon: const Icon(Icons.picture_as_pdf),
                  label: const Text('Choisir'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: Text('Durée demandée : $_minutes minutes')),
                Expanded(
                  child: Slider(
                    value: _minutes.toDouble(),
                    min: 2,
                    max: 10,
                    divisions: 8,
                    onChanged: _busy
                        ? null
                        : (v) => setState(() => _minutes = v.round()),
                  ),
                ),
              ],
            ),
            if (_error != null)
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: _busy ? null : () => Navigator.pop(context),
        child: const Text('Annuler'),
      ),
      FilledButton(
        onPressed: _busy ? null : _submit,
        child: _busy
            ? const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Text('Créer'),
      ),
    ],
  );
}

class _PodcastJobDialog extends StatefulWidget {
  const _PodcastJobDialog({required this.service, required this.initialJob});
  final PodcastAiStudioService service;
  final PodcastAiJob initialJob;
  @override
  State<_PodcastJobDialog> createState() => _PodcastJobDialogState();
}

class _PodcastJobDialogState extends State<_PodcastJobDialog> {
  late PodcastAiJob _job = widget.initialJob;
  late final _title = TextEditingController(text: _job.title);
  late final _script = TextEditingController(
    text: _job.voiceConfig.displayScript(_job.script ?? ''),
  );
  final _player = AudioPlayer();
  List<PodcastAiVoiceOption> _voices = const [];
  late PodcastSpeakerVoiceConfig _speaker1 = _job.voiceConfig.speaker1;
  late PodcastSpeakerVoiceConfig _speaker2 = _job.voiceConfig.speaker2;
  final Set<String> _busy = <String>{};
  bool _playing = false;
  bool _disposed = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadVoices();
    _player.onPlayerStateChanged.listen((s) {
      if (mounted) setState(() => _playing = s == PlayerState.playing);
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _title.dispose();
    _script.dispose();
    _player.dispose();
    super.dispose();
  }

  Future<void> _loadVoices() async {
    try {
      final voices = await widget.service.loadReadyVoices(_job.cse);
      if (mounted) setState(() => _voices = voices);
    } catch (_) {}
  }

  Future<void> _run(String key, Future<void> Function() action) async {
    if (_busy.contains(key)) return;
    setState(() {
      _busy.add(key);
      _error = null;
    });
    try {
      await action();
    } catch (_) {
      if (mounted) setState(() => _error = _messageFor(key));
    } finally {
      if (mounted) setState(() => _busy.remove(key));
    }
  }

  String _messageFor(String key) => switch (key) {
    'source' => 'Source indisponible.',
    'script' => 'Génération du script impossible.',
    'audio' => 'Génération audio impossible.',
    'publish' => 'Publication impossible ou job déjà publié.',
    'delete' => 'Suppression non autorisée.',
    _ => 'Modification impossible.',
  };

  Future<void> _refresh() async {
    final job = await widget.service.loadJob(_job.id);
    if (mounted) _setJob(job);
  }

  void _setJob(PodcastAiJob job) {
    setState(() {
      _job = job;
      _title.text = job.title;
      _script.text = job.voiceConfig.displayScript(job.script ?? '');
      _speaker1 = job.voiceConfig.speaker1;
      _speaker2 = job.voiceConfig.speaker2;
    });
  }

  Future<void> _source() => _run('source', () async {
    final url = await widget.service.getSourceUrl(_job.id);
    if (!await launchUrl(Uri.parse(url), webOnlyWindowName: '_blank')) {
      throw StateError('open');
    }
  });

  PodcastVoiceConfig get _selectedVoices =>
      PodcastVoiceConfig(version: 1, speaker1: _speaker1, speaker2: _speaker2);

  Future<void> _generateScript() => _run('script', () async {
    final selected = _selectedVoices;
    final generated = await widget.service.generateScript(_job.id);
    final saved = await widget.service.saveScript(
      jobId: generated.id,
      title: _title.text,
      script: generated.script ?? '',
      voiceConfig: selected,
    );
    _setJob(saved);
  });
  Future<void> _save() => _run(
    'save',
    () async => _setJob(
      await widget.service.saveScript(
        jobId: _job.id,
        title: _title.text,
        script: _selectedVoices.canonicalScript(_script.text),
        voiceConfig: _selectedVoices,
      ),
    ),
  );

  Future<void> _audio() => _run('audio', () async {
    final selected = _selectedVoices;
    final saved = await persistVoicesBeforeAudio(
      service: widget.service,
      job: _job,
      title: _title.text,
      canonicalScript: selected.canonicalScript(_script.text),
      selectedVoices: selected,
    );
    _setJob(saved);
    await _pollAudio();
  });

  Future<void> _pollAudio() async {
    for (var i = 0; i < 24 && !_disposed; i++) {
      await Future<void>.delayed(const Duration(seconds: 5));
      if (_disposed) return;
      final job = await widget.service.loadJob(_job.id);
      if (mounted) _setJob(job);
      if (job.status == PodcastAiStatuses.ready ||
          job.status == PodcastAiStatuses.failed ||
          job.status == PodcastAiStatuses.published) {
        return;
      }
    }
    throw const PodcastAiException(
      'La génération continue en arrière-plan. Actualisez plus tard.',
    );
  }

  Future<void> _play() async {
    final url = (_job.audioUrl ?? '').trim();
    if (url.isEmpty) {
      setState(() => _error = 'Audio indisponible.');
      return;
    }
    if (_playing) {
      await _player.pause();
    } else if (_player.state == PlayerState.paused) {
      await _player.resume();
    } else {
      await _player.play(UrlSource(url));
    }
  }

  Future<void> _publish() => _run(
    'publish',
    () async => _setJob(await widget.service.publish(_job.id)),
  );

  Future<void> _delete() async {
    if (_busy.contains('delete')) return;
    final ok =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Supprimer ce brouillon ?'),
            content: const Text('Cette action est définitive.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Annuler'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Supprimer'),
              ),
            ],
          ),
        ) ??
        false;
    if (!ok || !mounted) return;
    await _run('delete', () async {
      await widget.service.deleteJob(_job.id);
      if (mounted) Navigator.pop(context);
    });
  }

  bool get _anyBusy => _busy.isNotEmpty;

  @override
  Widget build(BuildContext context) => Dialog.fullscreen(
    child: Scaffold(
      appBar: AppBar(
        title: Text(_job.title),
        leading: IconButton(
          onPressed: _anyBusy ? null : () => Navigator.pop(context),
          icon: const Icon(Icons.close),
        ),
        actions: [
          IconButton(
            tooltip: 'Actualiser',
            onPressed: _anyBusy ? null : () => _run('refresh', _refresh),
            icon: const Icon(Icons.refresh),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1050),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _StatusChip(_job.status),
                    Chip(label: Text(_job.cse)),
                    Chip(label: Text('${_job.requestedMinutes} min')),
                    Chip(label: Text(_job.sourcePdfName ?? 'Sans PDF')),
                  ],
                ),
                if ((_job.errorMessage ?? '').isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Card(
                    color: Theme.of(context).colorScheme.errorContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        'Erreur de génération : ${_job.errorMessage}',
                      ),
                    ),
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Source et script',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _title,
                          enabled: !_anyBusy && !_job.isPublished,
                          decoration: const InputDecoration(labelText: 'Titre'),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _script,
                          enabled: !_anyBusy && !_job.isPublished,
                          minLines: 10,
                          maxLines: 24,
                          decoration: const InputDecoration(
                            labelText: 'Script Camille / Alex',
                            alignLabelWithHint: true,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            OutlinedButton.icon(
                              onPressed:
                                  _anyBusy || (_job.sourcePdfPath ?? '').isEmpty
                                  ? null
                                  : _source,
                              icon: const Icon(Icons.picture_as_pdf),
                              label: const Text('Ouvrir le PDF'),
                            ),
                            OutlinedButton.icon(
                              onPressed: _anyBusy || _job.isPublished
                                  ? null
                                  : _generateScript,
                              icon: const Icon(Icons.auto_awesome),
                              label: const Text('Générer le script'),
                            ),
                            FilledButton.icon(
                              onPressed:
                                  _anyBusy ||
                                      _job.isPublished ||
                                      _script.text.trim().isEmpty
                                  ? null
                                  : _save,
                              icon: const Icon(Icons.save),
                              label: const Text('Enregistrer'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Voix et audio',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _voiceSelector(
                          'Camille',
                          'Kore',
                          _speaker1,
                          (v) => _changeVoice(1, v),
                        ),
                        const SizedBox(height: 12),
                        _voiceSelector(
                          'Alex',
                          'Puck',
                          _speaker2,
                          (v) => _changeVoice(2, v),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'Voix 1 : ${_speaker1.label} — ${_speaker1.provider == 'elevenlabs' ? 'ElevenLabs' : 'Gemini'}\n'
                          'Voix 2 : ${_speaker2.label} — ${_speaker2.provider == 'elevenlabs' ? 'ElevenLabs' : 'Gemini'}',
                          key: const ValueKey('audio-voice-summary'),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            FilledButton.icon(
                              onPressed:
                                  _anyBusy ||
                                      _job.isPublished ||
                                      _script.text.trim().isEmpty
                                  ? null
                                  : _audio,
                              icon: const Icon(Icons.graphic_eq),
                              label: Text(
                                _job.status == PodcastAiStatuses.generatingAudio
                                    ? 'Génération en cours…'
                                    : 'Générer l’audio',
                              ),
                            ),
                            OutlinedButton.icon(
                              onPressed: _anyBusy || !_job.hasAudio
                                  ? null
                                  : _play,
                              icon: Icon(
                                _playing ? Icons.pause : Icons.play_arrow,
                              ),
                              label: Text(_playing ? 'Pause' : 'Écouter'),
                            ),
                            FilledButton.icon(
                              onPressed:
                                  _anyBusy ||
                                      _job.status != PodcastAiStatuses.ready
                                  ? null
                                  : _publish,
                              icon: const Icon(Icons.publish),
                              label: const Text('Publier'),
                            ),
                            OutlinedButton.icon(
                              onPressed: _anyBusy || !_job.canDelete
                                  ? null
                                  : _delete,
                              icon: const Icon(Icons.delete_outline),
                              label: const Text('Supprimer'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  Widget _voiceSelector(
    String speaker,
    String standard,
    PodcastSpeakerVoiceConfig current,
    ValueChanged<PodcastSpeakerVoiceConfig> changed,
  ) {
    final key = current.isCustom
        ? 'custom:${current.customVoiceId}'
        : 'standard';
    final items = <DropdownMenuItem<String>>[
      DropdownMenuItem(
        value: 'standard',
        child: Text('Voix standard • $standard'),
      ),
      ..._voices.map(
        (v) => DropdownMenuItem(
          value: 'custom:${v.id}',
          child: Text('${v.displayName} • ${v.provider}'),
        ),
      ),
    ];
    if (key != 'standard' && !items.any((i) => i.value == key)) {
      items.add(
        DropdownMenuItem(
          value: key,
          child: const Text('Voix personnalisée indisponible'),
        ),
      );
    }
    return DropdownButtonFormField<String>(
      initialValue: key,
      decoration: InputDecoration(labelText: 'Voix de $speaker'),
      items: items,
      onChanged: _anyBusy || _job.isPublished
          ? null
          : (value) {
              if (value == 'standard') {
                changed(
                  PodcastSpeakerVoiceConfig.standard(
                    speaker: speaker,
                    standardVoice: standard,
                  ),
                );
                return;
              }
              final id = value?.replaceFirst('custom:', '');
              final voice = _voices.where((v) => v.id == id).firstOrNull;
              if (voice != null) {
                changed(
                  PodcastSpeakerVoiceConfig.custom(
                    speaker: speaker,
                    option: voice,
                  ),
                );
              }
            },
    );
  }

  void _changeVoice(int slot, PodcastSpeakerVoiceConfig value) {
    final canonical = _selectedVoices.canonicalScript(_script.text);
    setState(() {
      if (slot == 1) {
        _speaker1 = value;
      } else {
        _speaker2 = value;
      }
      _script.text = _selectedVoices.displayScript(canonical);
    });
  }
}
