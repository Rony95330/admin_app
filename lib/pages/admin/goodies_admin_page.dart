import 'package:admin_app/pages/goodies_add_page.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class GoodiesAdminPage extends StatefulWidget {
  const GoodiesAdminPage({super.key});

  @override
  State<GoodiesAdminPage> createState() => _GoodiesAdminPageState();
}

class _GoodiesAdminPageState extends State<GoodiesAdminPage> {
  final supa = Supabase.instance.client;

  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _goodies = [];

  @override
  void initState() {
    super.initState();
    _loadGoodies();
  }

  Future<void> _loadGoodies() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final res = await supa
          .from('goodies')
          .select()
          .order('created_at', ascending: false);

      setState(() {
        _goodies = List<Map<String, dynamic>>.from(res);
        _loading = false;
      });
    } on PostgrestException catch (e) {
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _openAddOrEdit({String? id}) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => GoodiesAddPage(goodieId: id)),
    );

    // Si on revient avec un succès => rechargement
    if (result == true) {
      _loadGoodies();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        backgroundColor: cs.primary,
        title: Text(
          'Gestion des goodies',
          style: GoogleFonts.poppins(
            color: cs.onPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Rafraîchir',
            onPressed: _loadGoodies,
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            tooltip: 'Ajouter un goodie',
            onPressed: () => _openAddOrEdit(),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Text(
                'Erreur : $_error',
                style: const TextStyle(color: Colors.red),
              ),
            )
          : _goodies.isEmpty
          ? const Center(child: Text('Aucun goodie enregistré'))
          : RefreshIndicator(
              onRefresh: _loadGoodies,
              child: ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: _goodies.length,
                itemBuilder: (context, index) {
                  final g = _goodies[index];
                  final actif = g['actif'] == true;
                  final stock = g['stock_theorique'];
                  final photo = g['photo_url'] as String?;

                  return Card(
                    elevation: 2,
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListTile(
                      leading: photo != null && photo.trim().isNotEmpty
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                photo,
                                width: 48,
                                height: 48,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    const Icon(Icons.image_not_supported),
                              ),
                            )
                          : const Icon(Icons.card_giftcard, size: 36),
                      title: Text(
                        g['libelle'] ?? '',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Code : ${g['code'] ?? ''}',
                            style: GoogleFonts.poppins(fontSize: 12.5),
                          ),
                          Text(
                            'Stock : ${stock ?? '—'}',
                            style: GoogleFonts.poppins(
                              fontSize: 12.5,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            actif ? Icons.check_circle : Icons.cancel_outlined,
                            color: actif
                                ? const Color(0xFF5FB670)
                                : Colors.redAccent,
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.edit),
                            tooltip: 'Modifier',
                            onPressed: () => _openAddOrEdit(id: g['id']),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}
