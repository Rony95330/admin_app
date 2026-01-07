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

  // ✅ Toggle pour afficher/masquer les sessions inactives
  bool _showInactive = true;

  // ✅ Active/désactive les logs en console
  static const bool _debugSessions = true;

  void _log(String msg) {
    if (_debugSessions) debugPrint('🧪 [ActiveSessions] $msg');
  }

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

  /// 🔹 Récupère les sessions (app + console)
  Future<void> _fetchSessions({bool silent = false}) async {
    if (!silent && mounted) setState(() => _loading = true);

    final session = supabase.auth.currentSession;
    final user = session?.user;

    _log('Auth currentSession = ${session == null ? "NULL" : "OK"}');
    _log('Auth user = ${user?.id ?? "NULL"}');

    try {
      _log('SELECT user_sessions ...');

      final data = await supabase
          .from('user_sessions')
          .select(
            'id, user_id, matriculeaf, cse, level, client_kind, device_id, last_activity, is_active',
          )
          .order('last_activity', ascending: false);

      var list = List<Map<String, dynamic>>.from(data);

      if (!_showInactive) {
        list = list.where((r) => r['is_active'] == true).toList();
      }

      _log('SELECT OK: rows=${list.length}');

      if (list.isNotEmpty) {
        final keys = list.first.keys.toList()..sort();
        _log('First row keys: $keys');
      }

      final adminConsoleRows = list.where(
        (r) => (r['client_kind']?.toString() == 'admin_console'),
      );
      _log('Rows client_kind=admin_console: ${adminConsoleRows.length}');

      final myRows = (user == null)
          ? <Map<String, dynamic>>[]
          : list.where((r) => r['user_id']?.toString() == user.id).toList();
      _log('Rows for current user_id: ${myRows.length}');

      if (mounted) {
        setState(() => _sessions = list);
      }
    } catch (e) {
      _log('❌ SELECT FAILED: $e');

      if (mounted && !silent) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lecture user_sessions: $e'),
            backgroundColor: AppColors.rouge,
          ),
        );
      }
    } finally {
      if (mounted && !silent) setState(() => _loading = false);
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

  String _formatClientKind(String? kind) {
    final k = (kind ?? '').toLowerCase().trim();
    if (k == 'admin_console') return 'CONSOLE';
    return 'APP';
  }

  Color _clientKindColor(String? kind) {
    final k = (kind ?? '').toLowerCase().trim();
    if (k == 'admin_console') return AppColors.marine;
    return AppColors.ardoise;
  }

  /// 🔴 Déconnecte tout le monde (sauf consoles admin si param true)
  Future<void> _forceLogoutAll() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Déconnecter tout le monde ?'),
        content: const Text(
          "Cette action mettra fin à toutes les sessions actives immédiatement.\n"
          "Les sessions 'CONSOLE' admin peuvent être conservées.",
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
      _log('RPC purge_sessions(p_keep_admin_console=true) ...');
      await supabase.rpc(
        'purge_sessions',
        params: {'p_keep_admin_console': true},
      );
      _log('RPC purge_sessions OK');

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Déconnexion de masse effectuée.'),
          backgroundColor: AppColors.vert,
        ),
      );

      // ✅ IMPORTANT: on refetch systématiquement pour refléter l’état réel en base
      await _fetchSessions();
    } catch (e) {
      _log('❌ RPC purge_sessions FAILED: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur : $e'),
          backgroundColor: AppColors.rouge,
        ),
      );
    }
  }

  /// 🔹 Déconnecte une session spécifique (par id de ligne)
  Future<void> _disconnectSingleSession(Map<String, dynamic> session) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Déconnecter cette session ?'),
        content: Text(
          'Voulez-vous vraiment déconnecter la session du matricule '
          '${session['matriculeaf'] ?? 'inconnu'} '
          '(${_formatClientKind(session['client_kind'])}) ?',
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
      final rowId = session['id'];
      if (rowId == null) throw Exception('Session id manquant');

      _log('RPC disconnect_session_by_id(id=$rowId) ...');
      await supabase.rpc(
        'disconnect_session_by_id',
        params: {'p_session_row_id': rowId},
      );
      _log('RPC disconnect_session_by_id OK');

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '✅ Session ${session['matriculeaf'] ?? ''} (${_formatClientKind(session['client_kind'])}) déconnectée.',
          ),
          backgroundColor: AppColors.vert,
        ),
      );

      // ✅ IMPORTANT: on refetch pour refléter l’état réel en base (is_active=false, etc.)
      await _fetchSessions(silent: true);
    } catch (e) {
      _log('❌ RPC disconnect_session_by_id FAILED: $e');
      if (!mounted) return;
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
                        'Sessions : ${_sessions.length}',
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
                        label: const Text("Déconnecter tout (hors console)"),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // ✅ Toggle affichage inactifs (évite la confusion)
                  Row(
                    children: [
                      Switch(
                        value: _showInactive,
                        onChanged: (v) async {
                          setState(() => _showInactive = v);
                          await _fetchSessions();
                        },
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _showInactive
                            ? "Afficher aussi les sessions déconnectées"
                            : "Afficher uniquement les sessions actives",
                        style: text.bodyMedium,
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  Container(
                    decoration: BoxDecoration(
                      color: cs.surface,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        headingRowColor: WidgetStateProperty.all(
                          cs.primary.withOpacity(0.1),
                        ),
                        columns: const [
                          DataColumn(label: Text('Matricule')),
                          DataColumn(label: Text('CSE')),
                          DataColumn(label: Text('Rôle')),
                          DataColumn(label: Text('Contexte')),
                          DataColumn(label: Text('Dernière activité')),
                          DataColumn(label: Text('Statut')),
                          DataColumn(label: Text('')),
                        ],
                        rows: _sessions.map((s) {
                          final lastActivity = DateTime.parse(
                            s['last_activity'],
                          );
                          final isActive = s['is_active'] == true;

                          final statusText = isActive
                              ? _formatDuration(lastActivity)
                              : 'Déconnecté';

                          return DataRow(
                            color: WidgetStateProperty.all(
                              isActive
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
                                    color: (s['level'] == 'adm')
                                        ? AppColors.marine
                                        : (s['level'] == 'supuser')
                                        ? AppColors.vert
                                        : AppColors.ardoise,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              DataCell(
                                Text(
                                  _formatClientKind(s['client_kind']),
                                  style: TextStyle(
                                    color: _clientKindColor(s['client_kind']),
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
                              DataCell(
                                Text(
                                  statusText,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: isActive
                                        ? cs.onSurface
                                        : AppColors.rouge,
                                  ),
                                ),
                              ),
                              DataCell(
                                IconButton(
                                  icon: const Icon(
                                    Icons.logout,
                                    color: Colors.redAccent,
                                  ),
                                  tooltip: 'Déconnecter cette session',
                                  onPressed: isActive
                                      ? () => _disconnectSingleSession(s)
                                      : null, // pas besoin de déconnecter déjà off
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
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
