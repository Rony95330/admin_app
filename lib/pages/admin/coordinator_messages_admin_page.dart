import 'package:flutter/material.dart';

import '../../core/coordinator_message/coordinator_message_model.dart';
import '../../core/coordinator_message/coordinator_message_service.dart';
import '../../theme/brand_colors.dart';
import 'coordinator_message_edit_page.dart';

class CoordinatorMessagesAdminPage extends StatefulWidget {
  const CoordinatorMessagesAdminPage({
    super.key,
    this.initialCse,
    this.service,
  });

  final String? initialCse;
  final CoordinatorMessageService? service;

  @override
  State<CoordinatorMessagesAdminPage> createState() =>
      _CoordinatorMessagesAdminPageState();
}

class _CoordinatorMessagesAdminPageState
    extends State<CoordinatorMessagesAdminPage> {
  late final CoordinatorMessageService _service;
  List<CoordinatorMessage> _items = const <CoordinatorMessage>[];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? CoordinatorMessageService();
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
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Chargement impossible : $error')));
    }
  }

  Future<void> _edit([CoordinatorMessage? message]) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => CoordinatorMessageEditPage(
          message: message,
          initialCse: message?.cse ?? widget.initialCse,
          service: _service,
        ),
      ),
    );
    if (changed == true) await _load();
  }

  Future<bool> _confirmDelete(CoordinatorMessage message) async {
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Supprimer ce message ?'),
            content: Text(
              'Le mot de ${message.coordinatorName} pour ${message.cse} '
              'sera définitivement supprimé.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Annuler'),
              ),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
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
      await _service.delete(message.id);
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
        borderRadius: BorderRadius.circular(16),
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
              fontWeight: FontWeight.w800,
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
        title: const Text('Mots des coordinateurs'),
        actions: [
          IconButton(
            tooltip: 'Actualiser',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
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
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.format_quote_rounded,
                      size: 56,
                      color: AppColors.orange,
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Aucun mot du coordinateur.',
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Appuyez sur « Nouveau » pour créer le premier message.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: Scrollbar(
                thumbVisibility: MediaQuery.sizeOf(context).width >= 600,
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 110),
                  itemCount: _items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final message = _items[index];
                    return Dismissible(
                      key: ValueKey<String>(
                        'coordinator-message-${message.id}',
                      ),
                      direction: DismissDirection.endToStart,
                      background: _deleteBackground(),
                      confirmDismiss: (_) => _confirmDelete(message),
                      onDismissed: (_) {
                        setState(() {
                          _items = _items
                              .where((item) => item.id != message.id)
                              .toList(growable: false);
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Message supprimé.')),
                        );
                      },
                      child: Card(
                        margin: EdgeInsets.zero,
                        child: Padding(
                          padding: const EdgeInsets.all(13),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CircleAvatar(
                                radius: 34,
                                backgroundColor: AppColors.orange.withValues(
                                  alpha: 0.12,
                                ),
                                child: Text(
                                  message.initials,
                                  style: const TextStyle(
                                    color: AppColors.orange,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 13),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      message.coordinatorName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w800,
                                          ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      message.cse,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelMedium
                                          ?.copyWith(
                                            color: AppColors.orange,
                                            fontWeight: FontWeight.w800,
                                          ),
                                    ),
                                    if (message.headline?.isNotEmpty ==
                                        true) ...[
                                      const SizedBox(height: 5),
                                      Text(
                                        message.headline!,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.w700,
                                            ),
                                      ),
                                    ],
                                    const SizedBox(height: 4),
                                    Text(
                                      message.excerpt,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodySmall,
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        IconButton(
                                          tooltip: 'Modifier',
                                          onPressed: () => _edit(message),
                                          icon: const Icon(Icons.edit_rounded),
                                        ),
                                        const Spacer(),
                                        const Text('Actif'),
                                        Switch(
                                          value: message.isActive,
                                          onChanged: (value) async {
                                            try {
                                              await _service.setActive(
                                                message,
                                                value,
                                              );
                                              await _load();
                                            } catch (error) {
                                              if (!context.mounted) return;
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    'Modification impossible : $error',
                                                  ),
                                                ),
                                              );
                                            }
                                          },
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
    );
  }
}
