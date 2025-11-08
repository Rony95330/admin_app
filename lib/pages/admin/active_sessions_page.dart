import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme/brand_colors.dart';

class ActiveSessionsPage extends StatefulWidget {
  const ActiveSessionsPage({super.key});

  @override
  State<ActiveSessionsPage> createState() => _ActiveSessionsPageState();
}

class _ActiveSessionsPageState extends State<ActiveSessionsPage> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _sessions = [];
  bool _loading = true;
  Timer? _autoRefreshTimer;

  @override
  void initState() {
    super.initState();
    _fetchSessions();
    _startAutoRefresh();
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    super.dispose();
  }

  /// 🔁 Auto-refresh toutes les 30 secondes
  void _startAutoRefresh() {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _fetchSessions(silent: true);
    });
  }

  /// 🔹 Récupère les sessions actives
  Future<void> _fetchSessions({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);
    try {
      final data = await supabase
          .from('user_sessions')
          .select('user_id, matriculeaf, cse, level, last_activity, is_active')
          .order('last_activity', ascending: false);

      setState(() {
        _sessions = List<Map<String, dynamic>>.from(data);
      });
    } catch (e) {
      debugPrint('❌ Erreur fetch sessions: $e');
    } finally {
      if (!silent) setState(() => _loading = false);
    }
  }

  /// 🔸 Formate la durée depuis la dernière activité
  String _formatDuration(DateTime lastActivity) {
    final diff = DateTime.now().difference(lastActivity);
    if (diff.inMinutes < 1) return "Active";
    if (diff.inMinutes < 60) return "${diff.inMinutes} min";
    if (diff.inHours < 24) return "${diff.inHours} h";
    return "${diff.inDays} j";
  }

  /// 🔴 Déconnecte tout le monde via la fonction SQL
  Future<void> _forceLogoutAll() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Déconnecter tout le monde ?'),
        content: const Text(
          "Cette action mettra fin à toutes les sessions actives immédiatement.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.rouge),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await supabase.rpc('purge_sessions');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Tous les utilisateurs ont été déconnectés.'),
          backgroundColor: AppColors.vert,
        ),
      );

      await _fetchSessions(); // 🔄 rafraîchit la liste
    } catch (e) {
      debugPrint('❌ Erreur purge_sessions: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur : $e'),
          backgroundColor: AppColors.rouge,
        ),
      );
    }
  }

  /// 🔹 Déconnecte une session spécifique
  Future<void> _disconnectSingleSession(Map<String, dynamic> session) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Déconnecter cet utilisateur ?'),
        content: Text(
          'Voulez-vous vraiment déconnecter le matricule '
          '${session['matriculeaf'] ?? 'inconnu'} ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.rouge,
              foregroundColor: Colors.white,
            ),
            child: const Text('Déconnecter'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await supabase.rpc(
        'disconnect_session',
        params: {'p_user_id': session['user_id']},
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '✅ Utilisateur ${session['matriculeaf'] ?? ''} déconnecté.',
          ),
          backgroundColor: AppColors.vert,
        ),
      );

      setState(() {
        _sessions.removeWhere((s) => s['user_id'] == session['user_id']);
      });
    } catch (e) {
      debugPrint('❌ Erreur disconnect_session: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur : $e'),
          backgroundColor: AppColors.rouge,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sessions actives'),
        backgroundColor: cs.primary,
        foregroundColor: cs.onPrimary,
        actions: [
          IconButton(
            tooltip: 'Rafraîchir',
            icon: const Icon(Icons.refresh),
            onPressed: _fetchSessions,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetchSessions,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Utilisateurs actifs : ${_sessions.length}',
                        style: text.titleMedium?.copyWith(
                          color: cs.onSurface,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: _forceLogoutAll,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.rouge,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            vertical: 10,
                            horizontal: 14,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(Icons.power_settings_new),
                        label: const Text("Déconnecter tout le monde"),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // 🧾 Tableau des sessions
                  Container(
                    decoration: BoxDecoration(
                      color: cs.surface,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: DataTable(
                      headingRowColor: WidgetStateProperty.all(
                        cs.primary.withOpacity(0.1),
                      ),
                      columns: const [
                        DataColumn(label: Text('Matricule')),
                        DataColumn(label: Text('CSE')),
                        DataColumn(label: Text('Rôle')),
                        DataColumn(label: Text('Dernière activité')),
                        DataColumn(label: Text('Inactivité')),
                        DataColumn(label: Text('')),
                      ],
                      rows: _sessions.map((s) {
                        final lastActivity = DateTime.parse(s['last_activity']);
                        return DataRow(
                          color: WidgetStateProperty.all(
                            s['is_active'] == true
                                ? Colors.transparent
                                : Colors.red.withOpacity(0.05),
                          ),
                          cells: [
                            DataCell(Text(s['matriculeaf'] ?? '')),
                            DataCell(Text(s['cse'] ?? '-')),
                            DataCell(
                              Text(
                                s['level'] ?? '',
                                style: TextStyle(
                                  color: s['level'] == 'adm'
                                      ? AppColors.marine
                                      : s['level'] == 'supuser'
                                      ? AppColors.vert
                                      : AppColors.ardoise,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            DataCell(
                              Text(
                                "${lastActivity.hour.toString().padLeft(2, '0')}:${lastActivity.minute.toString().padLeft(2, '0')} "
                                "(${lastActivity.day.toString().padLeft(2, '0')}/${lastActivity.month.toString().padLeft(2, '0')})",
                              ),
                            ),
                            DataCell(Text(_formatDuration(lastActivity))),
                            DataCell(
                              IconButton(
                                icon: const Icon(
                                  Icons.logout,
                                  color: Colors.redAccent,
                                ),
                                tooltip: 'Déconnecter cet utilisateur',
                                onPressed: () => _disconnectSingleSession(s),
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: Text(
                      '⟳ Rafraîchissement automatique toutes les 30 secondes',
                      style: text.bodySmall?.copyWith(
                        color: Colors.grey.shade600,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
