import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme/brand_colors.dart';

/// ==============================
/// 🔹 Modèle filtres → CSV (stocké dans notification_outbox)
/// ==============================
class OutboxFilters {
  List<String> niveaux = []; // vide => 'Tous'
  List<String> cse = []; // vide => 'Tous'
  List<String> metiers = []; // vide => 'Tous' (comparés à effectif.emploi)

  Map<String, String> toCSV() {
    String csv(List<String> xs) => xs.isEmpty ? 'Tous' : xs.join(', ');
    return {'niveau': csv(niveaux), 'cse': csv(cse), 'metier': csv(metiers)};
  }
}

/// ==============================
/// 🔹 Chips multi-sélection (pour CSE & Niveaux)
/// ==============================
class MultiChips extends StatefulWidget {
  final String label;
  final List<String> all;
  final List<String> selected;
  final void Function(List<String>) onChanged;

  const MultiChips({
    super.key,
    required this.label,
    required this.all,
    required this.selected,
    required this.onChanged,
  });

  @override
  State<MultiChips> createState() => _MultiChipsState();
}

class _MultiChipsState extends State<MultiChips> {
  late List<String> _selected = [...widget.selected];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            InputChip(
              label: Text('${widget.label}: Tous'),
              selected: _selected.isEmpty,
              onSelected: (_) {
                setState(() => _selected.clear());
                widget.onChanged(_selected);
              },
            ),
            for (final v in widget.all)
              FilterChip(
                label: Text(v),
                selected: _selected.contains(v),
                onSelected: (sel) {
                  setState(() {
                    if (sel) {
                      _selected.add(v);
                    } else {
                      _selected.remove(v);
                    }
                  });
                  widget.onChanged(_selected);
                },
              ),
          ],
        ),
      ],
    );
  }
}

/// ==============================
/// 🔹 Boîte de dialogue multi-sélection (recherchable) pour Métiers
/// ==============================
class MultiSelectDialog extends StatefulWidget {
  final String title;
  final List<String> options; // toutes les valeurs possibles
  final List<String> initialSelected; // sélection initiale
  final String searchHint;

  const MultiSelectDialog({
    super.key,
    required this.title,
    required this.options,
    required this.initialSelected,
    this.searchHint = 'Rechercher…',
  });

  @override
  State<MultiSelectDialog> createState() => _MultiSelectDialogState();
}

class _MultiSelectDialogState extends State<MultiSelectDialog> {
  final TextEditingController _searchCtl = TextEditingController();
  late List<String> _filtered;
  late Set<String> _selected;

  @override
  void initState() {
    super.initState();
    _filtered = [...widget.options];
    _selected = {...widget.initialSelected};
    _searchCtl.addListener(() {
      final q = _searchCtl.text.trim().toUpperCase();
      setState(() {
        _filtered = q.isEmpty
            ? [...widget.options]
            : widget.options.where((o) => o.toUpperCase().contains(q)).toList();
      });
    });
  }

  @override
  void dispose() {
    _searchCtl.dispose();
    super.dispose();
  }

  void _toggle(String v, bool sel) {
    setState(() => sel ? _selected.add(v) : _selected.remove(v));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        '${widget.title} (${_selected.length}/${widget.options.length})',
      ),
      content: SizedBox(
        width: 480,
        height: 520,
        child: Column(
          children: [
            TextField(
              controller: _searchCtl,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Rechercher un métier…',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                TextButton.icon(
                  onPressed: () =>
                      setState(() => _selected = widget.options.toSet()),
                  icon: const Icon(Icons.select_all),
                  label: const Text('Tout sélectionner'),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: () => setState(() => _selected.clear()),
                  icon: const Icon(Icons.clear_all),
                  label: const Text('Effacer'),
                ),
                const Spacer(),
                Text('${_filtered.length} éléments'),
              ],
            ),
            const SizedBox(height: 6),
            Expanded(
              child: Scrollbar(
                thumbVisibility: true,
                child: ListView.builder(
                  itemCount: _filtered.length,
                  itemBuilder: (_, i) {
                    final v = _filtered[i];
                    final sel = _selected.contains(v);
                    return CheckboxListTile(
                      dense: true,
                      title: Text(v, overflow: TextOverflow.ellipsis),
                      value: sel,
                      onChanged: (b) => _toggle(v, b ?? false),
                      controlAffinity: ListTileControlAffinity.leading,
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, null),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _selected.toList()),
          child: const Text('Valider'),
        ),
      ],
    );
  }
}

