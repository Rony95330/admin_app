import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:pdfx/pdfx.dart';

class PdfViewerPage extends StatefulWidget {
  final String url;
  final String title;
  final bool canDownload;

  const PdfViewerPage({
    super.key,
    required this.url,
    required this.title,
    this.canDownload = false,
  });

  @override
  State<PdfViewerPage> createState() => _PdfViewerPageState();
}

class _PdfViewerPageState extends State<PdfViewerPage> {
  PdfControllerPinch? _controller;
  Uint8List? _bytes;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      Uint8List bytes;

      // 🔹 Cas 1 : URL distante (Supabase / HTTPS)
      if (widget.url.startsWith('http')) {
        final resp = await http.get(Uri.parse(widget.url));
        if (resp.statusCode != 200) {
          throw Exception('HTTP ${resp.statusCode}');
        }
        bytes = resp.bodyBytes;
      }

      // 🔹 Cas 2 : Fichier local (file:// ou path direct)
      else if (widget.url.startsWith('file://') ||
          File(widget.url).existsSync()) {
        final file = widget.url.startsWith('file://')
            ? File(Uri.parse(widget.url).path)
            : File(widget.url);
        bytes = await file.readAsBytes();
      } else {
        throw Exception('Chemin PDF invalide : ${widget.url}');
      }

      _bytes = bytes;
      _controller = PdfControllerPinch(
        document: PdfDocument.openData(bytes),
      );

      if (mounted) setState(() => _loading = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title, overflow: TextOverflow.ellipsis),
        centerTitle: true,
        actions: [
          if (widget.canDownload && _bytes != null)
            IconButton(
              tooltip: 'Télécharger',
              onPressed: _downloadLocally,
              icon: const Icon(Icons.download),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _ErrorView(message: _error!, onRetry: _load)
              : _controller == null
                  ? const Center(child: Text('Impossible d’ouvrir le PDF'))
                  : Container(
                      color: cs.surface,
                      child: PdfViewPinch(
                        controller: _controller!,
                        onDocumentError: (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Erreur PDF: $e')),
                          );
                        },
                      ),
                    ),
    );
  }

  Future<void> _downloadLocally() async {
    if (_bytes == null) return;
    try {
      // Sauvegarde “silencieuse” dans le cache de l’application
      final tempDir = Directory.systemTemp;
      final filePath = '${tempDir.path}/${widget.title}.pdf';
      final file = File(filePath);
      await file.writeAsBytes(_bytes!);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Téléchargement terminé ✅')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur téléchargement: $e')),
      );
    }
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: cs.error),
            const SizedBox(height: 10),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Réessayer'),
            ),
          ],
        ),
      ),
    );
  }
}
