import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme/brand_colors.dart';
import 'notification_create_page.dart';

// SnackBar + ErrorStateView

// 👉 Si tu as une page détail dans l'admin, importe-la ici.
// Sinon, si tu veux ouvrir la page détail "utilisateur", adapte l'import.
// import 'package:app_cfecgc_af/pages/notifications/notification_detail_page.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final supa = Supabase.instance.client;
  bool _loading = false;
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

  Future<void> _fetchNotifications() async {
    setState(() => _loading = true);
    try {
      final res = await supa
          .from('notification_outbox')
          .select(
            'id, type, message, cse, niveau, metier, status, created_at, author_id',
          )
          .order(_sortColumn, ascending: _sortAsc);

      // 🔄 Récupère les noms d'auteurs (si présents)
      final users = await supa.rpc('admin_notification_authors');

      final Map<String, String> userNames = {
        for (final u in (users as List))
          u['id'].toString(): "${u['prenom'] ?? ''} ${u['nom'] ?? ''}".trim(),
      };

      setState(() {
        _notifications = List<Map<String, dynamic>>.from(res).map((n) {
          n['author_name'] = userNames[n['author_id']] ?? 'Inconnu';
          return n;
        }).toList();
      });
    } catch (e) {
      debugPrint('Erreur chargement notifications : $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

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
      await _fetchNotifications();
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

  void _openDetail(String id) {
    // 👉 Si tu as une page détail d’admin, pousse-la ici.
    // Navigator.push(
    //   context,
    //   MaterialPageRoute(
    //     builder: (_) => NotificationDetailPage(notificationId: id),
    //   ),
    // );
    // Pour l’instant on montre un petit snackbar pour confirmer le clic.
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Ouvrir le détail pour $id')));
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
                        constraints: const BoxConstraints(minWidth: 1200),
                        child: DataTable(
                          sortAscending: _sortAsc,
                          headingRowColor: WidgetStateProperty.all(
                            cs.primary.withValues(alpha: 0.1),
                          ),
                          columns: [
                            DataColumn(
                              label: const Text('ID'),
                              onSort: (_, _) => _sortBy('id'),
                            ),
                            DataColumn(
                              label: const Text('Titre'),
                              onSort: (_, _) => _sortBy('type'),
                            ),
                            DataColumn(
                              label: const Text('Message'),
                              onSort: (_, _) => _sortBy('message'),
                            ),
                            DataColumn(
                              label: const Text('CSE'),
                              onSort: (_, _) => _sortBy('cse'),
                            ),
                            DataColumn(
                              label: const Text('Niveau'),
                              onSort: (_, _) => _sortBy('niveau'),
                            ),
                            DataColumn(
                              label: const Text('Métier'),
                              onSort: (_, _) => _sortBy('metier'),
                            ),
                            DataColumn(
                              label: const Text('Auteur'),
                              onSort: (_, _) => _sortBy('author_id'),
                            ),
                            DataColumn(
                              label: const Text('Statut'),
                              onSort: (_, _) => _sortBy('status'),
                            ),
                            DataColumn(
                              label: const Text('Créée le'),
                              onSort: (_, _) => _sortBy('created_at'),
                            ),
                            const DataColumn(label: Text('Actions')),
                          ],
                          rows: _notifications.map((row) {
                            final id = (row['id'] ?? '').toString();
                            return DataRow(
                              cells: [
                                DataCell(
                                  Text(id),
                                  onTap: () => _openDetail(id),
                                ),
                                DataCell(
                                  InkWell(
                                    onTap: () => _openDetail(id),
                                    child: Text(
                                      row['type'] ?? '',
                                      style: const TextStyle(
                                        decoration: TextDecoration.underline,
                                      ),
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Text(row['message'] ?? ''),
                                  onTap: () => _openDetail(id),
                                ),
                                DataCell(Text(row['cse'] ?? '')),
                                DataCell(Text(row['niveau'] ?? '')),
                                DataCell(Text(row['metier'] ?? '')),
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
                                    onPressed: () => _deleteNotification(id),
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
