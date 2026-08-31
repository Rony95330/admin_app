import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../services/election_service.dart';

class AdminElectionCampaignEditorPage extends StatefulWidget {
  const AdminElectionCampaignEditorPage({super.key, required this.campaignId});

  final String campaignId;

  @override
  State<AdminElectionCampaignEditorPage> createState() =>
      _AdminElectionCampaignEditorPageState();
}

class _AdminElectionCampaignEditorPageState
    extends State<AdminElectionCampaignEditorPage>
    with SingleTickerProviderStateMixin {
  final ElectionService _service = ElectionService();
  late final TabController _tabs;

  Map<String, dynamic>? _campaign;
  List<Map<String, dynamic>> _publications = const [];
  List<Map<String, dynamic>> _sections = const [];
  List<Map<String, dynamic>> _candidates = const [];
  List<String> _cseOptions = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 5, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final results = await Future.wait<Object>([
        _service.adminGetCampaign(widget.campaignId),
        _service.adminListPublications(widget.campaignId),
        _service.adminListSections(widget.campaignId),
        _service.adminListCandidates(widget.campaignId),
        _service.adminListCse(),
      ]);
      if (!mounted) return;
      setState(() {
        _campaign = Map<String, dynamic>.from(results[0] as Map);
        _publications = List<Map<String, dynamic>>.from(results[1] as List);
        _sections = List<Map<String, dynamic>>.from(results[2] as List);
        _candidates = List<Map<String, dynamic>>.from(results[3] as List);
        _cseOptions = List<String>.from(results[4] as List);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _saveCampaign(Map<String, dynamic> payload) async {
    await _service.adminUpdateCampaign(widget.campaignId, payload);
    await _load();
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Campagne enregistrée.')));
  }

  @override
  Widget build(BuildContext context) {
    final title = _campaign?['title']?.toString() ?? 'Campagne électorale';

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          tabs: const [
            Tab(icon: Icon(Icons.tune_rounded), text: 'Général'),
            Tab(icon: Icon(Icons.campaign_rounded), text: 'Publications'),
            Tab(icon: Icon(Icons.fact_check_outlined), text: 'Programme'),
            Tab(icon: Icon(Icons.groups_2_outlined), text: 'Candidats'),
            Tab(icon: Icon(Icons.phone_iphone_rounded), text: 'Aperçu'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _ErrorView(message: _error!, onRetry: _load)
          : TabBarView(
              controller: _tabs,
              children: [
                _GeneralTab(
                  campaignId: widget.campaignId,
                  campaign: _campaign!,
                  cseOptions: _cseOptions,
                  service: _service,
                  onSaved: _saveCampaign,
                ),
                _PublicationsTab(
                  campaignId: widget.campaignId,
                  initialPublications: _publications,
                  service: _service,
                  onChanged: _load,
                ),
                _ProgramTab(
                  campaignId: widget.campaignId,
                  initialSections: _sections,
                  service: _service,
                  onChanged: _load,
                ),
                _CandidatesTab(
                  campaignId: widget.campaignId,
                  initialCandidates: _candidates,
                  service: _service,
                  onChanged: _load,
                ),
                _PreviewTab(
                  campaign: _campaign!,
                  publications: _publications,
                  candidates: _candidates,
                ),
              ],
            ),
    );
  }
}

class _GeneralTab extends StatefulWidget {
  const _GeneralTab({
    required this.campaignId,
    required this.campaign,
    required this.cseOptions,
    required this.service,
    required this.onSaved,
  });

  final String campaignId;
  final Map<String, dynamic> campaign;
  final List<String> cseOptions;
  final ElectionService service;
  final Future<void> Function(Map<String, dynamic>) onSaved;

  @override
  State<_GeneralTab> createState() => _GeneralTabState();
}

class _GeneralTabState extends State<_GeneralTab> {
  late final TextEditingController _title;
  late final TextEditingController _slug;
  late final TextEditingController _subtitle;
  late final TextEditingController _intro;
  late final TextEditingController _cse;
  late final TextEditingController _year;
  late final TextEditingController _voteStart;
  late final TextEditingController _voteEnd;
  late final TextEditingController _displayStart;
  late final TextEditingController _displayEnd;
  late final TextEditingController _cta;

  late String _scope;
  late String _status;
  late int _homePosition;
  late bool _active;
  String? _heroUrl;
  String? _heroStoragePath;
  bool _uploadingHero = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final c = widget.campaign;
    _title = TextEditingController(text: c['title']?.toString() ?? '');
    _slug = TextEditingController(text: c['slug']?.toString() ?? '');
    _subtitle = TextEditingController(text: c['subtitle']?.toString() ?? '');
    _intro = TextEditingController(text: c['intro_text']?.toString() ?? '');
    _cse = TextEditingController(text: c['cse_code']?.toString() ?? '');
    _year = TextEditingController(text: c['election_year']?.toString() ?? '');
    _voteStart = TextEditingController(text: _dateOnly(c['vote_start_at']));
    _voteEnd = TextEditingController(text: _dateOnly(c['vote_end_at']));
    _displayStart = TextEditingController(
      text: _dateOnly(c['display_start_at']),
    );
    _displayEnd = TextEditingController(text: _dateOnly(c['display_end_at']));
    _cta = TextEditingController(
      text: c['home_card_cta']?.toString() ?? 'Découvrir la campagne',
    );
    _scope = c['scope_level']?.toString() ?? 'CSE';
    _status = c['status']?.toString() ?? 'draft';
    _homePosition = (c['home_position'] as num?)?.toInt() ?? 1;
    _active = c['is_active'] == true;
    _heroUrl = _nullIfEmpty(c['hero_image_url']?.toString() ?? '');
    _heroStoragePath = _nullIfEmpty(c['hero_storage_path']?.toString() ?? '');
  }

  @override
  void dispose() {
    for (final controller in [
      _title,
      _slug,
      _subtitle,
      _intro,
      _cse,
      _year,
      _voteStart,
      _voteEnd,
      _displayStart,
      _displayEnd,
      _cta,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _pickHero() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.single;
    final bytes = file.bytes;
    if (bytes == null) {
      _snack('Impossible de lire ce fichier.');
      return;
    }

    setState(() => _uploadingHero = true);
    try {
      final uploaded = await widget.service.uploadCampaignFile(
        campaignId: widget.campaignId,
        category: 'hero',
        fileName: file.name,
        bytes: bytes,
        contentType: _imageContentType(file.extension),
      );
      if (!mounted) return;
      setState(() {
        _heroUrl = uploaded.url;
        _heroStoragePath = uploaded.path;
      });
    } catch (e) {
      _snack('Échec de l’envoi de l’image : $e');
    } finally {
      if (mounted) setState(() => _uploadingHero = false);
    }
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty || _slug.text.trim().isEmpty) {
      _snack('Le titre et le slug sont obligatoires.');
      return;
    }
    if (_scope == 'CSE' && _cse.text.trim().isEmpty) {
      _snack('Choisis un CSE.');
      return;
    }

    setState(() => _saving = true);
    try {
      await widget.onSaved({
        'title': _title.text.trim(),
        'slug': _slug.text.trim(),
        'subtitle': _nullIfEmpty(_subtitle.text),
        'intro_text': _nullIfEmpty(_intro.text),
        'scope_level': _scope,
        'cse_code': _scope == 'CSE' ? _cse.text.trim() : null,
        'election_year': int.tryParse(_year.text.trim()),
        'status': _status,
        'is_active': _active,
        'hero_image_url': _heroStoragePath == null ? _heroUrl : null,
        'hero_storage_path': _heroStoragePath,
        'home_position': _homePosition,
        'home_card_cta': _cta.text.trim().isEmpty
            ? 'Découvrir la campagne'
            : _cta.text.trim(),
        'vote_start_at': _datePayload(_voteStart.text),
        'vote_end_at': _datePayload(_voteEnd.text, endOfDay: true),
        'display_start_at': _datePayload(_displayStart.text),
        'display_end_at': _datePayload(_displayEnd.text, endOfDay: true),
      });
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _SectionTitle(
          title: 'Identité de la campagne',
          subtitle:
              'Ce contenu alimente la carte d’accueil et la page Élections.',
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _title,
          decoration: const InputDecoration(labelText: 'Titre'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _subtitle,
          decoration: const InputDecoration(labelText: 'Sous-titre / slogan'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _slug,
          decoration: const InputDecoration(
            labelText: 'Slug unique',
            hintText: 'elections-2027-hub',
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _intro,
          maxLines: 5,
          decoration: const InputDecoration(
            labelText: 'Texte d’introduction',
            alignLabelWithHint: true,
          ),
        ),
        const SizedBox(height: 24),
        _SectionTitle(
          title: 'Image de la carte',
          subtitle:
              'Pas d’URL à saisir : choisis directement un JPG, PNG ou WebP.',
        ),
        const SizedBox(height: 12),
        Container(
          height: 240,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
          ),
          child: _heroUrl == null
              ? const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.image_outlined, size: 48),
                      SizedBox(height: 8),
                      Text('Aucune image sélectionnée'),
                    ],
                  ),
                )
              : Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.network(
                      _heroUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const Center(
                        child: Icon(Icons.broken_image_outlined, size: 48),
                      ),
                    ),
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Colors.black54],
                        ),
                      ),
                    ),
                    Positioned(
                      left: 18,
                      right: 18,
                      bottom: 16,
                      child: Text(
                        _title.text.trim().isEmpty
                            ? 'Élections CFDT'
                            : _title.text.trim(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
        ),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            onPressed: _uploadingHero ? null : _pickHero,
            icon: _uploadingHero
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.upload_file_rounded),
            label: Text(
              _heroUrl == null ? 'Choisir une image' : 'Remplacer l’image',
            ),
          ),
        ),
        const SizedBox(height: 24),
        _SectionTitle(
          title: 'Ciblage et visibilité',
          subtitle: 'La campagne reste distincte du suivi des votants.',
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            SizedBox(
              width: 260,
              child: DropdownButtonFormField<String>(
                key: ValueKey('scope-$_scope'),
                initialValue: _scope,
                decoration: const InputDecoration(labelText: 'Périmètre'),
                items: const [
                  DropdownMenuItem(value: 'CSE', child: Text('CSE')),
                  DropdownMenuItem(value: 'CSEC', child: Text('CSEC')),
                  DropdownMenuItem(value: 'GLOBAL', child: Text('Commun')),
                ],
                onChanged: (value) => setState(() => _scope = value ?? 'CSE'),
              ),
            ),
            SizedBox(
              width: 180,
              child: TextField(
                controller: _year,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Année'),
              ),
            ),
            SizedBox(
              width: 220,
              child: DropdownButtonFormField<String>(
                initialValue: _status,
                decoration: const InputDecoration(labelText: 'État'),
                items: const [
                  DropdownMenuItem(value: 'draft', child: Text('Brouillon')),
                  DropdownMenuItem(value: 'published', child: Text('Publiée')),
                  DropdownMenuItem(value: 'archived', child: Text('Archivée')),
                ],
                onChanged: (value) =>
                    setState(() => _status = value ?? 'draft'),
              ),
            ),
          ],
        ),
        if (_scope == 'CSE') ...[
          const SizedBox(height: 12),
          if (widget.cseOptions.isEmpty)
            TextField(
              controller: _cse,
              decoration: const InputDecoration(labelText: 'CSE'),
            )
          else
            DropdownButtonFormField<String>(
              key: ValueKey('cse-${_cse.text}'),
              initialValue: widget.cseOptions.contains(_cse.text.trim())
                  ? _cse.text.trim()
                  : null,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'CSE'),
              items: widget.cseOptions
                  .map(
                    (cse) => DropdownMenuItem<String>(
                      value: cse,
                      child: Text(cse, overflow: TextOverflow.ellipsis),
                    ),
                  )
                  .toList(),
              onChanged: (value) => _cse.text = value ?? '',
            ),
        ],
        const SizedBox(height: 12),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Campagne active'),
          subtitle: const Text('Elle doit aussi être publiée pour apparaître.'),
          value: _active,
          onChanged: (value) => setState(() => _active = value),
        ),
        const SizedBox(height: 18),
        _SectionTitle(
          title: 'Carte d’accueil',
          subtitle: 'La carte sera pleine largeur sur iPhone et iPad.',
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            SizedBox(
              width: 230,
              child: DropdownButtonFormField<int>(
                isExpanded: true,
                initialValue: _homePosition,
                decoration: const InputDecoration(labelText: 'Position'),
                items: const [
                  DropdownMenuItem(
                    value: 1,
                    child: Text('1 — avant représentants'),
                  ),
                  DropdownMenuItem(
                    value: 2,
                    child: Text('2 — après représentants'),
                  ),
                ],
                onChanged: (value) =>
                    setState(() => _homePosition = value ?? 1),
              ),
            ),
            SizedBox(
              width: 320,
              child: TextField(
                controller: _cta,
                decoration: const InputDecoration(
                  labelText: 'Texte du bouton',
                  hintText: 'Découvrir la campagne',
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        _SectionTitle(
          title: 'Dates',
          subtitle: 'Format AAAA-MM-JJ. Laisser vide si aucune limite.',
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _DateField(controller: _voteStart, label: 'Début du vote'),
            _DateField(controller: _voteEnd, label: 'Fin du vote'),
            _DateField(controller: _displayStart, label: 'Début affichage'),
            _DateField(controller: _displayEnd, label: 'Fin affichage'),
          ],
        ),
        const SizedBox(height: 26),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_rounded),
            label: const Text('Enregistrer la campagne'),
          ),
        ),
      ],
    );
  }
}

