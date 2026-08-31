import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../theme/brand_colors.dart';

class AdhTicketThreadPage extends StatefulWidget {
  const AdhTicketThreadPage({super.key, required this.ticket});

  final Map<String, dynamic> ticket;

  @override
  State<AdhTicketThreadPage> createState() => _AdhTicketThreadPageState();
}

class _AdhTicketThreadPageState extends State<AdhTicketThreadPage> {
  final SupabaseClient _supa = Supabase.instance.client;
  final TextEditingController _controller = TextEditingController();

  List<Map<String, dynamic>> _messages = const <Map<String, dynamic>>[];
  bool _loading = true;
  bool _sending = false;
  late String _status;

  @override
  void initState() {
    super.initState();
    _status = (widget.ticket['status'] ?? 'OPEN').toString();
    _load();
    _markRead();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _markRead() async {
    try {
      await _supa
          .from('adh_tickets')
          .update(<String, dynamic>{'unread_staff_count': 0})
          .eq('id', widget.ticket['id']);
    } catch (_) {}
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await _supa.rpc(
        'get_adh_ticket_messages',
        params: <String, dynamic>{'p_ticket_id': widget.ticket['id']},
      );
      if (!mounted) return;
      setState(() => _messages = List<Map<String, dynamic>>.from(data));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _updateStatus(String status) async {
    final oldStatus = _status;
    setState(() => _status = status);
    try {
      await _supa
          .from('adh_tickets')
          .update(<String, dynamic>{'status': status})
          .eq('id', widget.ticket['id']);
    } catch (error) {
      if (!mounted) return;
      setState(() => _status = oldStatus);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Statut non modifié : $error')));
    }
  }

  Future<void> _archive() async {
    await _supa
        .from('adh_tickets')
        .update(<String, dynamic>{'archived': true})
        .eq('id', widget.ticket['id']);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _send() async {
    final content = _controller.text.trim();
    final user = _supa.auth.currentUser;
    if (content.isEmpty || user == null || _sending) return;
    setState(() => _sending = true);
    try {
      await _supa.from('adh_messages').insert(<String, dynamic>{
        'ticket_id': widget.ticket['id'],
        'sender_id': user.id,
        'sender_role': 'STAFF',
        'content': content,
      });
      // Le trigger SQL trg_adh_messages_touch maintient
      // automatiquement les compteurs de messages non lus.
      _controller.clear();
      await _load();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Envoi impossible : $error')));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  String _sender(Map<String, dynamic> message) {
    final name = message['sender_name']?.toString().trim() ?? '';
    if (name.isNotEmpty) return name;
    return message['sender_role'] == 'STAFF' ? 'Équipe CFDT' : 'Adhérent';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text((widget.ticket['category'] ?? 'Demande').toString()),
        actions: <Widget>[
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _status,
              items: const <DropdownMenuItem<String>>[
                DropdownMenuItem(value: 'OPEN', child: Text('Ouvert')),
                DropdownMenuItem(value: 'IN_PROGRESS', child: Text('En cours')),
                DropdownMenuItem(value: 'CLOSED', child: Text('Clôturé')),
              ],
              onChanged: (value) {
                if (value != null) _updateStatus(value);
              },
            ),
          ),
          IconButton(
            tooltip: 'Archiver',
            onPressed: _archive,
            icon: const Icon(Icons.archive_outlined),
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    padding: const EdgeInsets.all(18),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final message = _messages[index];
                      final staff = message['sender_role'] == 'STAFF';
                      return Align(
                        alignment: staff
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          constraints: const BoxConstraints(maxWidth: 620),
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: staff
                                ? AppColors.orange.withValues(alpha: 0.13)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.grisBleute),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                _sender(message),
                                style: const TextStyle(
                                  color: AppColors.bleuPetrole,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text((message['content'] ?? '').toString()),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          SafeArea(
            top: false,
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.all(14),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      minLines: 1,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        hintText: 'Répondre à l’adhérent…',
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 10),
                  IconButton.filled(
                    onPressed: _sending ? null : _send,
                    icon: _sending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send),
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
