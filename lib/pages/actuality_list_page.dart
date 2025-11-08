import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme/brand_colors.dart';
import 'actuality_update_page.dart';

class ActualityListPage extends StatefulWidget {
  const ActualityListPage({super.key});

  @override
  State<ActualityListPage> createState() => _ActualityListPageState();
}

class _ActualityListPageState extends State<ActualityListPage> {
  final supa = Supabase.instance.client;
  bool _loading = true;
  List<Map<String, dynamic>> _articles = [];

  @override
  void initState() {
    super.initState();
    _fetchArticles();
  }

  Future<void> _fetchArticles() async {
    setState(() => _loading = true);
    try {
      final res = await supa
          .from('articles')
          .select('id, title, cse, author, published_at, pdf_url')
          .order('published_at', ascending: false);
      setState(() => _articles = List<Map<String, dynamic>>.from(res));
    } catch (e) {
      debugPrint('⚠️ Erreur chargement articles: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erreur de chargement: $e')));
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _deleteArticle(int id, String storagePath) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Supprimer l’article ?'),
        content: const Text(
          'Cette action supprimera définitivement le document et sa miniature.',
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
      await supa.from('articles').delete().eq('id', id);

      // Supprime le fichier PDF associé (si tu veux vraiment le purger du Storage)
      if (storagePath.isNotEmpty) {
        await supa.storage.from('Articles').remove([storagePath]);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🗑 Article supprimé.'),
          backgroundColor: AppColors.vert,
        ),
      );

      _fetchArticles();
    } catch (e) {
      debugPrint('❌ Erreur suppression: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erreur: $e')));
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
        title: const Text('📰 Actualités publiées'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Rafraîchir',
            onPressed: _fetchArticles,
          ),
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            tooltip: 'Nouvelle actualité',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ActualityUpdatePage()),
              ).then((_) => _fetchArticles());
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _articles.isEmpty
          ? const Center(child: Text('Aucune actualité publiée.'))
          : RefreshIndicator(
              onRefresh: _fetchArticles,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _articles.length,
                itemBuilder: (context, index) {
                  final art = _articles[index];
                  final date = art['published_at'] != null
                      ? fmt.format(DateTime.parse(art['published_at']))
                      : '-';
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    elevation: 1,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListTile(
                      leading: const Icon(
                        Icons.picture_as_pdf,
                        color: AppColors.rose,
                      ),
                      title: Text(
                        art['title'] ?? 'Sans titre',
                        style: text.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: Text(
                        'CSE: ${art['cse'] ?? '-'} • Auteur: ${art['author'] ?? '-'} • Publié: $date',
                        style: text.bodySmall,
                      ),
                      trailing: IconButton(
                        icon: const Icon(
                          Icons.delete_outline,
                          color: AppColors.rouge,
                        ),
                        tooltip: 'Supprimer',
                        onPressed: () => _deleteArticle(
                          art['id'] as int,
                          art['storage_path'] ?? '',
                        ),
                      ),
                      onTap: () {
                        final pdfUrl = art['pdf_url'];
                        if (pdfUrl != null && pdfUrl.toString().isNotEmpty) {
                          launchUrl(pdfUrl.toString());
                        }
                      },
                    ),
                  );
                },
              ),
            ),
    );
  }

  void launchUrl(String url) {
    // Simple ouverture via navigateur (web ou externe)
    Supabase.instance.client.auth; // pour éviter l'import inutile
    // ignore: avoid_print
    print('📄 Open: $url');
  }
}
