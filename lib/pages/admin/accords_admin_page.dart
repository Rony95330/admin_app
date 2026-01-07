// lib/pages/admin/accords_admin_page.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
//import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;

// ✅ Adapte ces imports à ton admin_app si besoin
import 'package:admin_app/theme/brand_colors.dart';
import 'package:admin_app/pages/pdf_viewer_page.dart';

class AccordsAdminPage extends StatefulWidget {
  const AccordsAdminPage({super.key});

  @override
  State<AccordsAdminPage> createState() => _AccordsAdminPageState();
}

class _AccordsAdminPageState extends State<AccordsAdminPage> {
  static const String bucket = 'Accords_AF';
  static const String _keepFileName = '.keep';

  final supa = Supabase.instance.client;

  String _path = '';
  late Future<_Listing> _future;

  bool _loading = false;
  String? _error;

  // Overlay “busy”
  bool _busy = false;
  String _busyLabel = '';
  double? _busyProgress; // 0..1

  static const List<Color> palette = <Color>[
    AppColors.marine,
    AppColors.vert,
    AppColors.rose,
    AppColors.cyan,
    AppColors.jaune,
    AppColors.violet,
  ];

  @override
  void initState() {
    super.initState();
    _future = _listPath('');
  }

  // ---------------------------
  // Helpers path
  // ---------------------------
  String _stripAccents(String s) {
    return s
        .replaceAll(RegExp(r'[àáâäãå]'), 'a')
        .replaceAll(RegExp(r'[ÀÁÂÄÃÅ]'), 'A')
        .replaceAll(RegExp(r'[ç]'), 'c')
        .replaceAll(RegExp(r'[Ç]'), 'C')
        .replaceAll(RegExp(r'[èéêë]'), 'e')
        .replaceAll(RegExp(r'[ÈÉÊË]'), 'E')
        .replaceAll(RegExp(r'[ìíîï]'), 'i')
        .replaceAll(RegExp(r'[ÌÍÎÏ]'), 'I')
        .replaceAll(RegExp(r'[òóôöõ]'), 'o')
        .replaceAll(RegExp(r'[ÒÓÔÖÕ]'), 'O')
        .replaceAll(RegExp(r'[ùúûü]'), 'u')
        .replaceAll(RegExp(r'[ÙÚÛÜ]'), 'U')
        .replaceAll(RegExp(r'[ÿ]'), 'y')
        .replaceAll(RegExp(r'[Ÿ]'), 'Y')
        .replaceAll('œ', 'oe')
        .replaceAll('Œ', 'OE')
        .replaceAll('æ', 'ae')
        .replaceAll('Æ', 'AE');
  }

  String _safeStorageSegment(String input) {
    final s = _stripAccents(input).trim();
    final normalized = s
        .replaceAll(RegExp(r'\s+'), '_')
        .replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    return normalized.isEmpty ? 'document' : normalized;
  }

  String _safePdfFileName(String originalName) {
    final ext = p.extension(originalName).toLowerCase();
    final base = p.basenameWithoutExtension(originalName);
    final safeBase = _safeStorageSegment(base);
    final safeExt = (ext == '.pdf') ? ext : '.pdf';
    return '$safeBase$safeExt';
  }

  String _join(String base, String name) => base.isEmpty ? name : '$base/$name';

  String _parent(String path) {
    final i = path.lastIndexOf('/');
    return i < 0 ? '' : path.substring(0, i);
  }

  List<String> _crumbs(String path) =>
      path.isEmpty ? [] : path.split('/').where((e) => e.isNotEmpty).toList();

  String _pretty(String s) => s
      .replaceAll(RegExp(r'\.pdf$', caseSensitive: false), '')
      .replaceAll(RegExp(r'_+'), ' ')
      .trim();

  bool _isHiddenSystemFile(String name) {
    final lower = name.toLowerCase();
    return lower == _keepFileName ||
        lower == '.ds_store' ||
        lower == 'thumbs.db' ||
        lower.startsWith('._');
  }

  Color _colorAt(int index) => palette[index % palette.length];

  double _gridAspectRatio(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    if (w < 360) return 0.78;
    if (w < 390) return 0.82;
    if (w < 420) return 0.86;
    return 0.92;
  }

