import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:pdfx/pdfx.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/brand_colors.dart'; // ✅ version admin_app

class RevuePresseUpdatePage extends StatefulWidget {
  const RevuePresseUpdatePage({super.key});

  @override
  State<RevuePresseUpdatePage> createState() => _RevuePresseUpdatePageState();
}

class _RevuePresseUpdatePageState extends State<RevuePresseUpdatePage> {
  final supa = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();

  final _titleCtl = TextEditingController();
  DateTime _date = DateTime.now();
  PlatformFile? _pickedPdf;
  bool _saving = false;
  bool _canPublish = false;

  void _recomputeCanPublish() {
    setState(() {
      _canPublish =
          _titleCtl.text.trim().isNotEmpty && _pickedPdf != null && !_saving;
    });
  }

  @override
  void initState() {
    super.initState();
    _titleCtl.addListener(_recomputeCanPublish);
  }

  @override
  void dispose() {
    _titleCtl.removeListener(_recomputeCanPublish);
    _titleCtl.dispose();
    super.dispose();
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

  Future<Uint8List?> _renderPdfThumb(File file) async {
    try {
      final doc = await PdfDocument.openFile(file.path);
      final page = await doc.getPage(1);

      const double targetWidth = 600.0;
      final double scale = targetWidth / page.width;
      final double targetHeight = page.height * scale;

      final img = await page.render(
        width: targetWidth,
        height: targetHeight,
        format: PdfPageImageFormat.png,
      );

      await page.close();
      await doc.close();
      return img?.bytes;
    } catch (_) {
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

    final formOk = _formKey.currentState?.validate() ?? false;
    final pdfOk = _pickedPdf != null;
    if (!formOk || !pdfOk) {
      _recomputeCanPublish();
      if (!pdfOk) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sélectionne un fichier PDF.')),
        );
      }
      return;
    }

    setState(() => _saving = true);
    _recomputeCanPublish();

    try {
      final title = _titleCtl.text.trim();

      final file = File(_pickedPdf!.path!);
      final fileName = _sanitizeFileName(
        _pickedPdf!.name.isNotEmpty
            ? p.basenameWithoutExtension(_pickedPdf!.name)
            : title,
      );

      final stamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());

      final pdfStoragePath = 'revue_presse/${fileName}_$stamp.pdf';
      final thumbStoragePath = 'revue_presse/thumbnails/${fileName}_$stamp.png';

      // 🟢 Upload du PDF
      final pdfBytes = await file.readAsBytes();
      await supa.storage
          .from('revue_presse')
          .uploadBinary(
            pdfStoragePath,
            pdfBytes,
            fileOptions: const FileOptions(
              contentType: 'application/pdf',
              cacheControl: '3600',
              upsert: false,
            ),
          );
      final pdfUrl = supa.storage
          .from('revue_presse')
          .getPublicUrl(pdfStoragePath);

      // 🟢 Génération de la miniature
      String? imageUrl;
      final thumbBytes = await _renderPdfThumb(file);
      if (thumbBytes != null) {
        await supa.storage
            .from('revue_presse')
            .uploadBinary(
              thumbStoragePath,
              thumbBytes,
              fileOptions: const FileOptions(
                contentType: 'image/png',
                cacheControl: '3600',
                upsert: false,
              ),
            );
        imageUrl = supa.storage
            .from('revue_presse')
            .getPublicUrl(thumbStoragePath);
      }

      // 🟢 Insertion dans la table Supabase
      await supa.from('revue_presse').insert({
        'titre': title,
        'pdf_url': pdfUrl,
        'image_url': imageUrl,
        'date_publication': DateFormat('yyyy-MM-dd').format(_date),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Revue publiée ✅')));
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erreur: $e')));
    } finally {
      if (mounted) {
        setState(() => _saving = false);
        _recomputeCanPublish();
      }
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      locale: const Locale('fr', 'FR'),
      helpText: 'Date de publication',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.marine,
              onPrimary: Colors.white,
              onSurface: AppColors.marine,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _date = DateTime(picked.year, picked.month, picked.day));
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final fmt = DateFormat('dd/MM/yyyy');

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.marine,
        title: const Text('📰 Nouvelle revue de presse'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: AbsorbPointer(
          absorbing: _saving,
          child: Form(
            key: _formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: Column(
              children: [
                // 🔹 Titre
                TextFormField(
                  controller: _titleCtl,
                  decoration: const InputDecoration(
                    labelText: 'Titre *',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Titre requis' : null,
                ),
                const SizedBox(height: 16),

                // 🔹 Date de publication
                Row(
                  children: [
                    Expanded(
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Date de publication',
                          border: OutlineInputBorder(),
                        ),
                        child: Text(fmt.format(_date)),
                      ),
                    ),
                    const SizedBox(width: 8.0),
                    FilledButton.icon(
                      onPressed: _pickDate,
                      icon: const Icon(Icons.calendar_today),
                      label: const Text('Choisir'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // 🔹 Sélection du PDF
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(
                    Icons.picture_as_pdf,
                    color: AppColors.rose,
                  ),
                  title: Text(_pickedPdf?.name ?? 'Aucun fichier sélectionné'),
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

                // 🔹 Bouton Publier
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: (_canPublish && !_saving) ? _save : null,
                    icon: _saving
                        ? const SizedBox(
                            width: 18.0,
                            height: 18.0,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.0,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.cloud_upload),
                    label: Text(_saving ? 'Publication…' : 'Publier'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: cs.primary,
                      foregroundColor: cs.onPrimary,
                      minimumSize: const Size.fromHeight(48),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
