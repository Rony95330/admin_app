import 'package:flutter/material.dart';

import '../../core/home_banner/home_banner_model.dart';
import '../../core/home_banner/home_banner_service.dart';
import 'home_banner_edit_page.dart';

class HomeBannersAdminPage extends StatefulWidget {
  const HomeBannersAdminPage({super.key, this.service});

  final HomeBannerService? service;

  @override
  State<HomeBannersAdminPage> createState() => _HomeBannersAdminPageState();
}

class _HomeBannersAdminPageState extends State<HomeBannersAdminPage> {
  late final HomeBannerService _service;
  List<HomeBanner> _items = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? HomeBannerService();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final items = await _service.fetchAllForAdmin();
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Chargement impossible : $e')));
    }
  }

  Future<void> _edit([HomeBanner? banner]) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => HomeBannerEditPage(banner: banner, service: _service),
      ),
    );
    if (changed == true) await _load();
  }

  Future<void> _move(int index, int delta) async {
    final target = index + delta;
    if (target < 0 || target >= _items.length) return;
    final mutable = List<HomeBanner>.of(_items);
    final item = mutable.removeAt(index);
    mutable.insert(target, item);
    setState(() => _items = mutable);
    await _service.reorder(mutable.where((b) => b.archivedAt == null).toList());
    await _load();
  }

  Future<void> _showStats(HomeBanner banner) async {
    final stats = await _service.stats(banner.id);
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(banner.title),
        content: Text(
          'Impressions : ${stats['impressions'] ?? 0}\n'
          'Clics : ${stats['clicks'] ?? 0}\n'
          'Fermetures : ${stats['dismissals'] ?? 0}\n'
          'Taux de clic : ${stats['click_rate'] ?? 0} %',
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

  Future<bool> _confirmDelete(HomeBanner banner) async {
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Supprimer ce bandeau ?'),
            content: Text(
              'Le bandeau « ${banner.title} » sera définitivement supprimé. '
              'Cette action est irréversible.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Annuler'),
              ),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                  foregroundColor: Theme.of(context).colorScheme.onError,
                ),
                onPressed: () => Navigator.pop(context, true),
                icon: const Icon(Icons.delete_forever_rounded),
                label: const Text('Supprimer'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed || !mounted) return false;

    try {
      await _service.delete(banner);
      return true;
    } catch (error) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Suppression impossible : $error')),
      );
      return false;
    }
  }

  Widget _deleteBackground() {
    return Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.error,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.delete_forever_rounded,
            color: Theme.of(context).colorScheme.onError,
          ),
          const SizedBox(height: 4),
          Text(
            'Supprimer',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onError,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bandeaux d’accueil'),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh_rounded)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Nouveau'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
          ? const Center(child: Text('Aucun bandeau.'))
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
                itemCount: _items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final b = _items[index];
                  final archived = b.archivedAt != null;
                  return Dismissible(
                    key: ValueKey<String>('home-banner-${b.id}'),
                    direction: DismissDirection.endToStart,
                    background: _deleteBackground(),
                    confirmDismiss: (_) => _confirmDelete(b),
                    onDismissed: (_) {
                      setState(() {
                        _items = _items
                            .where((item) => item.id != b.id)
                            .toList(growable: false);
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Bandeau supprimé.')),
                      );
                    },
                    child: Card(
                      margin: EdgeInsets.zero,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    b.title,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(
                                          decoration: archived
                                              ? TextDecoration.lineThrough
                                              : null,
                                        ),
                                  ),
                                ),
                                if (archived)
                                  const Chip(label: Text('Archivé'))
                                else
                                  Switch(
                                    value: b.isActive,
                                    onChanged: (v) async {
                                      await _service.setActive(b.id, v);
                                      await _load();
                                    },
                                  ),
                              ],
                            ),
                            if (b.message?.isNotEmpty == true)
                              Text(
                                b.message!,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            const SizedBox(height: 6),
                            Text(
                              '${b.style} • ${b.actionType} • ordre ${b.sortOrder} • '
                              '${b.platforms.join(', ')} • ${b.audiences.join(', ')}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 2,
                              children: [
                                IconButton(
                                  tooltip: 'Monter',
                                  onPressed: !archived && index > 0
                                      ? () => _move(index, -1)
                                      : null,
                                  icon: const Icon(Icons.arrow_upward_rounded),
                                ),
                                IconButton(
                                  tooltip: 'Descendre',
                                  onPressed:
                                      !archived && index < _items.length - 1
                                      ? () => _move(index, 1)
                                      : null,
                                  icon: const Icon(
                                    Icons.arrow_downward_rounded,
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Modifier',
                                  onPressed: archived ? null : () => _edit(b),
                                  icon: const Icon(Icons.edit_rounded),
                                ),
                                IconButton(
                                  tooltip: 'Dupliquer',
                                  onPressed: archived
                                      ? null
                                      : () async {
                                          await _service.duplicate(b);
                                          await _load();
                                        },
                                  icon: const Icon(Icons.copy_rounded),
                                ),
                                IconButton(
                                  tooltip: 'Statistiques',
                                  onPressed: () => _showStats(b),
                                  icon: const Icon(Icons.analytics_outlined),
                                ),
                                IconButton(
                                  tooltip: 'Archiver',
                                  onPressed: archived
                                      ? null
                                      : () async {
                                          await _service.archive(b.id);
                                          await _load();
                                        },
                                  icon: const Icon(Icons.archive_outlined),
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
            ),
    );
  }
}
