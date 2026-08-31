import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RhAiAdminPage extends StatefulWidget {
  const RhAiAdminPage({super.key});

  @override
  State<RhAiAdminPage> createState() => _RhAiAdminPageState();
}

class _RhAiAdminPageState extends State<RhAiAdminPage> {
  final _supa = Supabase.instance.client;

  bool _loading = true;
  bool _deepScanning = false;
  bool _syncing = false;
  String? _error;
  String? _syncMessage;
  double _syncProgress = 0;

  int _documents = 0;
  int _chunks = 0;
  int _storagePdfs = 0;
  DateTime? _lastIndex;

  List<String> _storagePaths = const [];
  List<String> _candidateFiles = const [];
  List<String> _missingFiles = const [];
  List<_ScanResult> _scanResults = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<List<String>> _storagePdfPaths([String path = '']) async {
    final out = <String>[];
    final items = await _supa.storage
        .from('Accords_AF')
        .list(path: path, searchOptions: const SearchOptions(limit: 5000));

    for (final item in items) {
      final name = item.name;
      if (name.startsWith('.') || name.startsWith('._')) continue;
      final full = path.isEmpty ? name : '$path/$name';

      if (name.toLowerCase().endsWith('.pdf')) {
        out.add('Accords_AF/$full');
      } else if ((item.metadata?['mimetype'] == null) && !name.contains('.')) {
        out.addAll(await _storagePdfPaths(full));
      }
    }
    return out;
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _syncMessage = null;
      _scanResults = const [];
    });

    try {
      final docs = await _supa
          .from('rh_ai_documents')
          .select('file_path,indexed_at,is_active')
          .eq('is_active', true);
      final chunkRows = await _supa.from('rh_ai_chunks').select('id');
      final storage = await _storagePdfPaths();

      final indexed = <String>{};
      DateTime? latest;
      for (final d in (docs as List)) {
        final path = (d['file_path'] ?? '').toString();
        if (path.isNotEmpty) indexed.add(path);
        final dt = DateTime.tryParse((d['indexed_at'] ?? '').toString());
        if (dt != null && (latest == null || dt.isAfter(latest))) latest = dt;
      }

      final storageSet = storage.toSet();
      if (!mounted) return;
      setState(() {
        _documents = docs.length;
        _chunks = (chunkRows as List).length;
        _storagePdfs = storage.length;
        _storagePaths = storage..sort();
        _lastIndex = latest;
        _candidateFiles = (storageSet.difference(indexed).toList()..sort());
        _missingFiles = (indexed.difference(storageSet).toList()..sort());
        _loading = false;
      });

      if (_candidateFiles.isNotEmpty) await _analyseCandidates();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _analyseCandidates({bool full = false}) async {
    final paths = full ? _storagePaths : _candidateFiles;
    if (paths.isEmpty) return;

    setState(() {
      _deepScanning = true;
      _error = null;
      _syncMessage = full ? 'Analyse complète des empreintes SHA-256…' : null;
    });

    try {
      final all = <_ScanResult>[];
      // La fonction accepte 40 chemins maximum par appel.
      for (var i = 0; i < paths.length; i += 40) {
        final end = (i + 40 < paths.length) ? i + 40 : paths.length;
        final response = await _supa.functions.invoke(
          'rh-ai-scan',
          body: {'paths': paths.sublist(i, end)},
        );
        final data = response.data;
        if (data is! Map || data['ok'] != true) {
          throw Exception(
            data is Map ? data['message'] : 'Réponse serveur invalide',
          );
        }
        all.addAll(
          (data['results'] as List? ?? const []).map(
            (e) => _ScanResult.fromMap(Map<String, dynamic>.from(e as Map)),
          ),
        );
      }

      if (!mounted) return;
      setState(() {
        _scanResults = all;
        _deepScanning = false;
        _syncMessage = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Analyse SHA-256 : $e';
        _deepScanning = false;
      });
    }
  }

  List<_ScanResult> get _duplicates =>
      _scanResults.where((e) => e.status == 'duplicate').toList();
  List<_ScanResult> get _newDocs =>
      _scanResults.where((e) => e.status == 'new').toList();
  List<_ScanResult> get _modified =>
      _scanResults.where((e) => e.status == 'modified').toList();
  List<_ScanResult> get _scanErrors =>
      _scanResults.where((e) => e.status == 'error').toList();

  int get _realChanges =>
      _newDocs.length + _modified.length + _missingFiles.length;

  Future<void> _sync() async {
    if (_realChanges == 0 || _syncing) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Synchroniser l’Assistant RH ?'),
        content: Text(
          '${_newDocs.length} nouveau(x), ${_modified.length} modifié(s) et '
          '${_missingFiles.length} supprimé(s) seront appliqués.\n\n'
          'Les suppressions retirent immédiatement le document de l’index IA.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Synchroniser'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() {
      _syncing = true;
      _syncProgress = 0;
      _error = null;
      _syncMessage = 'Préparation de la synchronisation…';
    });

    final jobs = <_ScanResult>[..._newDocs, ..._modified];
    final totalSteps = jobs.length + _missingFiles.length;
    var done = 0;
    var indexed = 0;
    var deleted = 0;
    final failures = <String>[];

    try {
      // 1. Suppressions : désactivation de l’index et suppression de ses chunks.
      for (final path in _missingFiles) {
        setState(() => _syncMessage = 'Suppression de l’index : $path');
        try {
          final r = await _supa.functions.invoke(
            'rh-index-text',
            body: {'operation': 'deactivate', 'file_path': path},
          );
          final d = r.data;
          if (d is! Map || d['ok'] != true) {
            throw Exception(d is Map ? d['message'] : 'Réponse invalide');
          }
          deleted++;
        } catch (e) {
          failures.add('$path — $e');
        }
        done++;
        if (mounted)
          setState(
            () => _syncProgress = totalSteps == 0 ? 1 : done / totalSteps,
          );
      }

      // 2. Nouveaux / modifiés : extraction texte serveur puis embeddings chunk par chunk.
      for (final job in jobs) {
        setState(() => _syncMessage = 'Extraction du PDF : ${job.path}');
        try {
          final extract = await _supa.functions.invoke(
            'rh-ai-extract',
            body: {'path': job.path},
          );
          final data = extract.data;
          if (data is! Map || data['ok'] != true) {
            final code = data is Map ? data['code']?.toString() : null;
            final msg = data is Map ? data['message']?.toString() : null;
            throw Exception(
              '${code ?? 'EXTRACT_ERROR'} : ${msg ?? 'Extraction impossible'}',
            );
          }

          if (data['duplicate'] == true) {
            // Une copie exacte n’a rien à indexer.
            done++;
            if (mounted)
              setState(
                () => _syncProgress = totalSteps == 0 ? 1 : done / totalSteps,
              );
            continue;
          }

          final chunks = (data['chunks'] as List? ?? const [])
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
          if (chunks.isEmpty) throw Exception('Aucun passage exploitable.');

          final prepare = await _supa.functions.invoke(
            'rh-index-text',
            body: {
              'operation': 'prepare',
              'title': data['title'],
              'file_path': job.path,
              'sha256': data['sha256'],
              'category': data['category'],
              'page_count': data['page_count'],
              'expected_chunks': chunks.length,
              'source_type': 'accord',
              'is_active': true,
            },
          );
          final p = prepare.data;
          if (p is! Map || p['ok'] != true) {
            throw Exception(p is Map ? p['message'] : 'Préparation impossible');
          }

          if (p['action'] != 'unchanged') {
            final documentId = p['document_id'].toString();
            for (var i = 0; i < chunks.length; i++) {
              if (mounted) {
                setState(
                  () => _syncMessage =
                      'Indexation ${i + 1}/${chunks.length} : ${data['title']}',
                );
              }
              final c = chunks[i];
              final cr = await _supa.functions.invoke(
                'rh-index-text',
                body: {
                  'operation': 'chunk',
                  'document_id': documentId,
                  'chunk_index': i,
                  'content': c['content'],
                  'page_number': c['page_number'],
                  'article_ref': c['article_ref'],
                },
              );
              final cd = cr.data;
              if (cd is! Map || cd['ok'] != true) {
                throw Exception(
                  cd is Map ? cd['message'] : 'Chunk ${i + 1} impossible',
                );
              }
            }

            final fr = await _supa.functions.invoke(
              'rh-index-text',
              body: {'operation': 'finalize', 'document_id': documentId},
            );
            final fd = fr.data;
            if (fd is! Map || fd['ok'] != true) {
              throw Exception(
                fd is Map ? fd['message'] : 'Finalisation impossible',
              );
            }
          }
          indexed++;
        } catch (e) {
          failures.add('${job.path} — $e');
        }

        done++;
        if (mounted)
          setState(
            () => _syncProgress = totalSteps == 0 ? 1 : done / totalSteps,
          );
      }

      if (!mounted) return;
      setState(() {
        _syncing = false;
        _syncMessage = failures.isEmpty
            ? 'Synchronisation terminée : $indexed document(s) indexé(s), $deleted supprimé(s).'
            : 'Synchronisation terminée avec ${failures.length} erreur(s).';
      });

      if (failures.isNotEmpty && mounted) {
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Erreurs de synchronisation'),
            content: SizedBox(
              width: 700,
              child: SingleChildScrollView(
                child: SelectableText(failures.join('\n\n')),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Fermer'),
              ),
            ],
          ),
        );
      }
      await _load();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _syncing = false;
        _error = 'Synchronisation : $e';
      });
    }
  }

  String _date(DateTime? d) {
    if (d == null) return 'Jamais';
    final x = d.toLocal();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(x.day)}/${two(x.month)}/${x.year} à ${two(x.hour)}:${two(x.minute)}';
  }

  Widget _stat(String title, String value, IconData icon) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Icon(icon, size: 32),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    value,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(title, maxLines: 2, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statsGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = width >= 1050 ? 4 : (width >= 700 ? 2 : 1);
        final itemWidth = (width - (columns - 1) * 14) / columns;
        return Wrap(
          spacing: 14,
          runSpacing: 14,
          children: [
            SizedBox(
              width: itemWidth,
              child: _stat(
                'PDF physiques',
                '$_storagePdfs',
                Icons.picture_as_pdf_outlined,
              ),
            ),
            SizedBox(
              width: itemWidth,
              child: _stat(
                'Documents uniques indexés',
                '$_documents',
                Icons.auto_awesome,
              ),
            ),
            SizedBox(
              width: itemWidth,
              child: _stat('Passages (chunks)', '$_chunks', Icons.segment),
            ),
            SizedBox(
              width: itemWidth,
              child: _stat(
                'Doublons ignorés',
                '${_duplicates.length}',
                Icons.content_copy_outlined,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _pathList(String title, List<String> paths, {IconData? icon}) {
    if (paths.isEmpty) return const SizedBox.shrink();
    return ExpansionTile(
      initiallyExpanded: paths.length <= 5,
      leading: icon == null ? null : Icon(icon),
      title: Text(
        '$title (${paths.length})',
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      children: paths
          .map(
            (p) => Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: SelectableText(p),
              ),
            ),
          )
          .toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final statusReady = !_deepScanning && _scanErrors.isEmpty;
    final upToDate = statusReady && _realChanges == 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Assistant RH IA'),
        actions: [
          IconButton(
            onPressed: _loading || _deepScanning || _syncing ? null : _load,
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualiser',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Erreur : $_error', textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: _load,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Réessayer'),
                    ),
                  ],
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(24),
              children: [
                _statsGrid(),
                const SizedBox(height: 22),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            if (_deepScanning || _syncing)
                              const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                ),
                              )
                            else
                              Icon(
                                upToDate
                                    ? Icons.check_circle
                                    : Icons.warning_amber_rounded,
                              ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _syncing
                                    ? (_syncMessage ?? 'Synchronisation…')
                                    : _deepScanning
                                    ? 'Vérification SHA-256…'
                                    : upToDate
                                    ? 'Index IA à jour'
                                    : '$_realChanges changement(s) réel(s) à traiter',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                            ),
                          ],
                        ),
                        if (_syncing) ...[
                          const SizedBox(height: 12),
                          LinearProgressIndicator(value: _syncProgress),
                        ],
                        const SizedBox(height: 10),
                        Text(
                          'Dernière indexation détectée : ${_date(_lastIndex)}',
                        ),
                        if (_syncMessage != null && !_syncing) ...[
                          const SizedBox(height: 8),
                          Text(_syncMessage!),
                        ],
                        if (_duplicates.isNotEmpty)
                          _pathList(
                            'Doublons exacts ignorés',
                            _duplicates
                                .map(
                                  (e) =>
                                      '${e.path}\n↳ copie de ${e.duplicateOf ?? 'document déjà indexé'}',
                                )
                                .toList(),
                            icon: Icons.content_copy_outlined,
                          ),
                        if (_newDocs.isNotEmpty)
                          _pathList(
                            'Nouveaux documents',
                            _newDocs.map((e) => e.path).toList(),
                            icon: Icons.add_circle_outline,
                          ),
                        if (_modified.isNotEmpty)
                          _pathList(
                            'Documents modifiés',
                            _modified.map((e) => e.path).toList(),
                            icon: Icons.edit_outlined,
                          ),
                        if (_missingFiles.isNotEmpty)
                          _pathList(
                            'Documents supprimés du Storage',
                            _missingFiles,
                            icon: Icons.delete_outline,
                          ),
                        if (_scanErrors.isNotEmpty)
                          _pathList(
                            'Erreurs de vérification',
                            _scanErrors
                                .map(
                                  (e) => '${e.path} — ${e.message ?? 'erreur'}',
                                )
                                .toList(),
                            icon: Icons.error_outline,
                          ),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            FilledButton.icon(
                              onPressed: _deepScanning || _syncing
                                  ? null
                                  : () => _analyseCandidates(full: true),
                              icon: const Icon(Icons.manage_search),
                              label: const Text('Analyser complètement'),
                            ),
                            OutlinedButton.icon(
                              onPressed:
                                  _realChanges == 0 || _deepScanning || _syncing
                                  ? null
                                  : _sync,
                              icon: const Icon(
                                Icons.auto_awesome_motion_outlined,
                              ),
                              label: const Text('Synchroniser l’Assistant RH'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'La synchronisation est volontairement confirmée avant exécution. '
                          'Un PDF image sans couche texte est refusé avec le statut « OCR requis » afin de ne jamais indexer un texte juridique approximatif.',
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _ScanResult {
  final String path;
  final String status;
  final String? duplicateOf;
  final String? message;

  const _ScanResult({
    required this.path,
    required this.status,
    this.duplicateOf,
    this.message,
  });

  factory _ScanResult.fromMap(Map<String, dynamic> map) => _ScanResult(
    path: (map['path'] ?? '').toString(),
    status: (map['status'] ?? '').toString(),
    duplicateOf: map['duplicate_of']?.toString(),
    message: map['message']?.toString(),
  );
}
