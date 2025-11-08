import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';
import '../../theme/brand_colors.dart';
import 'notification_create_page.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final supa = Supabase.instance.client;
  bool _loading = false;
  String? _status;
  List<Map<String, dynamic>> _notifications = [];
  bool _sortAsc = false;
  String _sortColumn = 'created_at';

  // 👉 Contrôleurs pour les scrollbars
  final ScrollController _vCtrl = ScrollController();
  final ScrollController _hCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
  }

  @override
  void dispose() {
    _vCtrl.dispose();
    _hCtrl.dispose();
    super.dispose();
  }

  /// 🔹 Récupération des notifications complètes
  Future<void> _fetchNotifications() async {
    setState(() => _loading = true);
    try {
      final res = await supa
          .from('notification_outbox')
          .select(
            'id, type, message, cse, niveau, secteur, status, created_at, author_id, filters',
          )
          .order(_sortColumn, ascending: _sortAsc);

      // 🔄 Récupère les noms d'auteurs (si présents)
      final users = await supa.from('users').select('id, prenom, nom');
      final Map<String, String> userNames = {
        for (var u in users)
          u['id']: "${u['prenom'] ?? ''} ${u['nom'] ?? ''}".trim(),
      };

      setState(() {
        _notifications = List<Map<String, dynamic>>.from(res).map((n) {
          n['author_name'] = userNames[n['author_id']] ?? 'Inconnu';
          return n;
        }).toList();
      });
    } catch (e) {
      debugPrint('❌ Erreur chargement notifications: $e');
      setState(() => _status = 'Erreur chargement : $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  /// 🔸 Supprimer une notification
  Future<void> _deleteNotification(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Supprimer la notification ?'),
        content: const Text(
          'Cette action supprimera définitivement cette notification de la base.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.rouge),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await supa.from('notification_outbox').delete().eq('id', id);
      _fetchNotifications();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🗑 Notification supprimée.'),
          backgroundColor: AppColors.vert,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur : $e'),
          backgroundColor: AppColors.rouge,
        ),
      );
    }
  }

  void _sortBy(String column) {
    setState(() {
      if (_sortColumn == column) {
        _sortAsc = !_sortAsc;
      } else {
        _sortColumn = column;
        _sortAsc = true;
      }
    });
    _fetchNotifications();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.marine,
        title: const Text('🔔 Historique des notifications'),
        actions: [
          IconButton(
            tooltip: 'Rafraîchir',
            icon: const Icon(Icons.refresh),
            onPressed: _fetchNotifications,
          ),
          IconButton(
            tooltip: 'Nouvelle notification',
            icon: const Icon(Icons.add_circle_outline),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const NotificationCreatePage(),
                ),
              );
              _fetchNotifications();
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _notifications.isEmpty
            ? const Center(child: Text('Aucune notification trouvée.'))
            : Scrollbar(
                controller: _vCtrl,
                thumbVisibility: true,
                child: SingleChildScrollView(
                  controller: _vCtrl,
                  child: Scrollbar(
                    controller: _hCtrl,
                    thumbVisibility: true,
                    notificationPredicate: (notif) =>
                        notif.metrics.axis == Axis.horizontal,
                    child: SingleChildScrollView(
                      controller: _hCtrl,
                      scrollDirection: Axis.horizontal,
                      child: ConstrainedBox(
                        // Ajuste la largeur minimale pour forcer le scroll horizontal si nécessaire
                        constraints: const BoxConstraints(minWidth: 1100),
                        child: DataTable(
                          sortAscending: _sortAsc,
                          headingRowColor: WidgetStateProperty.all(
                            cs.primary.withOpacity(0.1),
                          ),
                          columns: [
                            DataColumn(
                              label: const Text('ID'),
                              onSort: (_, __) => _sortBy('id'),
                            ),
                            DataColumn(
                              label: const Text('Titre'),
                              onSort: (_, __) => _sortBy('type'),
                            ),
                            DataColumn(
                              label: const Text('Message'),
                              onSort: (_, __) => _sortBy('message'),
                            ),
                            DataColumn(
                              label: const Text('CSE'),
                              onSort: (_, __) => _sortBy('cse'),
                            ),
                            DataColumn(
                              label: const Text('Niveau'),
                              onSort: (_, __) => _sortBy('niveau'),
                            ),
                            DataColumn(
                              label: const Text('Secteur'),
                              onSort: (_, __) => _sortBy('secteur'),
                            ),
                            DataColumn(
                              label: const Text('Auteur'),
                              onSort: (_, __) => _sortBy('author_id'),
                            ),
                            DataColumn(
                              label: const Text('Statut'),
                              onSort: (_, __) => _sortBy('status'),
                            ),
                            DataColumn(
                              label: const Text('Créée le'),
                              onSort: (_, __) => _sortBy('created_at'),
                            ),
                            const DataColumn(label: Text('Actions')),
                          ],
                          rows: _notifications.map((row) {
                            return DataRow(
                              cells: [
                                DataCell(Text(row['id'].toString())),
                                DataCell(Text(row['type'] ?? '')),
                                DataCell(Text(row['message'] ?? '')),
                                DataCell(Text(row['cse'] ?? '')),
                                DataCell(Text(row['niveau'] ?? '')),
                                DataCell(Text(row['secteur'] ?? '')),
                                DataCell(Text(row['author_name'] ?? '-')),
                                DataCell(Text(row['status'] ?? '')),
                                DataCell(
                                  Text(
                                    row['created_at']?.toString().substring(
                                          0,
                                          16,
                                        ) ??
                                        '',
                                  ),
                                ),
                                DataCell(
                                  IconButton(
                                    icon: const Icon(
                                      Icons.delete_outline,
                                      color: AppColors.rouge,
                                    ),
                                    tooltip: 'Supprimer',
                                    onPressed: () =>
                                        _deleteNotification(row['id']),
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}