// =====================================================
// 🔷 Modèle & presets de types de push
// =====================================================
class PushType {
  final String key; // ex: 'info', 'alerte', etc.
  final String label; // affiché dans la liste
  final String defaultTitle; // titre auto pré-rempli
  final IconData icon;
  final Color color;
  final String channelId; // Android channel
  final String? sound; // nom de fichier dans res/raw (Android)

  const PushType({
    required this.key,
    required this.label,
    required this.defaultTitle,
    required this.icon,
    required this.color,
    required this.channelId,
    this.sound,
  });
}

const _types = <PushType>[
  PushType(
    key: 'info',
    label: 'Informations',
    defaultTitle: 'ℹ️ Informations',
    icon: Icons.info_outline,
    color: AppColors.marine,
    channelId: 'info_general',
    sound: 'notif_info',
  ),
  PushType(
    key: 'alerte',
    label: 'Alerte CFE-CGC',
    defaultTitle: '⚠️ Alerte CFE-CGC',
    icon: Icons.warning_amber_rounded,
    color: AppColors.rose,
    channelId: 'alerts_urgent',
    sound: 'alert_urgent',
  ),
  PushType(
    key: 'live_cse',
    label: 'En direct du CSE',
    defaultTitle: '📣 En direct du CSE',
    icon: Icons.campaign,
    color: AppColors.violet,
    channelId: 'cse_live',
    sound: 'alert_megaphone',
  ),
  PushType(
    key: 'live_cssct',
    label: 'En direct du CSSCT',
    defaultTitle: '🛡️ En direct du CSSCT',
    icon: Icons.health_and_safety,
    color: AppColors.jaune,
    channelId: 'cssct_updates',
    sound: 'notif_cssct',
  ),
  PushType(
    key: 'cadres',
    label: 'Spécial Cadres',
    defaultTitle: '🎓 Spécial Cadres',
    icon: Icons.workspace_premium,
    color: AppColors.cyan,
    channelId: 'cadres_focus',
    sound: 'notif_focus',
  ),
  PushType(
    key: 'managers',
    label: 'Spécial Manageurs',
    defaultTitle: '👔 Spécial Manageurs',
    icon: Icons.manage_accounts,
    color: AppColors.vert,
    channelId: 'managers_focus',
    sound: 'notif_focus',
  ),
];

const _customLabel = 'Titre libre';

/// Mapping catégorie → codes niveau (pour la RPC)
const Map<String, List<String>> kNiveauMap = {
  'Cadres': ['12', '21', '22', '31', '32', 'CT', 'HC', 'PB'],
  'Techniciens': ['N3', 'N4'],
  'Employés': ['N1', 'N2'],
  'Managers': ['N5'],
};

class NotificationCreatePage extends StatefulWidget {
  const NotificationCreatePage({super.key});

  @override
  State<NotificationCreatePage> createState() => _NotificationCreatePageState();
}

class _NotificationCreatePageState extends State<NotificationCreatePage> {
  final supa = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();

  // --- Type de push ---
  PushType? _selectedType = _types.first;
  final _customTitleCtl = TextEditingController();

  // --- Filtres (multi) ---
  final filters = OutboxFilters();

