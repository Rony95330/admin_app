import 'package:flutter/material.dart';

import '../../services/election_service.dart';
import 'admin_election_campaign_editor_page.dart';

class AdminElectionCampaignsPage extends StatefulWidget {
  const AdminElectionCampaignsPage({super.key});

  @override
  State<AdminElectionCampaignsPage> createState() =>
      _AdminElectionCampaignsPageState();
}

class _AdminElectionCampaignsPageState
    extends State<AdminElectionCampaignsPage> {
  final ElectionService _service = ElectionService();
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _future = _service.adminListCampaigns();
  }

  Future<void> _openCampaign(String campaignId) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AdminElectionCampaignEditorPage(campaignId: campaignId),
      ),
    );
    if (!mounted) return;
    setState(_reload);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Campagnes électorales'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: Text(
                'Élections Pro',
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createCampaign,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Nouvelle campagne'),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline_rounded, size: 48),
                    const SizedBox(height: 10),
                    const Text('Impossible de charger les campagnes.'),
                    const SizedBox(height: 8),
                    Text(
                      snapshot.error.toString(),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: () => setState(_reload),
                      child: const Text('Réessayer'),
                    ),
                  ],
                ),
              ),
            );
          }

          final rows = snapshot.data ?? const [];
          if (rows.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(30),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.how_to_vote_outlined, size: 58),
                    SizedBox(height: 12),
                    Text('Aucune campagne électorale.'),
                    SizedBox(height: 5),
                    Text(
                      'Crée une campagne puis ajoute son visuel, ses tracts, son programme et ses candidats.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            itemCount: rows.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final c = rows[index];
              final image = c['hero_image_url']?.toString().trim() ?? '';
              final isActive = c['is_active'] == true;
              final status = c['status']?.toString() ?? 'draft';
              final position = (c['home_position'] as num?)?.toInt() ?? 1;

              return Card(
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => _openCampaign(c['id'].toString()),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: image.isEmpty
                              ? Container(
                                  width: 110,
                                  height: 78,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.surfaceContainerHighest,
                                  child: const Icon(
                                    Icons.how_to_vote_rounded,
                                    size: 36,
                                  ),
                                )
                              : Image.network(
                                  image,
                                  width: 110,
                                  height: 78,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) => Container(
                                    width: 110,
                                    height: 78,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.surfaceContainerHighest,
                                    child: const Icon(
                                      Icons.broken_image_outlined,
                                    ),
                                  ),
                                ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                c['title']?.toString() ?? 'Sans titre',
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(height: 5),
                              Wrap(
                                spacing: 7,
                                runSpacing: 5,
                                children: [
                                  Chip(label: Text(status)),
                                  Chip(
                                    label: Text(
                                      c['scope_level']?.toString() ?? 'CSE',
                                    ),
                                  ),
                                  Chip(label: Text('Accueil #$position')),
                                  if (c['cse_code'] != null)
                                    Chip(label: Text(c['cse_code'].toString())),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: isActive,
                          onChanged: (value) async {
                            await _service.adminUpdateCampaign(
                              c['id'].toString(),
                              {'is_active': value},
                            );
                            if (!mounted) return;
                            setState(_reload);
                          },
                        ),
                        PopupMenuButton<String>(
                          tooltip: 'Actions',
                          onSelected: (value) async {
                            switch (value) {
                              case 'duplicate':
                                await _duplicateCampaign(c);
                                break;
                              case 'delete':
                                await _deleteCampaign(c);
                                break;
                            }
                          },
                          itemBuilder: (_) => const [
                            PopupMenuItem(
                              value: 'duplicate',
                              child: Text('Dupliquer'),
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
          );
        },
      ),
    );
  }

  Future<void> _createCampaign() async {
    final cseOptions = await _service.adminListCse();
    if (!mounted) return;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _NewCampaignDialog(cseOptions: cseOptions),
    );
    if (result == null) return;

    final id = await _service.adminCreateCampaign(result);
    if (!mounted) return;
    setState(_reload);
    await _openCampaign(id);
  }

  Future<void> _duplicateCampaign(Map<String, dynamic> campaign) async {
    final currentYear = (campaign['election_year'] as num?)?.toInt();
    final suggestedYear = currentYear == null ? null : currentYear + 1;
    final titleController = TextEditingController(
      text: suggestedYear == null
          ? '${campaign['title'] ?? 'Élections'} - copie'
          : 'Élections $suggestedYear',
    );
    final slugBase = campaign['slug']?.toString().trim() ?? 'elections';
    final slugController = TextEditingController(
      text: suggestedYear == null
          ? '$slugBase-copie'
          : '$slugBase-$suggestedYear',
    );
    final yearController = TextEditingController(
      text: suggestedYear?.toString() ?? '',
    );

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Dupliquer la campagne'),
        content: SizedBox(
          width: 540,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(labelText: 'Nouveau titre'),
              ),
              TextField(
                controller: slugController,
                decoration: const InputDecoration(labelText: 'Nouveau slug'),
              ),
              TextField(
                controller: yearController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Année'),
              ),
              const SizedBox(height: 10),
              const Text(
                'La copie est créée en brouillon et désactivée. Les publications, le programme et les candidats sont recopiés.',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Dupliquer'),
          ),
        ],
      ),
    );

    if (ok != true) {
      titleController.dispose();
      slugController.dispose();
      yearController.dispose();
      return;
    }

    try {
      final id = await _service.adminDuplicateCampaign(
        campaignId: campaign['id'].toString(),
        title: titleController.text.trim(),
        slug: slugController.text.trim(),
        electionYear: int.tryParse(yearController.text.trim()),
      );
      if (!mounted) return;
      setState(_reload);
      await _openCampaign(id);
    } finally {
      titleController.dispose();
      slugController.dispose();
      yearController.dispose();
    }
  }

  Future<void> _deleteCampaign(Map<String, dynamic> campaign) async {
    final ok =
        await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Supprimer la campagne ?'),
            content: Text(
              'La campagne « ${campaign['title'] ?? ''} » et tous ses contenus seront supprimés.',
            ),
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
    if (!ok) return;

    await _service.adminDeleteCampaign(campaign['id'].toString());
    if (!mounted) return;
    setState(_reload);
  }
}