  void _setBusy(bool v, {String label = '', double? progress}) {
    setState(() {
      _busy = v;
      _busyLabel = label;
      _busyProgress = progress;
    });
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ---------------------------
  // Listing
  // ---------------------------

  Future<_Listing> _listPath(String path) async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final list = await supa.storage
          .from(bucket)
          .list(
            path: path,
            searchOptions: const SearchOptions(
              limit: 5000,
              sortBy: SortBy(column: 'name', order: 'asc'),
            ),
          );

      final folders = <_Node>[];
      final pdfs = <_Node>[];

      for (final it in list) {
        final name = it.name;
        if (_isHiddenSystemFile(name)) continue;

        final full = path.isEmpty ? name : '$path/$name';
        final mime = (it.metadata?['mimetype'] as String?);

        final isDir = (mime == null || mime.isEmpty) && !name.contains('.');
        if (isDir) {
          folders.add(_Node.folder(name: name, fullPath: full));
          continue;
        }

        if (name.toLowerCase().endsWith('.pdf')) {
          DateTime? updated;
          final raw = it.updatedAt;
          if (raw is String) {
            updated = DateTime.tryParse(raw);
          } else if (raw is DateTime) {
            updated = raw;
          }

          pdfs.add(
            _Node.file(
              name: name,
              fullPath: full,
              size: (it.metadata?['size'] is num)
                  ? (it.metadata!['size'] as num).toInt()
                  : null,
              mimeType: mime ?? 'application/pdf',
              updatedAt: updated,
            ),
          );
        }
      }

      folders.sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );
      pdfs.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