class _PublicationsTab extends StatefulWidget {
  const _PublicationsTab({
    required this.campaignId,
    required this.initialPublications,
    required this.service,
    required this.onChanged,
  });

  final String campaignId;
  final List<Map<String, dynamic>> initialPublications;
  final ElectionService service;
  final Future<void> Function() onChanged;

  @override
  State<_PublicationsTab> createState() => _PublicationsTabState();
}

class _PublicationsTabState extends State<_PublicationsTab> {
  late List<Map<String, dynamic>> _items;

  @override
  void initState() {
    super.initState();
    _items = List<Map<String, dynamic>>.from(widget.initialPublications);
  }

  Future<void> _refresh() async {
    final rows = await widget.service.adminListPublications(widget.campaignId);
    if (!mounted) return;
    setState(() => _items = rows);
  }

  Future<void> _openEditor([Map<String, dynamic>? initial]) async {
    final payload = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _PublicationDialog(
        campaignId: widget.campaignId,
        service: widget.service,
        initial: initial,
      ),
    );
    if (payload == null) return;

    if (initial == null) {
      await widget.service.adminCreatePublication({
        ...payload,
        'campaign_id': widget.campaignId,
        'sort_order': (_items.length + 1) * 10,
      });
    } else {
      await widget.service.adminUpdatePublication(
        initial['id'].toString(),
        payload,
      );
    }
    await _refresh();
    await widget.onChanged();
  }

  Future<void> _delete(Map<String, dynamic> item) async {
    final ok = await _confirmDelete(context, 'Supprimer cette publication ?');
    if (!ok) return;
    await widget.service.adminDeletePublication(item['id'].toString());
    await _refresh();
    await widget.onChanged();
  }

  Future<void> _move(int index, int delta) async {
    final target = index + delta;
    if (target < 0 || target >= _items.length) return;
    final next = List<Map<String, dynamic>>.from(_items);
    final item = next.removeAt(index);
    next.insert(target, item);
    setState(() => _items = next);
    await widget.service.adminReorderPublications(next);
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Ajouter une publication'),
      ),
      body: _items.isEmpty
          ? const _EmptyModule(
              icon: Icons.campaign_outlined,
              title: 'Aucune publication',
              text: 'Ajoute un tract PDF, une image ou un article.',
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 100),
              itemCount: _items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final item = _items[index];
                final type = item['publication_type']?.toString() ?? 'article';
                final imageUrl = _nullIfEmpty(
                  item['cover_image_url']?.toString() ??
                      (type == 'image'
                          ? item['media_url']?.toString() ?? ''
                          : ''),
                );
                return Card(
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => _openEditor(item),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          _PublicationThumb(type: type, imageUrl: imageUrl),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Wrap(
                                  spacing: 7,
                                  runSpacing: 5,
                                  children: [
                                    _TypeChip(type: type),
                                    if (item['is_featured'] == true)
                                      const Chip(
                                        avatar: Icon(
                                          Icons.star_rounded,
                                          size: 16,
                                        ),
                                        label: Text('À la une'),
                                      ),
                                    if (item['is_active'] != true)
                                      const Chip(label: Text('Masquée')),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  item['title']?.toString() ?? 'Sans titre',
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                                if (_nullIfEmpty(
                                      item['summary']?.toString() ?? '',
                                    ) !=
                                    null) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    item['summary'].toString(),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: 'Monter',
                            onPressed: index == 0
                                ? null
                                : () => _move(index, -1),
                            icon: const Icon(Icons.arrow_upward_rounded),
                          ),
                          IconButton(
                            tooltip: 'Descendre',
                            onPressed: index == _items.length - 1
                                ? null
                                : () => _move(index, 1),
                            icon: const Icon(Icons.arrow_downward_rounded),
                          ),
                          PopupMenuButton<String>(
                            onSelected: (value) {
                              if (value == 'edit') _openEditor(item);
                              if (value == 'delete') _delete(item);
                            },
                            itemBuilder: (_) => const [
                              PopupMenuItem(
                                value: 'edit',
                                child: Text('Modifier'),
                              ),
                              PopupMenuItem(
                                value: 'delete',
                                child: Text('Supprimer'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class _PublicationDialog extends StatefulWidget {
  const _PublicationDialog({
    required this.campaignId,
    required this.service,
    this.initial,
  });

  final String campaignId;
  final ElectionService service;
  final Map<String, dynamic>? initial;

  @override
  State<_PublicationDialog> createState() => _PublicationDialogState();
}

class _PublicationDialogState extends State<_PublicationDialog> {
  late final TextEditingController _title;
  late final TextEditingController _summary;
  late final TextEditingController _body;
  late String _type;
  late String _audience;
  late bool _active;
  late bool _featured;
  String? _mediaUrl;
  String? _mediaPath;
  String? _coverUrl;
  String? _coverPath;
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    final i = widget.initial;
    _title = TextEditingController(text: i?['title']?.toString() ?? '');
    _summary = TextEditingController(text: i?['summary']?.toString() ?? '');
    _body = TextEditingController(text: i?['body']?.toString() ?? '');
    _type = i?['publication_type']?.toString() ?? 'pdf';
    final tags = ((i?['audience_tags'] as List?) ?? const ['ALL'])
        .map((e) => e.toString())
        .toList();
    _audience = tags.contains('CADRE')
        ? 'CADRE'
        : tags.contains('NON_CADRE')
        ? 'NON_CADRE'
        : 'ALL';
    _active = i?['is_active'] != false;
    _featured = i?['is_featured'] == true;
    _mediaUrl = _nullIfEmpty(i?['media_url']?.toString() ?? '');
    _mediaPath = _nullIfEmpty(i?['media_storage_path']?.toString() ?? '');
    _coverUrl = _nullIfEmpty(i?['cover_image_url']?.toString() ?? '');
    _coverPath = _nullIfEmpty(i?['cover_storage_path']?.toString() ?? '');
  }

  @override
  void dispose() {
    _title.dispose();
    _summary.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _pickMainMedia() async {
    final isPdf = _type == 'pdf';
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: isPdf
          ? const ['pdf']
          : const ['jpg', 'jpeg', 'png', 'webp'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.single;
    final bytes = file.bytes;
    if (bytes == null) return;

    setState(() => _uploading = true);
    try {
      final uploaded = await widget.service.uploadCampaignFile(
        campaignId: widget.campaignId,
        category: isPdf ? 'tracts' : 'images',
        fileName: file.name,
        bytes: bytes,
        contentType: isPdf
            ? 'application/pdf'
            : _imageContentType(file.extension),
      );
      if (!mounted) return;
      setState(() {
        _mediaUrl = uploaded.url;
        _mediaPath = uploaded.path;
      });
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _pickCover() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.single;
    final bytes = file.bytes;
    if (bytes == null) return;

    setState(() => _uploading = true);
    try {
      final uploaded = await widget.service.uploadCampaignFile(
        campaignId: widget.campaignId,
        category: 'covers',
        fileName: file.name,
        bytes: bytes,
        contentType: _imageContentType(file.extension),
      );
      if (!mounted) return;
      setState(() {
        _coverUrl = uploaded.url;
        _coverPath = uploaded.path;
      });
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final requiresMedia = _type == 'pdf' || _type == 'image';
    return AlertDialog(
      title: Text(
        widget.initial == null
            ? 'Nouvelle publication'
            : 'Modifier la publication',
      ),
      content: SizedBox(
        width: 720,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DropdownButtonFormField<String>(
                key: ValueKey('pub-type-$_type'),
                initialValue: _type,
                decoration: const InputDecoration(labelText: 'Type'),
                items: const [
                  DropdownMenuItem(value: 'pdf', child: Text('Tract PDF')),
                  DropdownMenuItem(
                    value: 'image',
                    child: Text('Image / affiche'),
                  ),
                  DropdownMenuItem(
                    value: 'article',
                    child: Text('Article texte'),
                  ),
                ],
                onChanged: (value) => setState(() => _type = value ?? 'pdf'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _title,
                decoration: const InputDecoration(labelText: 'Titre'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _summary,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Résumé court',
                  hintText: 'Le texte visible sur la carte de publication',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _body,
                maxLines: 7,
                decoration: const InputDecoration(
                  labelText: 'Texte explicatif',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 16),
              if (requiresMedia) ...[
                FilledButton.tonalIcon(
                  onPressed: _uploading ? null : _pickMainMedia,
                  icon: Icon(
                    _type == 'pdf'
                        ? Icons.picture_as_pdf_rounded
                        : Icons.image_rounded,
                  ),
                  label: Text(
                    _type == 'pdf'
                        ? (_mediaUrl == null
                              ? 'Choisir le tract PDF'
                              : 'Remplacer le tract PDF')
                        : (_mediaUrl == null
                              ? 'Choisir l’image'
                              : 'Remplacer l’image'),
                  ),
                ),
                if (_mediaUrl != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _type == 'pdf' ? 'PDF chargé ✓' : 'Image chargée ✓',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
              ],
              if (_type != 'image') ...[
                OutlinedButton.icon(
                  onPressed: _uploading ? null : _pickCover,
                  icon: const Icon(Icons.photo_outlined),
                  label: Text(
                    _coverUrl == null
                        ? 'Ajouter une image d’aperçu (optionnel)'
                        : 'Remplacer l’image d’aperçu',
                  ),
                ),
                if (_coverUrl != null) ...[
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      _coverUrl!,
                      height: 150,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const SizedBox.shrink(),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
              ],
              DropdownButtonFormField<String>(
                initialValue: _audience,
                decoration: const InputDecoration(labelText: 'Audience'),
                items: const [
                  DropdownMenuItem(value: 'ALL', child: Text('Tous')),
                  DropdownMenuItem(value: 'CADRE', child: Text('Cadres')),
                  DropdownMenuItem(
                    value: 'NON_CADRE',
                    child: Text('Non-cadres'),
                  ),
                ],
                onChanged: (value) =>
                    setState(() => _audience = value ?? 'ALL'),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Mettre à la une'),
                subtitle: const Text(
                  'La publication sera affichée en priorité.',
                ),
                value: _featured,
                onChanged: (value) => setState(() => _featured = value),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Publication visible'),
                value: _active,
                onChanged: (value) => setState(() => _active = value),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: _uploading
              ? null
              : () {
                  if (_title.text.trim().isEmpty) return;
                  if (requiresMedia && _mediaUrl == null) return;
                  Navigator.pop(context, {
                    'publication_type': _type,
                    'title': _title.text.trim(),
                    'summary': _nullIfEmpty(_summary.text),
                    'body': _nullIfEmpty(_body.text),
                    'media_url': _type == 'article'
                        ? null
                        : (_mediaPath == null ? _mediaUrl : null),
                    'media_storage_path': _type == 'article'
                        ? null
                        : _mediaPath,
                    'cover_image_url': _type == 'image'
                        ? null
                        : (_coverPath == null ? _coverUrl : null),
                    'cover_storage_path': _type == 'image' ? null : _coverPath,
                    'audience_tags': [_audience],
                    'is_featured': _featured,
                    'is_active': _active,
                  });
                },
          child: const Text('Enregistrer'),
        ),
      ],
    );
  }
}

class _ProgramTab extends StatefulWidget {
  const _ProgramTab({
    required this.campaignId,
    required this.initialSections,
    required this.service,
    required this.onChanged,
  });

  final String campaignId;
  final List<Map<String, dynamic>> initialSections;
  final ElectionService service;
  final Future<void> Function() onChanged;

  @override
  State<_ProgramTab> createState() => _ProgramTabState();
}

class _ProgramTabState extends State<_ProgramTab> {
  late List<Map<String, dynamic>> _sections;

  @override
  void initState() {
    super.initState();
    _sections = List<Map<String, dynamic>>.from(widget.initialSections);
  }

  Future<void> _refresh() async {
    final rows = await widget.service.adminListSections(widget.campaignId);
    if (!mounted) return;
    setState(() => _sections = rows);
  }

  Future<void> _editSection([Map<String, dynamic>? initial]) async {
    final payload = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _SectionDialog(initial: initial),
    );
    if (payload == null) return;
    if (initial == null) {
      await widget.service.adminCreateSection({
        ...payload,
        'campaign_id': widget.campaignId,
        'sort_order': (_sections.length + 1) * 10,
      });
    } else {
      await widget.service.adminUpdateSection(
        initial['id'].toString(),
        payload,
      );
    }
    await _refresh();
    await widget.onChanged();
  }

  Future<void> _deleteSection(Map<String, dynamic> section) async {
    final ok = await _confirmDelete(
      context,
      'Supprimer cette rubrique et tout son contenu ?',
    );
    if (!ok) return;
    await widget.service.adminDeleteSection(section['id'].toString());
    await _refresh();
    await widget.onChanged();
  }

  Future<void> _moveSection(int index, int delta) async {
    final target = index + delta;
    if (target < 0 || target >= _sections.length) return;
    final next = List<Map<String, dynamic>>.from(_sections);
    final section = next.removeAt(index);
    next.insert(target, section);
    setState(() => _sections = next);
    await widget.service.adminReorderSections(next);
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _editSection(),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Ajouter une rubrique'),
      ),
      body: _sections.isEmpty
          ? const _EmptyModule(
              icon: Icons.fact_check_outlined,
              title: 'Programme vide',
              text:
                  'Crée des rubriques : pouvoir d’achat, conditions de travail, QVCT…',
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 100),
              itemCount: _sections.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final section = _sections[index];
                return Card(
                  child: ExpansionTile(
                    title: Text(
                      section['title']?.toString() ?? 'Rubrique',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle:
                        _nullIfEmpty(section['subtitle']?.toString() ?? '') ==
                            null
                        ? null
                        : Text(section['subtitle'].toString()),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Monter',
                          onPressed: index == 0
                              ? null
                              : () => _moveSection(index, -1),
                          icon: const Icon(Icons.arrow_upward_rounded),
                        ),
                        IconButton(
                          tooltip: 'Descendre',
                          onPressed: index == _sections.length - 1
                              ? null
                              : () => _moveSection(index, 1),
                          icon: const Icon(Icons.arrow_downward_rounded),
                        ),
                        PopupMenuButton<String>(
                          onSelected: (value) {
                            if (value == 'edit') _editSection(section);
                            if (value == 'delete') _deleteSection(section);
                          },
                          itemBuilder: (_) => const [
                            PopupMenuItem(
                              value: 'edit',
                              child: Text('Modifier'),
                            ),
                            PopupMenuItem(
                              value: 'delete',
                              child: Text('Supprimer'),
                            ),
                          ],
                        ),
                      ],
                    ),
                    children: [
                      _SectionItemsEditor(
                        sectionId: section['id'].toString(),
                        service: widget.service,
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}

class _SectionItemsEditor extends StatefulWidget {
  const _SectionItemsEditor({required this.sectionId, required this.service});

  final String sectionId;
  final ElectionService service;

  @override
  State<_SectionItemsEditor> createState() => _SectionItemsEditorState();
}

class _SectionItemsEditorState extends State<_SectionItemsEditor> {
  List<Map<String, dynamic>> _items = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final rows = await widget.service.adminListItems(widget.sectionId);
    if (!mounted) return;
    setState(() {
      _items = rows;
      _loading = false;
    });
  }

  Future<void> _edit([Map<String, dynamic>? initial]) async {
    final payload = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _ProgramItemDialog(initial: initial),
    );
    if (payload == null) return;
    if (initial == null) {
      await widget.service.adminCreateItem({
        ...payload,
        'section_id': widget.sectionId,
        'sort_order': (_items.length + 1) * 10,
      });
    } else {
      await widget.service.adminUpdateItem(initial['id'].toString(), payload);
    }
    await _load();
  }

  Future<void> _delete(Map<String, dynamic> item) async {
    final ok = await _confirmDelete(
      context,
      'Supprimer ce point du programme ?',
    );
    if (!ok) return;
    await widget.service.adminDeleteItem(item['id'].toString());
    await _load();
  }

  Future<void> _move(int index, int delta) async {
    final target = index + delta;
    if (target < 0 || target >= _items.length) return;
    final next = List<Map<String, dynamic>>.from(_items);
    final item = next.removeAt(index);
    next.insert(target, item);
    setState(() => _items = next);
    await widget.service.adminReorderItems(next);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(18),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        children: [
          for (var index = 0; index < _items.length; index++)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(child: Text('${index + 1}')),
              title: Text(_items[index]['title']?.toString() ?? 'Point'),
              subtitle:
                  _nullIfEmpty(_items[index]['body']?.toString() ?? '') == null
                  ? null
                  : Text(
                      _items[index]['body'].toString(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    onPressed: index == 0 ? null : () => _move(index, -1),
                    icon: const Icon(Icons.arrow_upward_rounded),
                  ),
                  IconButton(
                    onPressed: index == _items.length - 1
                        ? null
                        : () => _move(index, 1),
                    icon: const Icon(Icons.arrow_downward_rounded),
                  ),
                  IconButton(
                    onPressed: () => _edit(_items[index]),
                    icon: const Icon(Icons.edit_outlined),
                  ),
                  IconButton(
                    onPressed: () => _delete(_items[index]),
                    icon: const Icon(Icons.delete_outline_rounded),
                  ),
                ],
              ),
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => _edit(),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Ajouter un point'),
            ),
          ),
        ],
      ),
    );
  }
}

class _CandidatesTab extends StatefulWidget {
  const _CandidatesTab({
    required this.campaignId,
    required this.initialCandidates,
    required this.service,
    required this.onChanged,
  });

  final String campaignId;
  final List<Map<String, dynamic>> initialCandidates;
  final ElectionService service;
  final Future<void> Function() onChanged;

  @override
  State<_CandidatesTab> createState() => _CandidatesTabState();
}

class _CandidatesTabState extends State<_CandidatesTab> {
  late List<Map<String, dynamic>> _items;

  @override
  void initState() {
    super.initState();
    _items = List<Map<String, dynamic>>.from(widget.initialCandidates);
  }

  Future<void> _refresh() async {
    final rows = await widget.service.adminListCandidates(widget.campaignId);
    if (!mounted) return;
    setState(() => _items = rows);
  }

  Future<void> _edit([Map<String, dynamic>? initial]) async {
    final payload = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _CandidateDialog(
        campaignId: widget.campaignId,
        service: widget.service,
        initial: initial,
      ),
    );
    if (payload == null) return;
    if (initial == null) {
      await widget.service.adminCreateCandidate({
        ...payload,
        'campaign_id': widget.campaignId,
        'sort_order': (_items.length + 1) * 10,
      });
    } else {
      await widget.service.adminUpdateCandidate(
        initial['id'].toString(),
        payload,
      );
    }
    await _refresh();
    await widget.onChanged();
  }

  Future<void> _delete(Map<String, dynamic> candidate) async {
    final ok = await _confirmDelete(context, 'Supprimer ce candidat ?');
    if (!ok) return;
    await widget.service.adminDeleteCandidate(candidate['id'].toString());
    await _refresh();
    await widget.onChanged();
  }

  Future<void> _move(int index, int delta) async {
    final target = index + delta;
    if (target < 0 || target >= _items.length) return;
    final next = List<Map<String, dynamic>>.from(_items);
    final item = next.removeAt(index);
    next.insert(target, item);
    setState(() => _items = next);
    await widget.service.adminReorderCandidates(next);
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(),
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text('Ajouter un candidat'),
      ),
      body: _items.isEmpty
          ? const _EmptyModule(
              icon: Icons.groups_2_outlined,
              title: 'Aucun candidat',
              text:
                  'Ajoute les membres de la liste avec leur photo et leur présentation.',
            )
          : GridView.builder(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 100),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 360,
                mainAxisExtent: 330,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: _items.length,
              itemBuilder: (context, index) {
                final c = _items[index];
                final photo = _nullIfEmpty(c['photo_url']?.toString() ?? '');
                return Card(
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: photo == null
                            ? const Center(
                                child: Icon(Icons.person_rounded, size: 72),
                              )
                            : Image.network(
                                photo,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) => const Center(
                                  child: Icon(Icons.person_rounded, size: 72),
                                ),
                              ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
                        child: Text(
                          '${c['first_name'] ?? ''} ${c['last_name'] ?? ''}'
                              .trim(),
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      if (_nullIfEmpty(c['list_role']?.toString() ?? '') !=
                          null)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          child: Text(c['list_role'].toString()),
                        ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          IconButton(
                            onPressed: index == 0
                                ? null
                                : () => _move(index, -1),
                            icon: const Icon(Icons.arrow_back_rounded),
                          ),
                          IconButton(
                            onPressed: index == _items.length - 1
                                ? null
                                : () => _move(index, 1),
                            icon: const Icon(Icons.arrow_forward_rounded),
                          ),
                          IconButton(
                            onPressed: () => _edit(c),
                            icon: const Icon(Icons.edit_outlined),
                          ),
                          IconButton(
                            onPressed: () => _delete(c),
                            icon: const Icon(Icons.delete_outline),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}

class _PreviewTab extends StatelessWidget {
  const _PreviewTab({
    required this.campaign,
    required this.publications,
    required this.candidates,
  });

  final Map<String, dynamic> campaign;
  final List<Map<String, dynamic>> publications;
  final List<Map<String, dynamic>> candidates;

  @override
  Widget build(BuildContext context) {
    final hero = _nullIfEmpty(campaign['hero_image_url']?.toString() ?? '');
    final title = campaign['title']?.toString() ?? 'Élections CFDT';
    final subtitle = _nullIfEmpty(campaign['subtitle']?.toString() ?? '');
    final featured = publications
        .where((p) => p['is_featured'] == true)
        .toList();
    final others = publications.where((p) => p['is_featured'] != true).toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth < 720 ? constraints.maxWidth : 620.0;
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Center(
              child: SizedBox(
                width: width,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Aperçu de la carte d’accueil',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    AspectRatio(
                      aspectRatio: constraints.maxWidth < 720 ? 1.75 : 2.6,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            if (hero != null)
                              Image.network(
                                hero,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) =>
                                    const ColoredBox(color: Colors.deepOrange),
                              )
                            else
                              const ColoredBox(color: Colors.deepOrange),
                            const DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [Colors.black12, Colors.black87],
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(22),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.end,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    title,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 26,
                                    ),
                                  ),
                                  if (subtitle != null) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      subtitle,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 15,
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 12),
                                  DecoratedBox(
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 9,
                                      ),
                                      child: Text(
                                        campaign['home_card_cta']?.toString() ??
                                            'Découvrir la campagne',
                                        style: const TextStyle(
                                          color: Colors.black87,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    if (featured.isNotEmpty) ...[
                      Text(
                        'À la une',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 10),
                      for (final p in featured) ...[
                        _PreviewPublicationCard(item: p),
                        const SizedBox(height: 10),
                      ],
                    ],
                    if (others.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      Text(
                        'Publications',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 10),
                      for (final p in others.take(5)) ...[
                        _PreviewPublicationCard(item: p),
                        const SizedBox(height: 10),
                      ],
                    ],
                    if (candidates.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Text(
                        'Candidats',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 10),
                      Text('${candidates.length} candidat(s) configuré(s).'),
                    ],
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _PreviewPublicationCard extends StatelessWidget {
  const _PreviewPublicationCard({required this.item});
  final Map<String, dynamic> item;

  @override
  Widget build(BuildContext context) {
    final type = item['publication_type']?.toString() ?? 'article';
    final image = _nullIfEmpty(
      item['cover_image_url']?.toString() ??
          (type == 'image' ? item['media_url']?.toString() ?? '' : ''),
    );
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: [
          _PublicationThumb(type: type, imageUrl: image, size: 96),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _TypeChip(type: type),
                  const SizedBox(height: 6),
                  Text(
                    item['title']?.toString() ?? 'Publication',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  if (_nullIfEmpty(item['summary']?.toString() ?? '') != null)
                    Text(
                      item['summary'].toString(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
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

class _SectionDialog extends StatefulWidget {
  const _SectionDialog({this.initial});
  final Map<String, dynamic>? initial;

  @override
  State<_SectionDialog> createState() => _SectionDialogState();
}

class _SectionDialogState extends State<_SectionDialog> {
  late final TextEditingController _title;
  late final TextEditingController _subtitle;
  late final TextEditingController _intro;
  late String _audience;
  late bool _active;
  late bool _featured;

  @override
  void initState() {
    super.initState();
    final i = widget.initial;
    _title = TextEditingController(text: i?['title']?.toString() ?? '');
    _subtitle = TextEditingController(text: i?['subtitle']?.toString() ?? '');
    _intro = TextEditingController(text: i?['intro_text']?.toString() ?? '');
    _audience = _audienceFrom(i?['audience_tags']);
    _active = i?['is_active'] != false;
    _featured = i?['is_featured'] == true;
  }

  @override
  void dispose() {
    _title.dispose();
    _subtitle.dispose();
    _intro.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.initial == null ? 'Nouvelle rubrique' : 'Modifier la rubrique',
      ),
      content: SizedBox(
        width: 620,
        child: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                controller: _title,
                decoration: const InputDecoration(labelText: 'Titre'),
              ),
              TextField(
                controller: _subtitle,
                decoration: const InputDecoration(labelText: 'Sous-titre'),
              ),
              TextField(
                controller: _intro,
                maxLines: 4,
                decoration: const InputDecoration(labelText: 'Introduction'),
              ),
              DropdownButtonFormField<String>(
                initialValue: _audience,
                decoration: const InputDecoration(labelText: 'Audience'),
                items: _audienceItems,
                onChanged: (value) =>
                    setState(() => _audience = value ?? 'ALL'),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Mettre en avant'),
                value: _featured,
                onChanged: (value) => setState(() => _featured = value),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Active'),
                value: _active,
                onChanged: (value) => setState(() => _active = value),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: () {
            if (_title.text.trim().isEmpty) return;
            Navigator.pop(context, {
              'section_type': 'program',
              'title': _title.text.trim(),
              'subtitle': _nullIfEmpty(_subtitle.text),
              'intro_text': _nullIfEmpty(_intro.text),
              'audience_tags': [_audience],
              'is_featured': _featured,
              'is_active': _active,
            });
          },
          child: const Text('Enregistrer'),
        ),
      ],
    );
  }
}

class _ProgramItemDialog extends StatefulWidget {
  const _ProgramItemDialog({this.initial});
  final Map<String, dynamic>? initial;

  @override
  State<_ProgramItemDialog> createState() => _ProgramItemDialogState();
}

class _ProgramItemDialogState extends State<_ProgramItemDialog> {
  late final TextEditingController _title;
  late final TextEditingController _body;
  late final TextEditingController _badge;
  late final TextEditingController _metric;
  late String _type;
  late String _audience;
  late bool _active;

  @override
  void initState() {
    super.initState();
    final i = widget.initial;
    _title = TextEditingController(text: i?['title']?.toString() ?? '');
    _body = TextEditingController(text: i?['body']?.toString() ?? '');
    _badge = TextEditingController(text: i?['badge']?.toString() ?? '');
    _metric = TextEditingController(text: i?['metric_value']?.toString() ?? '');
    _type = i?['item_type']?.toString() ?? 'commitment';
    if (!const {
      'text',
      'commitment',
      'result',
      'metric',
      'quote',
    }.contains(_type)) {
      _type = 'text';
    }
    _audience = _audienceFrom(i?['audience_tags']);
    _active = i?['is_active'] != false;
  }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    _badge.dispose();
    _metric.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.initial == null ? 'Nouveau point' : 'Modifier le point',
      ),
      content: SizedBox(
        width: 650,
        child: SingleChildScrollView(
          child: Column(
            children: [
              DropdownButtonFormField<String>(
                initialValue: _type,
                decoration: const InputDecoration(labelText: 'Type'),
                items: const [
                  DropdownMenuItem(
                    value: 'commitment',
                    child: Text('Engagement'),
                  ),
                  DropdownMenuItem(
                    value: 'result',
                    child: Text('Bilan / résultat'),
                  ),
                  DropdownMenuItem(value: 'metric', child: Text('Chiffre clé')),
                  DropdownMenuItem(value: 'quote', child: Text('Citation')),
                  DropdownMenuItem(value: 'text', child: Text('Texte')),
                ],
                onChanged: (value) => setState(() => _type = value ?? 'text'),
              ),
              TextField(
                controller: _title,
                decoration: const InputDecoration(labelText: 'Titre'),
              ),
              TextField(
                controller: _body,
                maxLines: 5,
                decoration: const InputDecoration(labelText: 'Texte'),
              ),
              TextField(
                controller: _badge,
                decoration: const InputDecoration(
                  labelText: 'Badge (optionnel)',
                ),
              ),
              if (_type == 'metric')
                TextField(
                  controller: _metric,
                  decoration: const InputDecoration(
                    labelText: 'Valeur / chiffre clé',
                  ),
                ),
              DropdownButtonFormField<String>(
                initialValue: _audience,
                decoration: const InputDecoration(labelText: 'Audience'),
                items: _audienceItems,
                onChanged: (value) =>
                    setState(() => _audience = value ?? 'ALL'),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Actif'),
                value: _active,
                onChanged: (value) => setState(() => _active = value),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: () {
            if (_title.text.trim().isEmpty) return;
            Navigator.pop(context, {
              'item_type': _type,
              'title': _title.text.trim(),
              'body': _nullIfEmpty(_body.text),
              'badge': _nullIfEmpty(_badge.text),
              'metric_value': _type == 'metric'
                  ? _nullIfEmpty(_metric.text)
                  : null,
              'image_url': null,
              'document_url': null,
              'link_url': null,
              'audience_tags': [_audience],
              'is_active': _active,
            });
          },
          child: const Text('Enregistrer'),
        ),
      ],
    );
  }
}

class _CandidateDialog extends StatefulWidget {
  const _CandidateDialog({
    required this.campaignId,
    required this.service,
    this.initial,
  });

  final String campaignId;
  final ElectionService service;
  final Map<String, dynamic>? initial;

  @override
  State<_CandidateDialog> createState() => _CandidateDialogState();
}

class _CandidateDialogState extends State<_CandidateDialog> {
  late final TextEditingController _firstName;
  late final TextEditingController _lastName;
  late final TextEditingController _job;
  late final TextEditingController _sector;
  late final TextEditingController _college;
  late final TextEditingController _role;
  late final TextEditingController _position;
  late final TextEditingController _bio;
  late String _audience;
  late bool _active;
  String? _photoUrl;
  String? _photoStoragePath;
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    final i = widget.initial;
    _firstName = TextEditingController(
      text: i?['first_name']?.toString() ?? '',
    );
    _lastName = TextEditingController(text: i?['last_name']?.toString() ?? '');
    _job = TextEditingController(text: i?['job_title']?.toString() ?? '');
    _sector = TextEditingController(text: i?['sector']?.toString() ?? '');
    _college = TextEditingController(text: i?['college']?.toString() ?? '');
    _role = TextEditingController(text: i?['list_role']?.toString() ?? '');
    _position = TextEditingController(
      text: i?['list_position']?.toString() ?? '',
    );
    _bio = TextEditingController(text: i?['bio']?.toString() ?? '');
    _audience = _audienceFrom(i?['audience_tags']);
    _active = i?['is_active'] != false;
    _photoUrl = _nullIfEmpty(i?['photo_url']?.toString() ?? '');
    _photoStoragePath = _nullIfEmpty(
      i?['photo_storage_path']?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    for (final controller in [
      _firstName,
      _lastName,
      _job,
      _sector,
      _college,
      _role,
      _position,
      _bio,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.single;
    final bytes = file.bytes;
    if (bytes == null) return;

    setState(() => _uploading = true);
    try {
      final uploaded = await widget.service.uploadCampaignFile(
        campaignId: widget.campaignId,
        category: 'candidates',
        fileName: file.name,
        bytes: bytes,
        contentType: _imageContentType(file.extension),
      );
      if (!mounted) return;
      setState(() {
        _photoUrl = uploaded.url;
        _photoStoragePath = uploaded.path;
      });
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.initial == null ? 'Nouveau candidat' : 'Modifier le candidat',
      ),
      content: SizedBox(
        width: 700,
        child: SingleChildScrollView(
          child: Column(
            children: [
              CircleAvatar(
                radius: 55,
                backgroundImage: _photoUrl == null
                    ? null
                    : NetworkImage(_photoUrl!),
                child: _photoUrl == null
                    ? const Icon(Icons.person_rounded, size: 52)
                    : null,
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _uploading ? null : _pickPhoto,
                icon: const Icon(Icons.photo_camera_outlined),
                label: Text(
                  _photoUrl == null
                      ? 'Choisir une photo'
                      : 'Remplacer la photo',
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _firstName,
                      decoration: const InputDecoration(labelText: 'Prénom'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _lastName,
                      decoration: const InputDecoration(labelText: 'Nom'),
                    ),
                  ),
                ],
              ),
              TextField(
                controller: _job,
                decoration: const InputDecoration(
                  labelText: 'Métier / fonction',
                ),
              ),
              TextField(
                controller: _sector,
                decoration: const InputDecoration(labelText: 'Secteur'),
              ),
              TextField(
                controller: _college,
                decoration: const InputDecoration(labelText: 'Collège'),
              ),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _role,
                      decoration: const InputDecoration(labelText: 'Rôle'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _position,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Position sur la liste',
                      ),
                    ),
                  ),
                ],
              ),
              TextField(
                controller: _bio,
                maxLines: 4,
                decoration: const InputDecoration(labelText: 'Présentation'),
              ),
              DropdownButtonFormField<String>(
                initialValue: _audience,
                decoration: const InputDecoration(labelText: 'Audience'),
                items: _audienceItems,
                onChanged: (value) =>
                    setState(() => _audience = value ?? 'ALL'),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Actif'),
                value: _active,
                onChanged: (value) => setState(() => _active = value),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: _uploading
              ? null
              : () {
                  if (_firstName.text.trim().isEmpty ||
                      _lastName.text.trim().isEmpty) {
                    return;
                  }
                  Navigator.pop(context, {
                    'first_name': _firstName.text.trim(),
                    'last_name': _lastName.text.trim(),
                    'job_title': _nullIfEmpty(_job.text),
                    'sector': _nullIfEmpty(_sector.text),
                    'college': _nullIfEmpty(_college.text),
                    'list_role': _nullIfEmpty(_role.text),
                    'list_position': int.tryParse(_position.text.trim()),
                    'bio': _nullIfEmpty(_bio.text),
                    'photo_url': _photoStoragePath == null ? _photoUrl : null,
                    'photo_storage_path': _photoStoragePath,
                    'audience_tags': [_audience],
                    'is_active': _active,
                  });
                },
          child: const Text('Enregistrer'),
        ),
      ],
    );
  }
}

class _PublicationThumb extends StatelessWidget {
  const _PublicationThumb({required this.type, this.imageUrl, this.size = 82});

  final String type;
  final String? imageUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (imageUrl != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(
          imageUrl!,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _iconBox(context),
        ),
      );
    }
    return _iconBox(context);
  }

  Widget _iconBox(BuildContext context) {
    final icon = type == 'pdf'
        ? Icons.picture_as_pdf_rounded
        : type == 'image'
        ? Icons.image_rounded
        : Icons.article_outlined;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, size: size * 0.42),
    );
  }
}

class _TypeChip extends StatelessWidget {
  const _TypeChip({required this.type});
  final String type;

  @override
  Widget build(BuildContext context) {
    final label = type == 'pdf'
        ? 'TRACT PDF'
        : type == 'image'
        ? 'IMAGE'
        : 'ARTICLE';
    return Chip(label: Text(label));
  }
}

class _DateField extends StatelessWidget {
  const _DateField({required this.controller, required this.label});
  final TextEditingController controller;
  final String label;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 210,
      child: TextField(
        controller: controller,
        decoration: InputDecoration(labelText: label, hintText: 'AAAA-MM-JJ'),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.subtitle});
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 3),
        Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
      ],
    );
  }
}

class _EmptyModule extends StatelessWidget {
  const _EmptyModule({
    required this.icon,
    required this.title,
    required this.text,
  });
  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56),
            const SizedBox(height: 12),
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 6),
            Text(text, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});
  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 46),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(onPressed: onRetry, child: const Text('Réessayer')),
          ],
        ),
      ),
    );
  }
}

