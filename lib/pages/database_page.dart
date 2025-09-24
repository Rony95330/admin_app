import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DatabasePage extends StatefulWidget {
  const DatabasePage({super.key});

  @override
  State<DatabasePage> createState() => _DatabasePageState();
}

class _DatabasePageState extends State<DatabasePage> {
  final supabase = Supabase.instance.client;

  bool _loading = false;
  List<Map<String, dynamic>> _rows = [];
  String? _error;

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // ⚡️ Exemple : table "users" (remplace par "effectif" si besoin)
      final response = await supabase.from('users').select().limit(10);

      setState(() {
        _rows = List<Map<String, dynamic>>.from(response);
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                "Gestion de la base de données",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              ElevatedButton.icon(
                icon: const Icon(Icons.refresh),
                label: const Text("Charger les données"),
                onPressed: _loadData,
              ),
            ],
          ),
          const SizedBox(height: 20),

          if (_loading) const Center(child: CircularProgressIndicator()),

          if (_error != null)
            Text("Erreur : $_error", style: const TextStyle(color: Colors.red)),

          if (!_loading && _rows.isNotEmpty)
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: _rows.first.keys
                      .map((key) => DataColumn(label: Text(key)))
                      .toList(),
                  rows: _rows
                      .map(
                        (row) => DataRow(
                          cells: row.values
                              .map((value) => DataCell(Text('$value')))
                              .toList(),
                        ),
                      )
                      .toList(),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
