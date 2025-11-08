import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:pdfx/pdfx.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme/brand_colors.dart';

class ActualityUpdatePage extends StatefulWidget {
  final List<String>? cseOptions;
  const ActualityUpdatePage({super.key, this.cseOptions});

  @override
  State<ActualityUpdatePage> createState() => _ActualityUpdatePageState();
}

class _ActualityUpdatePageState extends State<ActualityUpdatePage> {
  final supa = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();

  final _titleCtl = TextEditingController();
  final _descCtl = TextEditingController();
  final _cseCtl = TextEditingController();
  DateTime _date = DateTime.now();

  PlatformFile? _pickedPdf;
  bool _saving = false;
  bool _loadingCse = true;
  List<String> _cseOptions = const [];
  bool _canPublish = false;

  @override
  void initState() {
    super.initState();
    _loadCseOptions();
    _titleCtl.addListener(_recomputeCanPublish);
  }

  @override
  void dispose() {
    _titleCtl.removeListener(_recomputeCanPublish);
    _titleCtl.dispose();
    _descCtl.dispose();
    _cseCtl.dispose();
    super.dispose();
  }

  void _recomputeCanPublish() {
    setState(() {
      _canPublish =
          _titleCtl.text.trim().isNotEmpty &&
          _cseCtl.text.trim().isNotEmpty &&
          _pickedPdf != null &&
          !_saving &&
          !_loadingCse;
    });
  }

  Future<void> _loadCseOptions() async {
    try {
      List<String> items;
      if (widget.cseOptions != null && widget.cseOptions!.isNotEmpty) {
        items = List<String>.from(widget.cseOptions!);
      } else {
        final res = await supa.from('liste_cse').select('cse');
        items =
            (res as List)
                .map((r) => (r['cse'] ?? '').toString().trim())
                .where((e) => e.isNotEmpty)
                .toList()
              ..sort();
      }

      const central = 'CENTRAL';
      final sorted = {...items, central}.toList()..sort();
      sorted.remove(central);
      sorted.insert(0, central);

      setState(() {
        _cseOptions = sorted;
        _cseCtl.text = _cseOptions.first;
        _loadingCse = false;
      });
      _recomputeCanPublish();
    } catch (e) {
      debugPrint('⚠️ Erreur chargement CSE: $e');
      setState(() {
        _cseOptions = const ['CENTRAL'];
        _cseCtl.text = 'CENTRAL';
        _loadingCse = false;
      });
      _recomputeCanPublish();
    }
  }