      setState(() => _loading = false);
      return _Listing(path: path, folders: folders, pdfs: pdfs);
    } catch (e) {
      setState(() {
        _loading = false;
        _error = e.toString();
      });
      rethrow;
    }
  }

  Future<void> _refresh() async {
    _future = _listPath(_path);
    setState(() {});
    await _future;
  }

  Future<void> _openFolder(_Node f) async {
    _path = f.fullPath;
    _future = _listPath(_path);
    setState(() {});
  }

  Future<String?> _getPdfUrl(_Node f) async {
    try {
      return await supa.storage
          .from(bucket)
          .createSignedUrl(f.fullPath, 60 * 10);
    } catch (_) {
      return supa.storage.from(bucket).getPublicUrl(f.fullPath);
    }
  }

  Future<void> _openPdf(_Node f) async {
    final url = await _getPdfUrl(f);
    if (!mounted) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PdfViewerPage(
          url: url ?? '',
          title: _pretty(f.name),
          canDownload: true,
        ),
      ),
    );
  }

  // ---------------------------
  // Admin actions
  // ---------------------------

  Future<void> _createFolder() async {
    final name = await _askText(
      title: 'Nouveau dossier',
      hint: 'Nom du dossier',
      initial: '',
    );
    if (name == null) return;

    final trimmed = name.trim();

    if (trimmed.isEmpty) return;

    final folderPath = _join(_path, trimmed);
    final keepPath = '$folderPath/$_keepFileName';

    try {
      _setBusy(true, label: 'Création du dossier…');
      final bytes = Uint8List.fromList(utf8.encode('keep'));
      await supa.storage
          .from(bucket)
          .uploadBinary(
            keepPath,
            bytes,
            fileOptions: const FileOptions(
              upsert: true,
              contentType: 'text/plain',
              cacheControl: '0',
            ),
          );
      _snack('Dossier créé : $trimmed');
      await _refresh();
    } catch (e) {
      _snack('Erreur création dossier : $e');
    } finally {
      _setBusy(false);
    }
  }

  Future<void> _uploadPdfs() async {
    final res = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
      withData: true, // ✅
    );
    if (res == null || res.files.isEmpty) return;

    final files = res.files
        .where((f) => f.name.toLowerCase().endsWith('.pdf'))
        .toList();

    if (files.isEmpty) {
      _snack('Aucun PDF sélectionné.');
      return;
    }

    try {
      _setBusy(true, label: 'Upload des PDF…', progress: 0);

      for (var i = 0; i < files.length; i++) {
        final pf = files[i];

        final bytes =
            pf.bytes ??
            (pf.path != null ? await File(pf.path!).readAsBytes() : null);

        if (bytes == null) {
          throw Exception('Lecture impossible: ${pf.name} (bytes/path null)');
        }

        final safeName = _safePdfFileName(pf.name);
        final remotePath = _join(_path, safeName);

        await supa.storage
            .from(bucket)
            .uploadBinary(
              remotePath,
              bytes,
              fileOptions: const FileOptions(
                upsert: true,
                contentType: 'application/pdf',
                cacheControl: '0',
              ),
            );

        _setBusy(
          true,
          label: 'Upload des PDF…',
          progress: (i + 1) / files.length,
        );
      }

      _snack('Upload terminé (${files.length} fichier(s)).');
      await _refresh();
    } catch (e) {
      _snack('Erreur upload : $e');
    } finally {
      _setBusy(false);
    }
  }

  Future<void> _uploadDirectoryRecursively() async {
    if (kIsWeb) {
      _snack('Upload dossier non disponible sur web.');
      return;
    }
    final dirPath = await FilePicker.platform.getDirectoryPath();
    if (dirPath == null) return;

    final root = Directory(dirPath);
    if (!await root.exists()) {
      _snack('Dossier introuvable.');
      return;
    }

    final pdfFiles = <File>[];
    await for (final ent in root.list(recursive: true, followLinks: false)) {
      if (ent is File && ent.path.toLowerCase().endsWith('.pdf')) {
        pdfFiles.add(ent);
      }
    }

    if (pdfFiles.isEmpty) {
      _snack('Aucun PDF trouvé dans ce dossier.');
      return;
    }

    try {
      _setBusy(true, label: 'Upload du dossier…', progress: 0);

      for (var i = 0; i < pdfFiles.length; i++) {
        final f = pdfFiles[i];
        final rel = p.relative(f.path, from: dirPath);
        final relUnix = rel.split(p.separator).join('/');

        final remotePath = _join(_path, relUnix);

        await _uploadFile(
          file: f,
          remotePath: remotePath,
          contentType: 'application/pdf',
          upsert: true,
        );

        _setBusy(
          true,
          label: 'Upload du dossier…',
          progress: (i + 1) / pdfFiles.length,
        );
      }

      _snack('Upload dossier terminé (${pdfFiles.length} PDF).');
      await _refresh();
    } catch (e) {
      _snack('Erreur upload dossier : $e');
    } finally {
      _setBusy(false);
    }
  }

  Future<void> _uploadFile({
    required File file,
    required String remotePath,
    required String contentType,
    required bool upsert,
  }) async {
    final bytes = await file.readAsBytes();
    await supa.storage
        .from(bucket)
        .uploadBinary(
          remotePath,
          bytes,
          fileOptions: FileOptions(
            upsert: upsert,
            contentType: contentType,
            cacheControl:
                '0', // pratique pour limiter les soucis de cache après remplacement
          ),
        );
  }

  Future<void> _replacePdf(_Node pdf) async {
    final res = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
      withData: true, // ✅ important: bytes dispo (macOS/web)
    );
    if (res == null || res.files.isEmpty) return;

    final pf = res.files.first;

    try {
      _setBusy(true, label: 'Remplacement…');

      final bytes =
          pf.bytes ??
          (pf.path != null ? await File(pf.path!).readAsBytes() : null);

      if (bytes == null) {
        _snack('Impossible de lire le fichier sélectionné (bytes/path null).');
        return;
      }

      await supa.storage
          .from(bucket)
          .uploadBinary(
            pdf.fullPath,
            bytes,
            fileOptions: const FileOptions(
              upsert: true,
              contentType: 'application/pdf',
              cacheControl: '0',
            ),
          );

      _snack('PDF remplacé : ${pdf.name}');
      await _refresh();
    } catch (e) {
      _snack('Erreur remplacement : $e');
    } finally {
      _setBusy(false);
    }
  }

  Future<void> _renameNode(_Node node) async {
    final newName = await _askText(
      title: node.isFolder ? 'Renommer le dossier' : 'Renommer le PDF',
      hint: 'Nouveau nom',
      initial: node.name,
    );
    if (newName == null) return;

    final trimmed = newName.trim();
    if (trimmed.isEmpty || trimmed == node.name) return;

    final fromPath = node.fullPath;
    final toPath = _join(_parent(fromPath), trimmed);

    // pour un PDF : conserve .pdf si oublié
    final finalToPath =
        (!node.isFolder &&
            !toPath.toLowerCase().endsWith('.pdf') &&
            fromPath.toLowerCase().endsWith('.pdf'))
        ? '$toPath.pdf'
        : toPath;

    try {
      _setBusy(true, label: 'Renommage…');
      if (node.isFolder) {
        await _moveFolderPrefix(oldPrefix: fromPath, newPrefix: finalToPath);
      } else {
        await _copyThenDelete(
          from: fromPath,
          to: finalToPath,
          contentType: node.mimeType ?? 'application/pdf',
        );
      }
      _snack('Renommé.');
      await _refresh();
    } catch (e) {
      _snack('Erreur renommage : $e');
    } finally {
      _setBusy(false);
    }
  }

  Future<void> _moveNode(_Node node) async {
    final destFolder = await _pickDestinationFolder();
    if (destFolder == null) return;

    final fromPath = node.fullPath;
    final fileName = node.name;

    final toPath = destFolder.isEmpty ? fileName : '$destFolder/$fileName';

    try {
      _setBusy(true, label: 'Déplacement…');
      if (node.isFolder) {
        await _moveFolderPrefix(oldPrefix: fromPath, newPrefix: toPath);
      } else {
        await _copyThenDelete(
          from: fromPath,
          to: toPath,
          contentType: node.mimeType ?? 'application/pdf',
        );
      }
      _snack('Déplacé.');
      await _refresh();
    } catch (e) {
      _snack('Erreur déplacement : $e');
    } finally {
      _setBusy(false);
    }
  }

  Future<void> _deleteNode(_Node node) async {
    final ok = await _confirm(
      title: 'Confirmer',
      message: node.isFolder
          ? 'Supprimer le dossier "${node.name}" et tout son contenu ?'
          : 'Supprimer "${node.name}" ?',
      confirmLabel: 'Supprimer',
    );
    if (!ok) return;

    try {
      _setBusy(true, label: 'Suppression…');
      if (node.isFolder) {
        final all = await _collectPathsRecursive(
          prefix: node.fullPath,
          includeHidden: true,
        );
        if (all.isNotEmpty) {
          await supa.storage.from(bucket).remove(all);
        }
      } else {
        await supa.storage.from(bucket).remove([node.fullPath]);
      }
      _snack('Supprimé.');
      await _refresh();
    } catch (e) {
      _snack('Erreur suppression : $e');
    } finally {
      _setBusy(false);
    }
  }

  Future<void> _copyThenDelete({
    required String from,
    required String to,
    required String contentType,
  }) async {
    final bytes = await supa.storage.from(bucket).download(from);
    await supa.storage
        .from(bucket)
        .uploadBinary(
          to,
          bytes,
          fileOptions: FileOptions(
            upsert: true,
            contentType: contentType,
            cacheControl: '0',
          ),
        );
    await supa.storage.from(bucket).remove([from]);
  }

  Future<void> _moveFolderPrefix({
    required String oldPrefix,
    required String newPrefix,
  }) async {
    // Déplace tous les objets sous oldPrefix vers newPrefix (même structure relative)
    final paths = await _collectPathsRecursive(
      prefix: oldPrefix,
      includeHidden: true,
    );
    if (paths.isEmpty) return;

    for (var i = 0; i < paths.length; i++) {
      final from = paths[i];
      final rel = from
          .substring(oldPrefix.length)
          .replaceFirst(RegExp(r'^/'), '');
      final to = rel.isEmpty ? newPrefix : '$newPrefix/$rel';

      // Déduire contentType
      final ct = from.toLowerCase().endsWith('.pdf')
          ? 'application/pdf'
          : 'text/plain';

      _setBusy(
        true,
        label: 'Déplacement dossier…',
        progress: (i + 1) / paths.length,
      );
      await _copyThenDelete(from: from, to: to, contentType: ct);
    }

    // Assure l’existence du dossier destination si vide
    final keepPath = '$newPrefix/$_keepFileName';
    await supa.storage
        .from(bucket)
        .uploadBinary(
          keepPath,
          Uint8List.fromList(utf8.encode('keep')),
          fileOptions: const FileOptions(
            upsert: true,
            contentType: 'text/plain',
            cacheControl: '0',
          ),
        );
  }

  Future<List<String>> _collectPathsRecursive({
    required String prefix,
    required bool includeHidden,
  }) async {
    final out = <String>[];

    Future<void> walk(String path) async {
      final list = await supa.storage
          .from(bucket)
          .list(
            path: path,
            searchOptions: const SearchOptions(
              limit: 5000,
              sortBy: SortBy(column: 'name', order: 'asc'),
            ),
          );

      for (final it in list) {
        final name = it.name;
        if (!includeHidden && _isHiddenSystemFile(name)) continue;

        final mime = (it.metadata?['mimetype'] as String?);
        final isDir = (mime == null || mime.isEmpty) && !name.contains('.');
        final full = path.isEmpty ? name : '$path/$name';

        if (isDir) {
          await walk(full);
        } else {
          out.add(full);
        }
      }
    }

    await walk(prefix);
    return out;
  }

  // ---------------------------
  // Destination picker (simple)
  // ---------------------------

  Future<String?> _pickDestinationFolder() async {
    // Picker minimaliste : navigation comme l’explorateur, mais “Sélectionner ici”
    var current = '';
    while (true) {
      final listing = await _listPath(current);
      if (!mounted) return null;
      final picked = await showModalBottomSheet<_DestChoice>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
        ),
        builder: (_) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Choisir un dossier de destination',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(
                          context,
                          _DestChoice.selectHere(current),
                        ),
                        child: Text(
                          'Sélectionner ici',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      IconButton(
                        tooltip: 'Racine',
                        onPressed: () =>
                            Navigator.pop(context, _DestChoice.goRoot()),
                        icon: const Icon(Icons.home_outlined),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          current.isEmpty ? 'Racine' : current,
                          style: GoogleFonts.poppins(color: Colors.black54),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (current.isNotEmpty)
                        IconButton(
                          tooltip: 'Remonter',
                          onPressed: () => Navigator.pop(
                            context,
                            _DestChoice.goUp(_parent(current)),
                          ),
                          icon: const Icon(Icons.arrow_upward),
                        ),
                    ],
                  ),
                  const Divider(height: 16),
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height * 0.55,
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: listing.folders.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),

                      itemBuilder: (_, i) {
                        final f = listing.folders[i];
                        return ListTile(
                          leading: const Icon(Icons.folder_outlined),
                          title: Text(
                            _pretty(f.name),
                            style: GoogleFonts.poppins(),
                          ),
                          onTap: () => Navigator.pop(
                            context,
                            _DestChoice.openFolder(f.fullPath),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );

      if (picked == null) return null;
      if (picked.type == _DestChoiceType.selectHere) return picked.path;
      if (picked.type == _DestChoiceType.root) {
        current = '';
        continue;
      }
      if (picked.type == _DestChoiceType.up) {
        current = picked.path;
        continue;
      }
      if (picked.type == _DestChoiceType.open) {
        current = picked.path;
        continue;
      }
    }
  }

  // ---------------------------
  // Dialogs
  // ---------------------------

  Future<String?> _askText({
    required String title,
    required String hint,
    required String initial,
  }) async {
    final ctrl = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(
          title,
          style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
        ),
        content: TextField(
          controller: ctrl,
          decoration: InputDecoration(hintText: hint),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Annuler', style: GoogleFonts.poppins()),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, ctrl.text),
            child: Text(
              'Valider',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Future<bool> _confirm({
    required String title,
    required String message,
    required String confirmLabel,
  }) async {
    final res = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(
          title,
          style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
        ),
        content: Text(message, style: GoogleFonts.poppins()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Annuler', style: GoogleFonts.poppins()),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.rouge),
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              confirmLabel,
              style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
    return res ?? false;
  }

  // ---------------------------
  // UI
  // ---------------------------

  @override
  Widget build(BuildContext context) {
    final crumbs = _crumbs(_path);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.marine,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'Accords (Admin)',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
        ),
        actions: [
          if (_path.isNotEmpty)
            IconButton(
              tooltip: 'Remonter',
              icon: const Icon(Icons.arrow_upward),
              onPressed: () {
                _path = _parent(_path);
                _future = _listPath(_path);
                setState(() {});
              },
            ),
          IconButton(
            tooltip: 'Rafraîchir',
            icon: const Icon(Icons.refresh),
            onPressed: _refresh,
          ),
          PopupMenuButton<_TopAction>(
            tooltip: 'Actions',
            onSelected: (a) async {
              switch (a) {
                case _TopAction.createFolder:
                  await _createFolder();
                  break;
                case _TopAction.uploadPdfs:
                  await _uploadPdfs();
                  break;
                case _TopAction.uploadDirectory:
                  await _uploadDirectoryRecursively();
                  break;
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: _TopAction.createFolder,
                child: Text('Nouveau dossier', style: GoogleFonts.poppins()),
              ),
              PopupMenuItem(
                value: _TopAction.uploadPdfs,
                child: Text('Importer PDF(s)', style: GoogleFonts.poppins()),
              ),
              PopupMenuItem(
                value: _TopAction.uploadDirectory,
                child: Text(
                  'Importer un dossier de PDF',
                  style: GoogleFonts.poppins(),
                ),
              ),
            ],
          ),
        ],
      ),
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.marine,
                  Color(0xFFF3F8FF),
                  Color(0xFFE5F6FB),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: Column(
              children: [
                if (crumbs.isNotEmpty)
                  _BreadcrumbBar(
                    crumbs: crumbs.map(_pretty).toList(),
                    onTapRoot: () {
                      _path = '';
                      _future = _listPath(_path);
                      setState(() {});
                    },
                    onTapCrumb: (idx) {
                      var pth = '';
                      for (var i = 0; i <= idx; i++) {
                        pth = pth.isEmpty ? crumbs[i] : '$pth/${crumbs[i]}';
                      }
                      _path = pth;
                      _future = _listPath(_path);
                      setState(() {});
                    },
                  ),
                Expanded(
                  child: FutureBuilder<_Listing>(
                    future: _future,
                    builder: (context, snap) {
                      if (_loading && !snap.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (_error != null) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(_error!, textAlign: TextAlign.center),
                          ),
                        );
                      }
                      final data = snap.data;
                      if (data == null) return const SizedBox.shrink();

                      final entries = <_TileEntry>[];
                      for (final f in data.folders) {
                        entries.add(
                          _TileEntry(
                            node: f,
                            title: _pretty(f.name),
                            icon: Icons.folder_outlined,
                            onTap: () => _openFolder(f),
                          ),
                        );
                      }
                      for (final pdf in data.pdfs) {
                        entries.add(
                          _TileEntry(
                            node: pdf,
                            title: _pretty(pdf.name),
                            icon: Icons.picture_as_pdf_outlined,
                            onTap: () => _openPdf(pdf),
                          ),
                        );
                      }

                      if (entries.isEmpty) {
                        return Center(
                          child: Text(
                            'Aucun contenu ici…',
                            style: GoogleFonts.poppins(color: Colors.black54),
                          ),
                        );
                      }

                      return RefreshIndicator(
                        onRefresh: _refresh,
                        child: GridView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: entries.length,
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                crossAxisSpacing: 16,
                                mainAxisSpacing: 16,
                                childAspectRatio: _gridAspectRatio(context),
                              ),
                          itemBuilder: (_, i) {
                            final e = entries[i];
                            final color = _colorAt(i);
                            return _AdminAccordCard(
                              title: e.title,
                              icon: e.icon,
                              color: color,
                              updatedAt: e.node.updatedAt,
                              onTap: e.onTap,
                              onAction: (act) async {
                                switch (act) {
                                  case _NodeAction.rename:
                                    await _renameNode(e.node);
                                    break;
                                  case _NodeAction.move:
                                    await _moveNode(e.node);
                                    break;
                                  case _NodeAction.delete:
                                    await _deleteNode(e.node);
                                    break;
                                  case _NodeAction.replace:
                                    await _replacePdf(e.node);
                                    break;
                                }
                              },
                              isFolder: e.node.isFolder,
                            );
                          },
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          // Overlay busy
          if (_busy)
            Positioned.fill(
              child: AbsorbPointer(
                absorbing: true,
                child: Container(
                  color: Colors.black.withOpacity(0.25),
                  child: Center(
                    child: Container(
                      width: 320,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: const [
                          BoxShadow(blurRadius: 12, offset: Offset(0, 6)),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _busyLabel.isEmpty ? 'Traitement…' : _busyLabel,
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w700,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          if (_busyProgress != null)
                            LinearProgressIndicator(value: _busyProgress)
                          else
                            const CircularProgressIndicator(),
                          const SizedBox(height: 8),
                          if (_busyProgress != null)
                            Text(
                              '${((_busyProgress ?? 0) * 100).toStringAsFixed(0)}%',
                              style: GoogleFonts.poppins(color: Colors.black54),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------
// Models & UI components
// ---------------------------

enum _TopAction { createFolder, uploadPdfs, uploadDirectory }

enum _NodeAction { rename, move, delete, replace }

class _TileEntry {
  final _Node node;
  final String title;
  final IconData icon;
  final VoidCallback onTap;

  _TileEntry({
    required this.node,
    required this.title,
    required this.icon,
    required this.onTap,
  });
}

class _AdminAccordCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final DateTime? updatedAt;
  final VoidCallback onTap;
  final bool isFolder;
  final void Function(_NodeAction) onAction;

  const _AdminAccordCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.updatedAt,
    required this.onTap,
    required this.isFolder,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final subtitle = (!isFolder && updatedAt != null)
        ? 'Maj: ${updatedAt!.toLocal().toString().split('.').first}'
        : null;

    return Tooltip(
      message: title,
      triggerMode: TooltipTriggerMode.longPress,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.88),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withOpacity(0.6), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.25),
                blurRadius: 8,
                offset: const Offset(2, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Row(
                children: [
                  Icon(icon, size: 30, color: color),
                  const Spacer(),
                  PopupMenuButton<_NodeAction>(
                    tooltip: 'Actions',
                    onSelected: onAction,
                    itemBuilder: (_) {
                      final items = <PopupMenuEntry<_NodeAction>>[
                        PopupMenuItem(
                          value: _NodeAction.rename,
                          child: Text('Renommer', style: GoogleFonts.poppins()),
                        ),
                        PopupMenuItem(
                          value: _NodeAction.move,
                          child: Text(
                            'Déplacer…',
                            style: GoogleFonts.poppins(),
                          ),
                        ),
                        PopupMenuItem(
                          value: _NodeAction.delete,
                          child: Text(
                            'Supprimer',
                            style: GoogleFonts.poppins(),
                          ),
                        ),
                      ];
                      if (!isFolder) {
                        items.insert(
                          0,
                          PopupMenuItem(
                            value: _NodeAction.replace,
                            child: Text(
                              'Remplacer (upload)',
                              style: GoogleFonts.poppins(),
                            ),
                          ),
                        );
                      }
                      return items;
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Center(
                  child: Text(
                    title,
                    textAlign: TextAlign.center,
                    maxLines: 5,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                      height: 1.15,
                    ),
                  ),
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: Colors.black54,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Listing {
  final String path;
  final List<_Node> folders;
  final List<_Node> pdfs;
  _Listing({required this.path, required this.folders, required this.pdfs});
}

class _Node {
  final String name;
  final String fullPath;
  final bool isFolder;
  final int? size;
  final String? mimeType;
  final DateTime? updatedAt;

  _Node.folder({required this.name, required this.fullPath})
    : isFolder = true,
      size = null,
      mimeType = null,
      updatedAt = null;

  _Node.file({
    required this.name,
    required this.fullPath,
    this.size,
    this.mimeType,
    this.updatedAt,
  }) : isFolder = false;
}

class _BreadcrumbBar extends StatelessWidget {
  final List<String> crumbs;
  final VoidCallback onTapRoot;
  final void Function(int) onTapCrumb;

  const _BreadcrumbBar({
    required this.crumbs,
    required this.onTapRoot,
    required this.onTapCrumb,
  });

  @override
  Widget build(BuildContext context) {
    final items = <Widget>[
      ActionChip(
        label: Text(
          'Racine',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        onPressed: onTapRoot,
        backgroundColor: Colors.white.withOpacity(.9),
      ),
    ];
    for (var i = 0; i < crumbs.length; i++) {
      items.add(
        const Icon(Icons.chevron_right, size: 18, color: Colors.white70),
      );
      final isLast = i == crumbs.length - 1;
      items.add(
        ActionChip(
          label: Text(
            crumbs[i],
            style: GoogleFonts.poppins(
              fontWeight: isLast ? FontWeight.w700 : FontWeight.w500,
              color: isLast ? AppColors.marine : Colors.black87,
            ),
          ),
          onPressed: isLast ? null : () => onTapCrumb(i),
          backgroundColor: Colors.white.withOpacity(.9),
        ),
      );
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: items,
      ),
    );
  }
}

// ---------------------------
// Destination picker choices
// ---------------------------

enum _DestChoiceType { selectHere, open, up, root }

class _DestChoice {
  final _DestChoiceType type;
  final String path;
  const _DestChoice._(this.type, this.path);

  factory _DestChoice.selectHere(String path) =>
      _DestChoice._(_DestChoiceType.selectHere, path);
  factory _DestChoice.openFolder(String path) =>
      _DestChoice._(_DestChoiceType.open, path);
  factory _DestChoice.goUp(String path) =>
      _DestChoice._(_DestChoiceType.up, path);
  factory _DestChoice.goRoot() => _DestChoice._(_DestChoiceType.root, '');
}
