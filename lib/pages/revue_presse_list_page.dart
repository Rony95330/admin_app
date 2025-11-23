import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../theme/brand_colors.dart';
import 'revue_presse_update_page.dart';

class RevuePresseListPage extends StatefulWidget {
  const RevuePresseListPage({super.key});

  @override
  State<RevuePresseListPage> createState() => _RevuePresseListPageState();
}

class _RevuePresseListPageState extends State<RevuePresseListPage> {
  final supa = Supabase.instance.client;
  bool _loading = true;
  List<Map<String, dynamic>> _revues = [];

  @override
  void initState() {
    super.initState();
    _fetchRevues();
  }

  Future<void> _fetchRevues() async {
    setState(() => _loading = true);
    try {
      final res = await supa
          .from('revue_presse')
          .select('id, titre, pdf_url, image_url, date_publication')
          .order('date_publication', ascending: false);
      setState(() {
        _revues = List<Map<String, dynamic>>.from(res);
      });
    } catch (e) {
      debugPrint('⚠️ Erreur chargement revues de presse: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erreur de chargement: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  /// Extrait le chemin de stockage à partir de l’URL publique Supabase
  /// ex: https://xxx.supabase.co/storage/v1/object/public/revue_presse/AAA/BBB.pdf
  ///      -> AAA/BBB.pdf
  String _extractStoragePathFromPublicUrl(String? url) {
    if (url == null || url.isEmpty) return '';
    const marker = '/storage/v1/object/public/revue_presse/';
    final idx = url.indexOf(marker);
    if (idx == -1) return '';
    return url.substring(idx + marker.length);
  }

  Future<void> _deleteRevue(Map<String, dynamic> revue) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Supprimer cette revue de presse ?'),
        content: const Text(
          'Cette action supprimera définitivement l’entrée ainsi que le PDF et la miniature associés (si disponibles).',
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
      final id = revue['id'] as int;
      final pdfUrl = revue['pdf_url'] as String?;
      final imageUrl = revue['image_url'] as String?;

      // On supprime d'abord la ligne en BDD
      await supa.from('revue_presse').delete().eq('id', id);

      // Ensuite on tente de purger les fichiers du Storage (si on arrive à retrouver le path)
      final paths = <String>[];
      final pdfPath = _extractStoragePathFromPublicUrl(pdfUrl);
      final imagePath = _extractStoragePathFromPublicUrl(imageUrl);

      if (pdfPath.isNotEmpty) paths.add(pdfPath);
      if (imagePath.isNotEmpty) paths.add(imagePath);

      if (paths.isNotEmpty) {
        await supa.storage.from('revue_presse').remove(paths);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🗑 Revue de presse supprimée.'),
            backgroundColor: AppColors.vert,
          ),
        );
      }

      _fetchRevues();
    } catch (e) {
      debugPrint('❌ Erreur suppression revue de presse: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erreur: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final fmt = DateFormat('dd/MM/yyyy');

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.marine,
        title: const Text('📰 Revues de presse'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Rafraîchir',
            onPressed: _fetchRevues,
          ),
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            tooltip: 'Nouvelle revue de presse',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const RevuePresseUpdatePage(),
                ),
              ).then((_) => _fetchRevues());
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _revues.isEmpty
          ? const Center(child: Text('Aucune revue de presse publiée.'))
          : RefreshIndicator(
              onRefresh: _fetchRevues,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _revues.length,
                itemBuilder: (context, index) {
                  final revue = _revues[index];
                  final date = revue['date_publication'] != null
                      ? fmt.format(DateTime.parse(revue['date_publication']))
                      : '-';

                  final titre = revue['titre'] ?? 'Sans titre';
                  final imageUrl = revue['image_url'] as String?;
                  final pdfUrl = revue['pdf_url'] as String?;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    elevation: 1,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListTile(
                      leading: imageUrl != null && imageUrl.isNotEmpty
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: Image.network(
                                imageUrl,
                                width: 40,
                                height: 40,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const Icon(
                                  Icons.picture_as_pdf,
                                  color: AppColors.rose,
                                ),
                              ),
                            )
                          : const Icon(
                              Icons.picture_as_pdf,
                              color: AppColors.rose,
                            ),
                      title: Text(
                        titre,
                        style: text.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: Text('Publié le: $date', style: text.bodySmall),
                      trailing: IconButton(
                        icon: const Icon(
                          Icons.delete_outline,
                          color: AppColors.rouge,
                        ),
                        tooltip: 'Supprimer',
                        onPressed: () => _deleteRevue(revue),
                      ),
                      onTap: () {
                        if (pdfUrl != null && pdfUrl.isNotEmpty) {
                          _openPdf(pdfUrl);
                        }
                      },
                    ),
                  );
                },
              ),
            ),
    );
  }

  void _openPdf(String url) {
    // Pour l’instant on se contente de logger l’URL.
    // Tu pourras brancher url_launcher ou un viewer interne plus tard.
    // ignore: avoid_print
    print('📄 Open PDF: $url');
  }
}
