import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final supa = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();

  String _title = '';
  String _content = '';
  bool _loading = false;
  String? _status;

  List<Map<String, dynamic>> _history = [];
  bool _loadingHistory = false;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _send() async {
    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid) return;

    _formKey.currentState!.save();
    setState(() {
      _loading = true;
      _status = null;
    });

    try {
      // 1️⃣ Encodage des filtres en base64
      final filtersJson = jsonEncode({});
      final filtersBase64 = base64Encode(utf8.encode(filtersJson));

      // 2️⃣ Insertion dans l’outbox
      final payload = {
        'type': _title,
        'content': _content,
        'attachment_url': "",
        'filters': filtersBase64,
        'status': 'queued',
      };

      final row = await supa
          .from('notification_outbox')
          .insert(payload)
          .select()
          .single();

      final outboxId = row['id'];

      // 3️⃣ Déclenchement de la fonction
      print("Notification insérée avec ID: $outboxId");

      final res = await supa.functions.invoke(
        'send_push_from_outbox',
        body: {'outbox_id': outboxId},
      );

      if (res.status >= 400) {
        setState(() => _status = "Erreur function: ${res.data}");
      } else {
        setState(
          () => _status =
              "Notification envoyée ✅ (id: $outboxId)\nRéponse: ${res.data}",
        );
      }

      // 4️⃣ Recharge historique
      await _loadHistory();
    } catch (e) {
      setState(() => _status = "Erreur : $e");
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _loadHistory() async {
    setState(() {
      _loadingHistory = true;
    });
    try {
      final rows = await supa
          .from('notification_outbox')
          .select('id, type, content, status, created_at')
          .order('created_at', ascending: false)
          .limit(10);

      setState(() {
        _history = List<Map<String, dynamic>>.from(rows);
      });
    } catch (e) {
      setState(() {
        _status = "Erreur historique : $e";
      });
    } finally {
      setState(() {
        _loadingHistory = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Envoyer une notification",
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 20),

            Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    decoration: const InputDecoration(
                      labelText: "Titre",
                      border: OutlineInputBorder(),
                    ),
                    onSaved: (v) => _title = (v ?? '').trim(),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? "Champ requis" : null,
                  ),
                  const SizedBox(height: 12),

                  TextFormField(
                    decoration: const InputDecoration(
                      labelText: "Message",
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 5,
                    onSaved: (v) => _content = (v ?? '').trim(),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? "Champ requis" : null,
                  ),
                  const SizedBox(height: 20),

                  ElevatedButton.icon(
                    icon: _loading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send),
                    label: const Text("Envoyer"),
                    onPressed: _loading ? null : _send,
                  ),
                ],
              ),
            ),

            if (_status != null) ...[
              const SizedBox(height: 20),
              Text(
                _status!,
                style: TextStyle(
                  color: _status!.startsWith("Erreur")
                      ? Colors.red
                      : Colors.green,
                ),
              ),
            ],

            const SizedBox(height: 40),
            Row(
              children: [
                Text(
                  "Historique des notifications",
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const Spacer(),
                IconButton(
                  tooltip: "Recharger",
                  icon: const Icon(Icons.refresh),
                  onPressed: _loadingHistory ? null : _loadHistory,
                ),
              ],
            ),
            const SizedBox(height: 10),

            if (_loadingHistory)
              const Center(child: CircularProgressIndicator())
            else if (_history.isEmpty)
              const Text("Aucune notification trouvée")
            else
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text("ID")),
                    DataColumn(label: Text("Titre")),
                    DataColumn(label: Text("Contenu")),
                    DataColumn(label: Text("Status")),
                    DataColumn(label: Text("Créé le")),
                  ],
                  rows: _history
                      .map(
                        (row) => DataRow(
                          cells: [
                            DataCell(Text(row['id'].toString())),
                            DataCell(Text(row['type'] ?? '')),
                            DataCell(Text(row['content'] ?? '')),
                            DataCell(Text(row['status'] ?? '')),
                            DataCell(Text(row['created_at'] ?? '')),
                          ],
                        ),
                      )
                      .toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