  Future<void> _pickPdf() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      withData: false,
    );
    if (res != null && res.files.isNotEmpty) {
      setState(() => _pickedPdf = res.files.first);
      _recomputeCanPublish();
    }
  }

  /// ✅ Correction : `height` désormais obligatoire dans `PdfPage.render`
  Future<Uint8List?> _renderPdfThumb(File file) async {
    try {
      final doc = await PdfDocument.openFile(file.path);
      final page = await doc.getPage(1);

      // 🔹 Calcul proportionnel pour garder le bon ratio
      const double targetWidth = 600.0;
      final double scale = targetWidth / page.width;
      final double targetHeight = page.height * scale;

      final img = await page.render(
        width: targetWidth,
        height: targetHeight, // ✅ requis par pdfx >= 2.5
        format: PdfPageImageFormat.png,
      );

      await page.close();
      await doc.close();
      return img?.bytes;
    } catch (e) {
      debugPrint('⚠️ Erreur rendu miniature PDF: $e');
      return null;
    }
  }

  String _sanitizeFileName(String input) {
    final base = input
        .replaceAll(RegExp(r'[^\w\s\-\.]'), '')
        .replaceAll(RegExp(r'\s+'), '_')
        .trim();
    return base.isEmpty ? 'document' : base;
  }

  Future<void> _save() async {
    if (_saving) return;

    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid || _pickedPdf == null) {
      _recomputeCanPublish();
      return;
    }

    setState(() => _saving = true);
    _recomputeCanPublish();

    try {
      final cse = _cseCtl.text.trim();
      final title = _titleCtl.text.trim();
      final desc = _descCtl.text.trim();
      final file = File(_pickedPdf!.path!);
      final fileName = _sanitizeFileName(
        _pickedPdf!.name.isNotEmpty
            ? p.basenameWithoutExtension(_pickedPdf!.name)
            : title,
      );

      final stamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final pdfStoragePath = 'articles_admin/$cse/${fileName}_$stamp.pdf';
      final thumbStoragePath =
          'articles_admin/thumbs/$cse/${fileName}_$stamp.png';

      // 🟢 Upload PDF
      final pdfBytes = await file.readAsBytes();
      await supa.storage
          .from('Articles')
          .uploadBinary(
            pdfStoragePath,
            pdfBytes,
            fileOptions: const FileOptions(
              contentType: 'application/pdf',
              upsert: false,
            ),
          );
      final pdfUrl = supa.storage.from('Articles').getPublicUrl(pdfStoragePath);

      // 🟣 Miniature
      String? thumbUrl;
      final thumbBytes = await _renderPdfThumb(file);
      if (thumbBytes != null) {
        await supa.storage
            .from('Articles')
            .uploadBinary(
              thumbStoragePath,
              thumbBytes,
              fileOptions: const FileOptions(
                contentType: 'image/png',
                upsert: false,
              ),
            );
        thumbUrl = supa.storage.from('Articles').getPublicUrl(thumbStoragePath);
      }

      // 🟠 Insertion en base
      await supa.from('articles').insert({
        'title': title,
        'description': desc.isEmpty ? null : desc,
        'cse': cse,
        'pdf_url': pdfUrl,
        'thumb_url': thumbUrl,
        'storage_path': pdfStoragePath,
        'published_at': DateFormat('yyyy-MM-dd').format(_date),
        'author': supa.auth.currentUser?.id,
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Article publié avec succès'),
          backgroundColor: AppColors.vert,
        ),
      );

      // 🧹 Réinitialise le formulaire après publication
      setState(() {
        _titleCtl.clear();
        _descCtl.clear();
        _pickedPdf = null;
        _saving = false;
      });
      _recomputeCanPublish();
    } catch (e) {
      debugPrint('❌ Erreur enregistrement: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: AppColors.rouge,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
        _recomputeCanPublish();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd/MM/yyyy');

    return Scaffold(
      appBar: AppBar(
        title: const Text('📰 Nouvelle actualité'),
        backgroundColor: AppColors.marine,
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  // 🔹 Bloc infos auteur + date
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.marine.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Informations de publication',
                          style: TextStyle(
                            color: AppColors.marine,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Auteur : ${supa.auth.currentUser?.email ?? "Inconnu"}',
                        ),
                        Text('Date : ${fmt.format(_date)}'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _titleCtl,
                    decoration: const InputDecoration(
                      labelText: 'Titre *',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Titre requis' : null,
                  ),
                  const SizedBox(height: 12),

                  TextFormField(
                    controller: _descCtl,
                    minLines: 2,
                    maxLines: 5,
                    decoration: const InputDecoration(
                      labelText: 'Description (optionnelle)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),

                  _loadingCse
                      ? const Center(child: CircularProgressIndicator())
                      : DropdownButtonFormField<String>(
                          value: _cseCtl.text.isNotEmpty
                              ? _cseCtl.text
                              : _cseOptions.first,
                          items: _cseOptions
                              .map(
                                (c) =>
                                    DropdownMenuItem(value: c, child: Text(c)),
                              )
                              .toList(),
                          onChanged: (v) {
                            setState(() => _cseCtl.text = v ?? '');
                            _recomputeCanPublish();
                          },
                          decoration: const InputDecoration(
                            labelText: 'CSE *',
                            border: OutlineInputBorder(),
                          ),
                        ),
                  const SizedBox(height: 12),

                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(
                      Icons.picture_as_pdf,
                      color: AppColors.rose,
                    ),
                    title: Text(
                      _pickedPdf?.name ?? 'Aucun fichier sélectionné',
                    ),
                    subtitle: Text(
                      _pickedPdf == null
                          ? 'Sélectionne un fichier .pdf'
                          : '${(_pickedPdf!.size / (1024 * 1024)).toStringAsFixed(2)} Mo',
                    ),
                    trailing: OutlinedButton.icon(
                      onPressed: _pickPdf,
                      icon: const Icon(Icons.attach_file),
                      label: const Text('Joindre PDF'),
                    ),
                  ),
                  const SizedBox(height: 20),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: (_canPublish && !_saving) ? _save : null,
                      icon: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.cloud_upload),
                      label: Text(
                        _saving ? 'Publication…' : 'Publier l’article',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.vert,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(48),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