  // 👉 listes proposées (statiques)
  final List<String> _niveauxCats = const [
    'Cadres',
    'Techniciens',
    'Employés',
    'Managers',
  ];
  final List<String> _cseList = const [
    'CSE INDUSTRIEL',
    'CSE EXPLOITATION HUB',
    'CSE PILOTAGE ECONOMIQUE',
    'CSE SYSTEMES D\'INFORMATION',
    'CSE AIR FRANCE CARGO',
    'CSE EXPLOITATION AERIENNE',
  ];

  // --- Métiers dynamiques via RPC ---
  List<String> _metiersAll = [];
  bool _metiersLoading = false;

  // Population visée (chips)
  final List<String> _popOptions = const [
    'Tous',
    'Militants',
    'Adhérents',
    'Enrolés',
  ];
  final Set<String> _popSelected = {'Tous'};

  // Contenu + pièce jointe
  String _message = '';
  PlatformFile? _attachedFile;

  bool _loading = false;
  String? _status;

  @override
  void initState() {
    super.initState();
    _customTitleCtl.text = _selectedType?.defaultTitle ?? '';
    _loadMetiers(); // charge initialement (Tous CSE + Tous niveaux)
  }

  @override
  void dispose() {
    _customTitleCtl.dispose();
    super.dispose();
  }

  List<String> _codesForNiveaux(List<String> cats) {
    final out = <String>[];
    for (final c in cats) {
      out.addAll(kNiveauMap[c] ?? const []);
    }
    return out;
  }

  /// 🔄 Charge distinctement les métiers depuis la RPC `distinct_metiers`
  Future<void> _loadMetiers() async {
    setState(() => _metiersLoading = true);
    try {
      final cseList = filters.cse.isEmpty ? null : filters.cse;
      final nivList = filters.niveaux.isEmpty
          ? null
          : _codesForNiveaux(filters.niveaux);

      final rows = await supa.rpc(
        'distinct_metiers',
        params: {'p_cse_list': cseList, 'p_niveau_list': nivList},
      );

      final list = List<Map<String, dynamic>>.from(rows)
          .map((r) => (r['emploi'] ?? '').toString().trim())
          .where((e) => e.isNotEmpty)
          .toList();

      setState(() {
        _metiersAll = list;
        // Nettoie la sélection si des valeurs ne sont plus proposées
        final upperSet = _metiersAll.map((e) => e.toUpperCase()).toSet();
        filters.metiers.removeWhere((m) => !upperSet.contains(m.toUpperCase()));
      });
    } catch (e) {
      // Optionnel: log
    } finally {
      if (mounted) setState(() => _metiersLoading = false);
    }
  }