class _NewCampaignDialog extends StatefulWidget {
  const _NewCampaignDialog({required this.cseOptions});
  final List<String> cseOptions;

  @override
  State<_NewCampaignDialog> createState() => _NewCampaignDialogState();
}

class _NewCampaignDialogState extends State<_NewCampaignDialog> {
  final _title = TextEditingController();
  final _slug = TextEditingController();
  final _subtitle = TextEditingController();
  final _cse = TextEditingController();
  final _year = TextEditingController();
  String _scope = 'CSE';

  @override
  void dispose() {
    _title.dispose();
    _slug.dispose();
    _subtitle.dispose();
    _cse.dispose();
    _year.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nouvelle campagne'),
      content: SizedBox(
        width: 580,
        child: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                controller: _title,
                decoration: const InputDecoration(labelText: 'Titre'),
              ),
              TextField(
                controller: _slug,
                decoration: const InputDecoration(
                  labelText: 'Slug unique',
                  hintText: 'elections-2027-hub',
                ),
              ),
              TextField(
                controller: _subtitle,
                decoration: const InputDecoration(labelText: 'Sous-titre'),
              ),
              TextField(
                controller: _year,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Année'),
              ),
              DropdownButtonFormField<String>(
                key: ValueKey(_scope),
                initialValue: _scope,
                decoration: const InputDecoration(labelText: 'Périmètre'),
                items: const [
                  DropdownMenuItem(value: 'CSE', child: Text('CSE')),
                  DropdownMenuItem(value: 'CSEC', child: Text('CSEC')),
                  DropdownMenuItem(value: 'GLOBAL', child: Text('Commun')),
                ],
                onChanged: (value) => setState(() => _scope = value ?? 'CSE'),
              ),
              if (_scope == 'CSE')
                widget.cseOptions.isEmpty
                    ? TextField(
                        controller: _cse,
                        decoration: const InputDecoration(labelText: 'CSE'),
                      )
                    : DropdownButtonFormField<String>(
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'CSE'),
                        items: widget.cseOptions
                            .map(
                              (cse) => DropdownMenuItem<String>(
                                value: cse,
                                child: Text(
                                  cse,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (value) => _cse.text = value ?? '',
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
            if (_title.text.trim().isEmpty || _slug.text.trim().isEmpty) return;
            if (_scope == 'CSE' && _cse.text.trim().isEmpty) return;
            Navigator.pop(context, {
              'title': _title.text.trim(),
              'slug': _slug.text.trim(),
              'subtitle': _subtitle.text.trim().isEmpty
                  ? null
                  : _subtitle.text.trim(),
              'scope_level': _scope,
              'cse_code': _scope == 'CSE' ? _cse.text.trim() : null,
              'election_year': int.tryParse(_year.text.trim()),
              'status': 'draft',
              'is_active': false,
              'home_position': 1,
              'home_card_cta': 'Découvrir la campagne',
            });
          },
          child: const Text('Créer'),
        ),
      ],
    );
  }
}
