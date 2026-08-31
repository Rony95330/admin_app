import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../theme/brand_colors.dart';
import 'adh_ticket_thread_page.dart';

class AdhExchangeAdminPage extends StatefulWidget {
  const AdhExchangeAdminPage({super.key});

  @override
  State<AdhExchangeAdminPage> createState() => _AdhExchangeAdminPageState();
}

class _AdhExchangeAdminPageState extends State<AdhExchangeAdminPage> {
  final SupabaseClient _supa = Supabase.instance.client;
  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> _tickets = const <Map<String, dynamic>>[];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _supa.rpc(
        'get_section_ticket_inbox',
        params: <String, dynamic>{'p_archived': false},
      );
      final tickets = List<Map<String, dynamic>>.from(data);
      if (!mounted) return;
      setState(() => _tickets = tickets);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> get _filtered {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return _tickets;
    return _tickets.where((ticket) {
      return <dynamic>[
        ticket['prenom'],
        ticket['nom'],
        ticket['email'],
        ticket['category'],
        ticket['cse_code'],
        ticket['last_message'],
      ].any(
        (value) => value?.toString().toLowerCase().contains(query) ?? false,
      );
    }).toList();
  }

  int _unread(Map<String, dynamic> ticket) {
    final value = ticket['unread_staff_count'];
    return value is int ? value : int.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _name(Map<String, dynamic> ticket) {
    final fullName = <String>[
      ticket['prenom']?.toString().trim() ?? '',
      ticket['nom']?.toString().trim() ?? '',
    ].where((value) => value.isNotEmpty).join(' ');
    if (fullName.isNotEmpty) return fullName;
    final email = ticket['email']?.toString().trim() ?? '';
    if (email.isNotEmpty) return email;
    return 'Adhérent';
  }

  String _date(dynamic raw) {
    final date = DateTime.tryParse(raw?.toString() ?? '');
    if (date == null) return '';
    return DateFormat('dd/MM/yyyy HH:mm', 'fr_FR').format(date.toLocal());
  }

  Color _statusColor(String status) {
    switch (status.toUpperCase()) {
      case 'CLOSED':
        return AppColors.anthracite;
      case 'IN_PROGRESS':
        return AppColors.orangeClair;
      default:
        return AppColors.vert;
    }
  }

  Future<void> _open(Map<String, dynamic> ticket) async {
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => AdhTicketThreadPage(ticket: ticket),
      ),
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final tickets = _filtered;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Demandes adhérents'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Actualiser',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
            child: TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                hintText: 'Rechercher un adhérent, un CSE ou une demande',
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Erreur : $_error',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : tickets.isEmpty
                ? const Center(child: Text('Aucune demande en cours.'))
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(18, 18, 18, 40),
                    itemCount: tickets.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final ticket = tickets[index];
                      final unread = _unread(ticket);
                      final status = (ticket['status'] ?? 'OPEN').toString();
                      return Card(
                        margin: EdgeInsets.zero,
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(16),
                          leading: CircleAvatar(
                            backgroundColor: unread > 0
                                ? AppColors.orange
                                : AppColors.grisBleute,
                            foregroundColor: unread > 0
                                ? Colors.white
                                : AppColors.anthracite,
                            child: unread > 0
                                ? Text('$unread')
                                : const Icon(Icons.person_outline),
                          ),
                          title: Text(
                            _name(ticket),
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 7),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  (ticket['category'] ?? 'Demande').toString(),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  <String>[
                                        ticket['cse_code']?.toString() ?? '',
                                        _date(ticket['updated_at']),
                                      ]
                                      .where((value) => value.isNotEmpty)
                                      .join(' • '),
                                ),
                                if ((ticket['last_message'] ?? '')
                                    .toString()
                                    .trim()
                                    .isNotEmpty) ...<Widget>[
                                  const SizedBox(height: 5),
                                  Text(
                                    ticket['last_message'].toString(),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ],
                            ),
                          ),
                          trailing: Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: _statusColor(status),
                              shape: BoxShape.circle,
                            ),
                          ),
                          onTap: () => _open(ticket),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