const List<DropdownMenuItem<String>> _audienceItems = [
  DropdownMenuItem(value: 'ALL', child: Text('Tous')),
  DropdownMenuItem(value: 'CADRE', child: Text('Cadres')),
  DropdownMenuItem(value: 'NON_CADRE', child: Text('Non-cadres')),
];

String _audienceFrom(dynamic raw) {
  final tags = ((raw as List?) ?? const ['ALL'])
      .map((e) => e.toString())
      .toList();
  if (tags.contains('CADRE')) return 'CADRE';
  if (tags.contains('NON_CADRE')) return 'NON_CADRE';
  return 'ALL';
}

String? _nullIfEmpty(String value) {
  final v = value.trim();
  return v.isEmpty ? null : v;
}

String _dateOnly(dynamic raw) {
  if (raw == null) return '';
  final value = raw.toString().trim();
  if (value.isEmpty) return '';
  final dt = DateTime.tryParse(value);
  if (dt == null) return value;
  return '${dt.year.toString().padLeft(4, '0')}-'
      '${dt.month.toString().padLeft(2, '0')}-'
      '${dt.day.toString().padLeft(2, '0')}';
}

String? _datePayload(String value, {bool endOfDay = false}) {
  final v = value.trim();
  if (v.isEmpty) return null;
  final dt = DateTime.tryParse(v);
  if (dt == null) return null;
  final adjusted = endOfDay
      ? DateTime(dt.year, dt.month, dt.day, 23, 59, 59)
      : DateTime(dt.year, dt.month, dt.day);
  return adjusted.toIso8601String();
}

String _imageContentType(String? extension) {
  switch ((extension ?? '').toLowerCase()) {
    case 'png':
      return 'image/png';
    case 'webp':
      return 'image/webp';
    case 'jpg':
    case 'jpeg':
    default:
      return 'image/jpeg';
  }
}

Future<bool> _confirmDelete(BuildContext context, String message) async {
  return await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Confirmation'),
          content: Text(message),
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
}