  Future<void> _pickAttachment() async {
    try {
      final res = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'png'],
        withData: true,
      );
      if (res != null && res.files.isNotEmpty) {
        setState(() => _attachedFile = res.files.first);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erreur fichier : $e')));
    }
  }

  Future<void> _sendNotification() async {
    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid) return;
    _formKey.currentState!.save();

    // Vérifier session → évite author_id = null
    final uid = supa.auth.currentUser?.id;
    if (uid == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Session expirée : veuillez vous reconnecter.'),
          ),
        );
      }
      return;
    }
    debugPrint('admin_app uid = $uid');

    // Titre effectif
    final bool isCustom = (_selectedType == null);
    final String effectiveTitle = isCustom
        ? _customTitleCtl.text.trim()
        : (_selectedType?.defaultTitle ?? 'Notification');

    if (effectiveTitle.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Le titre est requis.')));
      return;
    }

    if (_popSelected.isEmpty) _popSelected.add('Tous');

    setState(() {
      _loading = true;
      _status = null;
    });

    try {
      // 1) Upload éventuel
      String? uploadedUrl;
      if (_attachedFile != null && _attachedFile!.bytes != null) {
        final bytes = _attachedFile!.bytes!;
        final safeName = _attachedFile!.name.replaceAll(
          RegExp(r'[^\w\-.]'),
          '_',
        );
        final storageName =
            'notif_${DateTime.now().millisecondsSinceEpoch}_$safeName';

        await supa.storage
            .from('Notifications')
            .uploadBinary(
              storageName,
              bytes,
              fileOptions: const FileOptions(upsert: true),
            );

        uploadedUrl = supa.storage
            .from('Notifications')
            .getPublicUrl(storageName);
      }

      // 2) Filtres (CSV) + meta
      final csv = filters.toCSV();

      final notifMeta = {
        'category': _selectedType?.key ?? 'custom',
        'channel_id': _selectedType?.channelId,
        'sound': _selectedType?.sound,
        'color_hex': _selectedType == null
            ? null
            : '#${_selectedType!.color.value.toRadixString(16).padLeft(8, '0').substring(2)}',
        'icon_hint': _selectedType?.icon.codePoint,
        'population': _popSelected.toList(),
      };
      final filtersBase64 = base64Encode(
        utf8.encode(jsonEncode({'notif_meta': notifMeta})),
      );

      // 3) Insert outbox (avec author_id sûr)
      final payload = {
        'type': effectiveTitle,
        'message': _message,
        'attachment_url': uploadedUrl ?? '',
        'filters':
            filtersBase64, // méta/trace, le filtrage est via cse/niveau/metier
        'status': 'queued',
        'author_id': uid, // ✅ non-null
        // 👇 champs utilisés par la RPC/Edge
        'cse': csv['cse'],
        'niveau': csv['niveau'],
        'metier': csv['metier'], // comparé à effectif.emploi
      };

      final row = await supa
          .from('notification_outbox')
          .insert(payload)
          .select('id, author_id')
          .single();
      debugPrint('outbox created: ${row['id']} by ${row['author_id']}');
      final outboxId = row['id'] as String;

      // 4) Edge function
      final res = await supa.functions.invoke(
        'send_push_from_outbox', // alias → v2 dans ton backend
        body: {'outbox_id': outboxId},
      );

      if (res.status >= 400) {
        setState(() => _status = "❌ Erreur function: ${res.data}");
      } else {
        setState(() => _status = "✅ Notification envoyée !");
      }
    } catch (e) {
      setState(() => _status = "Erreur: $e");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isCustom = (_selectedType == null);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.marine,
        title: const Text('📢 Nouvelle notification'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // ---- Type de push ----
              InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Type de push',
                  border: OutlineInputBorder(),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<PushType?>(
                    isExpanded: true,
                    value: _selectedType,
                    items: [
                      ..._types.map(
                        (pt) => DropdownMenuItem(
                          value: pt,
                          child: Row(
                            children: [
                              Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: pt.color.withOpacity(.15),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(pt.icon, size: 18, color: pt.color),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                pt.label,
                                style: const TextStyle(fontSize: 16),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const DropdownMenuItem(
                        value: null,
                        child: Row(
                          children: [
                            Icon(Icons.edit_note, size: 20),
                            SizedBox(width: 12),
                            Text(_customLabel, style: TextStyle(fontSize: 16)),
                          ],
                        ),
                      ),
                    ],
                    onChanged: (pt) {
                      setState(() => _selectedType = pt);
                      if (pt != null) {
                        _customTitleCtl.text = pt.defaultTitle;
                      } else {
                        _customTitleCtl.clear();
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // ---- Titre ----
              TextFormField(
                controller: _customTitleCtl,
                decoration: const InputDecoration(
                  labelText: 'Titre de la notification',
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Saisir un titre' : null,
              ),

              // ---- Preview du type ----
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: isCustom
                      ? const SizedBox.shrink()
                      : Chip(
                          key: ValueKey(_selectedType?.key),
                          avatar: CircleAvatar(
                            backgroundColor: _selectedType!.color.withOpacity(
                              .15,
                            ),
                            child: Icon(
                              _selectedType!.icon,
                              size: 16,
                              color: _selectedType!.color,
                            ),
                          ),
                          label: Text(
                            '${_selectedType!.label} • ${_selectedType!.channelId}'
                            '${_selectedType!.sound != null ? ' • 🔊 ${_selectedType!.sound}' : ''}',
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 18),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Filtres',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              const SizedBox(height: 8),

              // === NIVEAUX (multi) ===
              MultiChips(
                label: 'Niveaux',
                all: _niveauxCats,
                selected: filters.niveaux,
                onChanged: (xs) {
                  setState(() => filters.niveaux = xs);
                  _loadMetiers(); // 🔄 recharge la liste des métiers
                },
              ),
              const SizedBox(height: 12),

              // === CSE (multi) ===
              MultiChips(
                label: 'CSE',
                all: _cseList,
                selected: filters.cse,
                onChanged: (xs) {
                  setState(() => filters.cse = xs);
                  _loadMetiers(); // 🔄 recharge la liste des métiers
                },
              ),
              const SizedBox(height: 12),

              // === Métiers (multi) → boîte de dialogue ===
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Métiers',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(width: 10),
                      if (_metiersLoading)
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: _metiersAll.isEmpty
                        ? null
                        : () async {
                            final res = await showDialog<List<String>?>(
                              context: context,
                              builder: (_) => MultiSelectDialog(
                                title: 'Sélection des métiers',
                                options: _metiersAll,
                                initialSelected: filters.metiers,
                                searchHint: 'Rechercher un métier…',
                              ),
                            );
                            if (res != null) {
                              setState(() => filters.metiers = res);
                            }
                          },
                    child: InputDecorator(
                      isFocused: false,
                      isEmpty: filters.metiers.isEmpty,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        labelText: 'Choix des métiers',
                      ),
                      child: _metiersAll.isEmpty && !_metiersLoading
                          ? const Text(
                              'Aucun métier disponible pour les filtres actuels.',
                              style: TextStyle(color: Colors.grey),
                            )
                          : Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    filters.metiers.isEmpty
                                        ? 'Tous'
                                        : filters.metiers.length <= 3
                                        ? filters.metiers.join(', ')
                                        : '${filters.metiers.take(3).join(", ")} +${filters.metiers.length - 3} autres',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Icon(Icons.arrow_drop_down),
                              ],
                            ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Population (chips)
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Population visée',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: _popOptions.map((opt) {
                  final selected = _popSelected.contains(opt);
                  return FilterChip(
                    label: Text(opt),
                    selected: selected,
                    onSelected: (val) {
                      setState(() {
                        if (opt == 'Tous') {
                          _popSelected
                            ..clear()
                            ..add('Tous');
                        } else {
                          if (_popSelected.contains('Tous')) {
                            _popSelected.remove('Tous');
                          }
                          if (val) {
                            _popSelected.add(opt);
                          } else {
                            _popSelected.remove(opt);
                          }
                          if (_popSelected.isEmpty) _popSelected.add('Tous');
                        }
                      });
                    },
                  );
                }).toList(),
              ),

              const SizedBox(height: 16),

              // Contenu
              TextFormField(
                decoration: const InputDecoration(
                  labelText: "Contenu de l'information",
                  border: OutlineInputBorder(),
                ),
                maxLines: 5,
                onSaved: (v) => _message = (v ?? '').trim(),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Champ requis' : null,
              ),
              const SizedBox(height: 16),

              // Pièce jointe
              OutlinedButton.icon(
                onPressed: _pickAttachment,
                icon: const Icon(Icons.attach_file),
                label: Text(
                  _attachedFile == null
                      ? 'Ajouter une pièce jointe (facultatif)'
                      : 'Fichier : ${_attachedFile!.name}',
                ),
              ),
              const SizedBox(height: 24),

              // Envoyer
              ElevatedButton.icon(
                onPressed: _loading ? null : _sendNotification,
                icon: _loading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.send),
                label: const Text('Envoyer la notification'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.marine,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    vertical: 14,
                    horizontal: 24,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),

              const SizedBox(height: 16),
              if (_status != null)
                Text(
                  _status!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _status!.startsWith('❌') ? Colors.red : Colors.green,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
