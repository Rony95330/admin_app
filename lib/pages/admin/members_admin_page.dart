import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../theme/brand_colors.dart';

class MembersAdminPage extends StatefulWidget {
  const MembersAdminPage({super.key});

  @override
  State<MembersAdminPage> createState() => _MembersAdminPageState();
}

class _MembersAdminPageState extends State<MembersAdminPage> {
  final supa = Supabase.instance.client;

  bool _loading = true;
  bool _saving = false;

  String? _myCse;

  // ✅ Dropdown CSE (secteur) : options + sélection courante
  List<String> _cseOptions = [];
  String? _selectedCse;

  List<Map<String, dynamic>> _rows = [];

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    setState(() => _loading = true);
    try {
      _myCse = await _resolveMyCse();
      if (_myCse == null || _myCse!.trim().isEmpty) {
        throw Exception(
          "Impossible de déterminer votre CSE admin (user_sessions admin_console ou users.cse).",
        );
      }

      _cseOptions = await _loadCseOptions(myCse: _myCse!.trim());
      _selectedCse = _myCse!.trim();

      await _fetchMembers();
    } catch (e) {
      _showError('Erreur init: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ------------------------------------------------------------
  Future<String?> _resolveMyCse() async {
    final user = supa.auth.currentUser;
    if (user == null) return null;

    // 1) user_sessions admin_console
    try {
      final row = await supa
          .from('user_sessions')
          .select('cse, client_kind, last_activity, is_active')
          .eq('user_id', user.id)
          .eq('client_kind', 'admin_console')
          .order('last_activity', ascending: false)
          .limit(1)
          .maybeSingle();

      final cse = (row?['cse'] ?? '').toString().trim();
      if (cse.isNotEmpty) return cse;
    } catch (_) {}

    // 2) fallback users.cse si existe
    try {
      final row = await supa
          .from('users')
          .select('cse')
          .eq('id', user.id)
          .maybeSingle();
      final cse = (row?['cse'] ?? '').toString().trim();
      if (cse.isNotEmpty) return cse;
    } catch (_) {}

    return null;
  }

  // ------------------------------------------------------------
  // ✅ Charge une liste de CSE pour alimenter les dropdowns.
  // Stratégie :
  // 1) tente table "cse" (code)
  // 2) sinon, distinct côté client depuis members.cse
  // 3) inclut toujours myCse
  Future<List<String>> _loadCseOptions({required String myCse}) async {
    final set = <String>{};

    // 1) Tentative table "cse" (si tu en as une)
    try {
      final data = await supa
          .from('cse')
          .select('code')
          .order('code', ascending: true);
      for (final r in List<Map<String, dynamic>>.from(data)) {
        final v = (r['code'] ?? '').toString().trim();
        if (v.isNotEmpty) set.add(v);
      }
    } catch (_) {
      // ignore
    }

    // 2) Fallback: récupère tous les cse depuis members
    if (set.isEmpty) {
      try {
        final data = await supa.from('members').select('cse');
        for (final r in List<Map<String, dynamic>>.from(data)) {
          final v = (r['cse'] ?? '').toString().trim();
          if (v.isNotEmpty) set.add(v);
        }
      } catch (_) {
        // ignore
      }
    }

    // 3) Toujours inclure myCse
    if (myCse.trim().isNotEmpty) set.add(myCse.trim());

    final list = set.toList()..sort();
    return list;
  }

  // ------------------------------------------------------------
  Future<void> _fetchMembers() async {
    final cse = (_selectedCse ?? _myCse ?? '').trim();
    if (cse.isEmpty) return;

    final data = await supa
        .from('members')
        .select(
          'id, name, role, phone, cse, sector, photo_url, email, photo_path, order_index',
        )
        .eq('cse', cse)
        .order('order_index', ascending: true)
        .order('name', ascending: true);

    if (!mounted) return;
    setState(() => _rows = List<Map<String, dynamic>>.from(data));
  }

  // ------------------------------------------------------------
  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppColors.rouge),
    );
  }

  void _showOk(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppColors.vert),
    );
  }

  // ------------------------------------------------------------
  String _slugify(String input) {
    var s = input.trim().toLowerCase();
    const map = {
      'à': 'a',
      'â': 'a',
      'ä': 'a',
      'á': 'a',
      'ã': 'a',
      'ç': 'c',
      'é': 'e',
      'è': 'e',
      'ê': 'e',
      'ë': 'e',
      'î': 'i',
      'ï': 'i',
      'ì': 'i',
      'í': 'i',
      'ô': 'o',
      'ö': 'o',
      'ò': 'o',
      'ó': 'o',
      'õ': 'o',
      'ù': 'u',
      'û': 'u',
      'ü': 'u',
      'ú': 'u',
      'ÿ': 'y',
      'ñ': 'n',
    };
    map.forEach((k, v) => s = s.replaceAll(k, v));
    s = s.replaceAll(RegExp(r'[^a-z0-9]+'), '_');
    s = s.replaceAll(RegExp(r'_+'), '_');
    s = s.replaceAll(RegExp(r'^_+|_+$'), '');
    return s;
  }

  // ------------------------------------------------------------
  Future<({Uint8List bytes, String ext})?> _pickImage() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['png', 'jpg', 'jpeg'],
      withData: true,
    );
    if (res == null || res.files.isEmpty) return null;

    final f = res.files.first;
    final bytes = f.bytes;
    if (bytes == null) {
      _showError("Impossible de lire le fichier sélectionné.");
      return null;
    }

    final extRaw = (p.extension(f.name).replaceFirst('.', '')).toLowerCase();
    final ext = (extRaw == 'jpeg') ? 'jpg' : extRaw;

    if (ext != 'png' && ext != 'jpg') {
      _showError("Format non supporté. Utilisez PNG ou JPG.");
      return null;
    }

    return (bytes: bytes, ext: ext);
  }

  // ------------------------------------------------------------
  Future<({String path, String url})> _uploadPhoto({
    required String cse,
    required String name,
    required Uint8List bytes,
    required String ext,
  }) async {
    final cleanCse = cse.trim();
    final fileName = '${_slugify(name)}.$ext';
    final objectPath = '$cleanCse/$fileName';

    final storage = supa.storage.from('photos');

    await storage.uploadBinary(
      objectPath,
      bytes,
      fileOptions: FileOptions(
        upsert: true,
        contentType: ext == 'png' ? 'image/png' : 'image/jpeg',
      ),
    );

    final publicUrl = storage.getPublicUrl(objectPath);
    return (path: objectPath, url: publicUrl);
  }

  Future<void> _deletePhotoIfAny(String? photoPath) async {
    final pp = (photoPath ?? '').trim();
    if (pp.isEmpty) return;
    try {
      await supa.storage.from('photos').remove([pp]);
    } catch (_) {
      // best effort
    }
  }

  // ------------------------------------------------------------
  Future<void> _openCreateDialog() async {
    final currentCse = (_selectedCse ?? _myCse ?? '').trim();
    if (currentCse.isEmpty) return;

    final options = {..._cseOptions, currentCse}.toList()..sort();

    final result = await showDialog<_MemberDraft>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _MemberEditDialog(
        title: 'Ajouter un membre',
        cseOptions: options,
        initial: _MemberDraft(
          id: null,
          name: '',
          role: '',
          phone: '',
          cse: currentCse,
          sector: '',
          email: '',
          orderIndex: _nextOrderIndex(),
          photoUrl: null,
          photoPath: null,
        ),
      ),
    );

    if (result == null) return;
    await _saveMember(result, isEdit: false);
  }

  Future<void> _openEditDialog(Map<String, dynamic> row) async {
    final rowCse = (row['cse'] ?? '').toString().trim();
    final options = {..._cseOptions, if (rowCse.isNotEmpty) rowCse}.toList()
      ..sort();

    final result = await showDialog<_MemberDraft>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _MemberEditDialog(
        title: 'Modifier un membre',
        cseOptions: options,
        initial: _MemberDraft.fromRow(row),
      ),
    );

    if (result == null) return;
    await _saveMember(result, isEdit: true);
  }

  int _nextOrderIndex() {
    if (_rows.isEmpty) return 1;
    final maxIdx = _rows
        .map((r) => (r['order_index'] as int?) ?? 0)
        .fold<int>(0, (a, b) => a > b ? a : b);
    return maxIdx + 1;
  }

  // ------------------------------------------------------------
  Future<void> _saveMember(_MemberDraft draft, {required bool isEdit}) async {
    // ✅ IMPORTANT : on autorise temporairement la gestion cross-CSE
    // (ancien blocage supprimé volontairement)
    if (draft.name.trim().isEmpty) {
      _showError("Le nom est obligatoire.");
      return;
    }
    /*if (draft.cse.trim().isEmpty) {
      _showError("Le CSE (secteur) est obligatoire.");
      return;
    }*/

    setState(() => _saving = true);

    try {
      String? photoPath = draft.photoPath;
      String? photoUrl = draft.photoUrl;

      final oldPath = (draft.photoPath ?? '').trim();

      if (draft.newPhotoBytes != null && draft.newPhotoExt != null) {
        final uploaded = await _uploadPhoto(
          cse: draft.cse.trim(), // ✅ upload dans le dossier du CSE choisi
          name: draft.name.trim(),
          bytes: draft.newPhotoBytes!,
          ext: draft.newPhotoExt!,
        );

        if (oldPath.isNotEmpty && oldPath != uploaded.path) {
          await _deletePhotoIfAny(oldPath);
        }

        photoPath = uploaded.path;
        photoUrl = uploaded.url;
      }

      final payload = <String, dynamic>{
        'name': draft.name.trim(),
        'role': draft.role.trim(),
        'phone': draft.phone.trim(),
        'cse': draft.cse.trim(), // ✅ on sauvegarde le CSE choisi
        'sector': draft.sector.trim(),
        'email': draft.email.trim(),
        'photo_path': photoPath,
        'photo_url': photoUrl,
        'order_index': draft.orderIndex,
      };

      if (isEdit) {
        if (draft.id == null) throw Exception('id manquant pour update');
        await supa.from('members').update(payload).eq('id', draft.id!);
        _showOk("Membre mis à jour.");
      } else {
        await supa.from('members').insert(payload);
        _showOk("Membre ajouté.");
      }

      // Si tu modifies le CSE dans le dialog, on recale le filtre sur le CSE du membre
      if (mounted &&
          draft.cse.trim().isNotEmpty &&
          _selectedCse != draft.cse.trim()) {
        setState(() => _selectedCse = draft.cse.trim());
      }

      await _fetchMembers();
    } catch (e) {
      _showError("Erreur sauvegarde: $e");
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _deleteMember(Map<String, dynamic> row) async {
    // ✅ IMPORTANT : on autorise temporairement la gestion cross-CSE
    final name = (row['name'] ?? '').toString();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Supprimer ce membre ?"),
        content: Text('Confirmez la suppression de "$name".'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Annuler"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.rouge,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Supprimer"),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _saving = true);
    try {
      final id = row['id'];
      if (id == null) throw Exception('id manquant');
      await supa.from('members').delete().eq('id', id);

      await _deletePhotoIfAny(row['photo_path']?.toString());

      _showOk("Membre supprimé.");
      await _fetchMembers();
    } catch (e) {
      _showError("Erreur suppression: $e");
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Membres du syndicat'),
        backgroundColor: cs.primary,
        foregroundColor: cs.onPrimary,
        actions: [
          IconButton(
            tooltip: 'Rafraîchir',
            icon: const Icon(Icons.refresh),
            onPressed: _fetchMembers,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _saving ? null : _openCreateDialog,
        backgroundColor: AppColors.vert,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text("Ajouter"),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Votre CSE admin : ${_myCse ?? "-"}',
                          style: text.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: cs.onSurface,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 260,
                        child: DropdownButtonFormField<String>(
                          value: _selectedCse,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Secteur (CSE) affiché',
                          ),
                          items: _cseOptions
                              .map(
                                (c) => DropdownMenuItem<String>(
                                  value: c,
                                  child: Text(c),
                                ),
                              )
                              .toList(),
                          onChanged: _saving
                              ? null
                              : (v) async {
                                  if (v == null || v.trim().isEmpty) return;
                                  setState(() => _selectedCse = v.trim());
                                  await _fetchMembers();
                                },
                        ),
                      ),
                      if (_saving) ...[
                        const SizedBox(width: 12),
                        const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: _rows.isEmpty
                        ? Center(
                            child: Text(
                              "Aucun membre dans ce CSE.",
                              style: text.bodyLarge?.copyWith(
                                color: Colors.grey[700],
                              ),
                            ),
                          )
                        : SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: DataTable(
                              headingRowColor: WidgetStateProperty.all(
                                cs.primary.withValues(alpha: 0.08),
                              ),
                              columns: const [
                                DataColumn(label: Text('#')),
                                DataColumn(label: Text('Nom')),
                                DataColumn(label: Text('Rôle')),
                                DataColumn(label: Text('Téléphone')),
                                DataColumn(label: Text('Email')),
                                DataColumn(label: Text('Photo')),
                                DataColumn(label: Text('Actions')),
                              ],
                              rows: _rows.map((r) {
                                final idx = (r['order_index'] ?? 0).toString();
                                final photoUrl = (r['photo_url'] ?? '')
                                    .toString()
                                    .trim();

                                return DataRow(
                                  cells: [
                                    DataCell(Text(idx)),
                                    DataCell(
                                      Text((r['name'] ?? '').toString()),
                                    ),
                                    DataCell(
                                      Text((r['role'] ?? '').toString()),
                                    ),
                                    DataCell(
                                      Text((r['phone'] ?? '').toString()),
                                    ),
                                    DataCell(
                                      Text((r['email'] ?? '').toString()),
                                    ),
                                    DataCell(
                                      photoUrl.isEmpty
                                          ? const Text('-')
                                          : SizedBox(
                                              width: 42,
                                              height: 42,
                                              child: ClipRRect(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                child: Image.network(
                                                  photoUrl,
                                                  fit: BoxFit.cover,
                                                  errorBuilder:
                                                      (context, _, __) =>
                                                          const Icon(
                                                            Icons.broken_image,
                                                          ),
                                                ),
                                              ),
                                            ),
                                    ),
                                    DataCell(
                                      Row(
                                        children: [
                                          IconButton(
                                            tooltip: 'Modifier',
                                            icon: const Icon(Icons.edit),
                                            onPressed: _saving
                                                ? null
                                                : () => _openEditDialog(r),
                                          ),
                                          IconButton(
                                            tooltip: 'Supprimer',
                                            icon: const Icon(
                                              Icons.delete,
                                              color: Colors.redAccent,
                                            ),
                                            onPressed: _saving
                                                ? null
                                                : () => _deleteMember(r),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                );
                              }).toList(),
                            ),
                          ),
                  ),
                ],
              ),
            ),
    );
  }
}

// ============================================================================
// Draft + Dialog
// ============================================================================
class _MemberDraft {
  final int? id;
  final String name;
  final String role;
  final String phone;

  // ✅ CSE modifiable (dropdown)
  final String cse;

  final String sector;
  final String email;
  final int orderIndex;

  final String? photoUrl;
  final String? photoPath;

  final Uint8List? newPhotoBytes;
  final String? newPhotoExt;

  const _MemberDraft({
    required this.id,
    required this.name,
    required this.role,
    required this.phone,
    required this.cse,
    required this.sector,
    required this.email,
    required this.orderIndex,
    required this.photoUrl,
    required this.photoPath,
    this.newPhotoBytes,
    this.newPhotoExt,
  });

  static _MemberDraft fromRow(Map<String, dynamic> r) {
    return _MemberDraft(
      id: r['id'] as int?,
      name: (r['name'] ?? '').toString(),
      role: (r['role'] ?? '').toString(),
      phone: (r['phone'] ?? '').toString(),
      cse: (r['cse'] ?? '').toString(),
      sector: (r['sector'] ?? '').toString(),
      email: (r['email'] ?? '').toString(),
      photoUrl: (r['photo_url'] ?? '').toString(),
      photoPath: (r['photo_path'] ?? '').toString(),
      orderIndex: (r['order_index'] as int?) ?? 0,
    );
  }

  _MemberDraft copyWith({
    String? name,
    String? role,
    String? phone,
    String? cse,
    String? sector,
    String? email,
    int? orderIndex,
    Uint8List? newPhotoBytes,
    String? newPhotoExt,
  }) {
    return _MemberDraft(
      id: id,
      name: name ?? this.name,
      role: role ?? this.role,
      phone: phone ?? this.phone,
      cse: cse ?? this.cse,
      sector: sector ?? this.sector,
      email: email ?? this.email,
      orderIndex: orderIndex ?? this.orderIndex,
      photoUrl: photoUrl,
      photoPath: photoPath,
      newPhotoBytes: newPhotoBytes ?? this.newPhotoBytes,
      newPhotoExt: newPhotoExt ?? this.newPhotoExt,
    );
  }
}

class _MemberEditDialog extends StatefulWidget {
  final String title;
  final _MemberDraft initial;
  final List<String> cseOptions;

  const _MemberEditDialog({
    required this.title,
    required this.initial,
    required this.cseOptions,
  });

  @override
  State<_MemberEditDialog> createState() => _MemberEditDialogState();
}

class _MemberEditDialogState extends State<_MemberEditDialog> {
  late _MemberDraft _draft;

  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _roleCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _sectorCtrl = TextEditingController();
  final _orderCtrl = TextEditingController();

  bool _picking = false;

  @override
  void initState() {
    super.initState();
    _draft = widget.initial;

    _nameCtrl.text = _draft.name;
    _roleCtrl.text = _draft.role;
    _phoneCtrl.text = _draft.phone;
    _emailCtrl.text = _draft.email;
    _sectorCtrl.text = _draft.sector;
    _orderCtrl.text = _draft.orderIndex.toString();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _roleCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _sectorCtrl.dispose();
    _orderCtrl.dispose();
    super.dispose();
  }

  Future<({Uint8List bytes, String ext})?> _pickImage() async {
    setState(() => _picking = true);
    try {
      final res = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['png', 'jpg', 'jpeg'],
        withData: true,
      );
      if (res == null || res.files.isEmpty) return null;

      final f = res.files.first;
      final bytes = f.bytes;
      if (bytes == null) return null;

      var ext = p.extension(f.name).replaceFirst('.', '').toLowerCase();
      if (ext == 'jpeg') ext = 'jpg';
      if (ext != 'png' && ext != 'jpg') return null;

      return (bytes: bytes, ext: ext);
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final photoPreviewBytes = _draft.newPhotoBytes;
    final hasNetworkPhoto = (_draft.photoUrl ?? '').trim().isNotEmpty;

    Widget preview;
    if (photoPreviewBytes != null) {
      preview = ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.memory(
          photoPreviewBytes,
          width: 90,
          height: 90,
          fit: BoxFit.cover,
        ),
      );
    } else if (hasNetworkPhoto) {
      preview = ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(
          _draft.photoUrl!,
          width: 90,
          height: 90,
          fit: BoxFit.cover,
          errorBuilder: (context, _, __) => const Icon(Icons.broken_image),
        ),
      );
    } else {
      preview = Container(
        width: 90,
        height: 90,
        decoration: BoxDecoration(
          color: Colors.grey.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.withValues(alpha: 0.30)),
        ),
        child: const Icon(Icons.person, size: 36),
      );
    }

    final cseItems = widget.cseOptions
        .map((c) => DropdownMenuItem<String>(value: c, child: Text(c)))
        .toList();

    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 560,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              children: [
                Row(
                  children: [
                    preview,
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _picking
                            ? null
                            : () async {
                                final picked = await _pickImage();
                                if (picked == null) return;

                                setState(() {
                                  _draft = _draft.copyWith(
                                    newPhotoBytes: picked.bytes,
                                    newPhotoExt: picked.ext,
                                  );
                                });
                              },
                        icon: _picking
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.upload),
                        label: const Text("Choisir une photo (PNG/JPG)"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.marine,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // ✅ Dropdown CSE dans le dialog
                DropdownButtonFormField<String>(
                  value: (_draft.cse.trim().isEmpty) ? null : _draft.cse.trim(),
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Secteur (CSE)'),
                  items: cseItems,
                  onChanged: (v) {
                    setState(() {
                      _draft = _draft.copyWith(cse: (v ?? '').trim());
                    });
                  },
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Choisissez un CSE'
                      : null,
                ),

                const SizedBox(height: 10),
                TextFormField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(labelText: 'Nom / Prénom'),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Champ obligatoire'
                      : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _roleCtrl,
                  decoration: const InputDecoration(labelText: 'Rôle'),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _phoneCtrl,
                  decoration: const InputDecoration(labelText: 'Téléphone'),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _emailCtrl,
                  decoration: const InputDecoration(labelText: 'Email'),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _sectorCtrl,
                  decoration: const InputDecoration(labelText: 'Secteur'),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _orderCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Ordre (order_index)',
                  ),
                  keyboardType: TextInputType.number,
                  validator: (v) {
                    final t = (v ?? '').trim();
                    if (t.isEmpty) return null;
                    return int.tryParse(t) == null ? 'Nombre attendu' : null;
                  },
                ),

                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'CSE sélectionné: ${_draft.cse}',
                    style: TextStyle(
                      color: cs.onSurface.withValues(alpha: 0.70),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.vert,
            foregroundColor: Colors.white,
          ),
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;

            final order = int.tryParse(_orderCtrl.text.trim());
            final next = _draft.copyWith(
              name: _nameCtrl.text,
              role: _roleCtrl.text,
              phone: _phoneCtrl.text,
              email: _emailCtrl.text,
              sector: _sectorCtrl.text,
              orderIndex: order ?? _draft.orderIndex,
            );
            Navigator.pop(context, next);
          },
          child: const Text('Enregistrer'),
        ),
      ],
    );
  }
}
