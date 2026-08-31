import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

import '../../core/home_banner/home_banner_model.dart';
import '../../core/home_banner/home_banner_service.dart';
import '../../widgets/home_banner/home_banner_content_picker.dart';

class HomeBannerEditPage extends StatefulWidget {
  const HomeBannerEditPage({super.key, this.banner, this.service});

  final HomeBanner? banner;
  final HomeBannerService? service;

  @override
  State<HomeBannerEditPage> createState() => _HomeBannerEditPageState();
}

class _HomeBannerEditPageState extends State<HomeBannerEditPage> {
  late final HomeBannerService _service;
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _message;
  late final TextEditingController _actionValue;
  late final TextEditingController _actionLabel;
  late final TextEditingController _sortOrder;

  String _style = 'info';
  String _icon = 'campaign';
  String _actionType = 'none';
  Set<String> _audiences = {'all'};
  Set<String> _platforms = {'all'};
  DateTime? _startsAt;
  DateTime? _endsAt;
  bool _active = false;
  bool _dismissible = true;
  bool _saving = false;
  String? _selectedContentTitle;
  PlatformFile? _pendingPdf;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? HomeBannerService();
    final b = widget.banner;
    _title = TextEditingController(text: b?.title ?? '');
    _message = TextEditingController(text: b?.message ?? '');
    _actionValue = TextEditingController(text: b?.actionValue ?? '');
    _actionLabel = TextEditingController(
      text: b?.actionLabel ?? 'En savoir plus',
    );
    _sortOrder = TextEditingController(text: '${b?.sortOrder ?? 100}');
    _style = b?.style ?? 'info';
    _icon = b?.iconName ?? 'campaign';
    _actionType = b?.actionType ?? 'none';
    _audiences = {...?b?.audiences};
    if (_audiences.isEmpty) _audiences = {'all'};
    _platforms = {...?b?.platforms};
    if (_platforms.isEmpty) _platforms = {'all'};
    _startsAt = b?.startsAt;
    _endsAt = b?.endsAt;
    _active = b?.isActive ?? false;
    _dismissible = b?.isDismissible ?? true;
    if (b != null &&
        b.actionType != 'none' &&
        b.actionValue?.isNotEmpty == true) {
      _loadSelectedContentTitle();
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _message.dispose();
    _actionValue.dispose();
    _actionLabel.dispose();
    _sortOrder.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool start}) async {
    final current = start ? _startsAt : _endsAt;
    final date = await showDatePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
      initialDate: current ?? DateTime.now(),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current ?? DateTime.now()),
    );
    if (time == null) return;
    setState(() {
      final value = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
      if (start) {
        _startsAt = value;
      } else {
        _endsAt = value;
      }
    });
  }

  void _toggleSet(Set<String> target, String value) {
    setState(() {
      if (value == 'all') {
        target
          ..clear()
          ..add('all');
        return;
      }
      target.remove('all');
      if (!target.add(value)) target.remove(value);
      if (target.isEmpty) target.add('all');
    });
  }

  Future<void> _loadSelectedContentTitle() async {
    final title = await _service.resolveActionTitle(
      actionType: _actionType,
      actionValue: _actionValue.text,
    );
    if (!mounted || title == null || title.isEmpty) return;
    setState(() => _selectedContentTitle = title);
  }

  bool get _usesContentPicker =>
      const {'tract', 'press_review', 'podcast'}.contains(_actionType);

  String get _defaultActionLabel => switch (_actionType) {
    'tract' => 'Lire le tract',
    'press_review' => 'Lire la revue',
    'podcast' => 'Écouter le podcast',
    'pdf' => 'Ouvrir le PDF',
    'url' => 'Ouvrir le lien',
    _ => 'En savoir plus',
  };

  String get _selectionButtonLabel => switch (_actionType) {
    'tract' => 'Choisir parmi tous les tracts',
    'press_review' => 'Choisir parmi toutes les revues de presse',
    'podcast' => 'Choisir parmi tous les podcasts',
    _ => 'Choisir le contenu',
  };

  IconData get _selectionIcon => switch (_actionType) {
    'tract' => Icons.article_outlined,
    'press_review' => Icons.newspaper_rounded,
    'podcast' => Icons.podcasts_rounded,
    'pdf' => Icons.picture_as_pdf_rounded,
    _ => Icons.touch_app_rounded,
  };

  void _changeActionType(String value) {
    setState(() {
      _actionType = value;
      _actionValue.clear();
      _selectedContentTitle = null;
      _pendingPdf = null;
      _actionLabel.text = _defaultActionLabel;
    });
  }

  Future<void> _pickExistingContent() async {
    final choice = await showDialog<HomeBannerContentChoice>(
      context: context,
      builder: (_) =>
          HomeBannerContentPicker(actionType: _actionType, service: _service),
    );
    if (!mounted || choice == null) return;
    setState(() {
      _actionValue.text = choice.value;
      _selectedContentTitle = choice.title;
      _pendingPdf = null;
    });
  }

  Future<void> _pickPdf() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['pdf'],
        withData: true,
      );
      if (!mounted || result == null || result.files.isEmpty) return;
      final file = result.files.first;
      if (file.size > 50 * 1024 * 1024) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Le fichier PDF ne doit pas dépasser 50 Mo.'),
          ),
        );
        return;
      }
      if (file.bytes == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Impossible de lire ce fichier PDF.')),
        );
        return;
      }
      setState(() {
        _pendingPdf = file;
        _selectedContentTitle = file.name;
        _actionValue.clear();
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sélection du PDF impossible : $error')),
      );
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_endsAt != null && _startsAt != null && !_endsAt!.isAfter(_startsAt!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('La date de fin doit être après la date de début.'),
        ),
      );
      return;
    }
    if (_usesContentPicker && _actionValue.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choisissez le contenu à ouvrir.')),
      );
      return;
    }
    if (_actionType == 'pdf' &&
        _pendingPdf == null &&
        _actionValue.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choisissez le fichier PDF à ouvrir.')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      var actionValue = _actionValue.text.trim();
      if (_actionType == 'pdf' && _pendingPdf?.bytes != null) {
        actionValue = await _service.uploadActionPdf(
          fileName: _pendingPdf!.name,
          bytes: _pendingPdf!.bytes!,
        );
      }

      final values = <String, dynamic>{
        'title': _title.text.trim(),
        'message': _message.text.trim().isEmpty ? null : _message.text.trim(),
        'style': _style,
        'icon_name': _icon,
        'action_type': _actionType,
        'action_value': _actionType == 'none' || actionValue.isEmpty
            ? null
            : actionValue,
        'action_label': _actionLabel.text.trim().isEmpty
            ? null
            : _actionLabel.text.trim(),
        'audiences': _audiences.toList(),
        'platforms': _platforms.toList(),
        'starts_at': _startsAt?.toUtc().toIso8601String(),
        'ends_at': _endsAt?.toUtc().toIso8601String(),
        'is_active': _active,
        'is_dismissible': _dismissible,
        'sort_order': int.tryParse(_sortOrder.text) ?? 100,
      };

      if (widget.banner == null) {
        await _service.create(values);
      } else {
        await _service.update(widget.banner!.id, values);
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Enregistrement impossible : $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.banner == null ? 'Nouveau bandeau' : 'Modifier le bandeau',
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _title,
              decoration: const InputDecoration(labelText: 'Titre *'),
              maxLength: 120,
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Titre obligatoire' : null,
            ),
            TextFormField(
              controller: _message,
              decoration: const InputDecoration(labelText: 'Message'),
              minLines: 2,
              maxLines: 4,
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _style,
              decoration: const InputDecoration(labelText: 'Style'),
              items: const [
                DropdownMenuItem(
                  value: 'info',
                  child: Text('Information — orange CFDT'),
                ),
                DropdownMenuItem(
                  value: 'important',
                  child: Text('Important — rouge'),
                ),
                DropdownMenuItem(
                  value: 'success',
                  child: Text('Nouveauté — vert'),
                ),
              ],
              onChanged: (v) => setState(() => _style = v ?? 'info'),
            ),
            DropdownButtonFormField<String>(
              initialValue: _icon,
              decoration: const InputDecoration(labelText: 'Icône'),
              items: const [
                DropdownMenuItem(value: 'campaign', child: Text('Mégaphone')),
                DropdownMenuItem(value: 'info', child: Text('Information')),
                DropdownMenuItem(value: 'warning', child: Text('Alerte')),
                DropdownMenuItem(value: 'calendar', child: Text('Calendrier')),
              ],
              onChanged: (v) => setState(() => _icon = v ?? 'campaign'),
            ),
            const SizedBox(height: 16),
            Text(
              'Action au clic',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _actionType,
              decoration: const InputDecoration(labelText: 'Type'),
              items: const [
                DropdownMenuItem(value: 'none', child: Text('Aucune')),
                DropdownMenuItem(value: 'tract', child: Text('Tract existant')),
                DropdownMenuItem(
                  value: 'press_review',
                  child: Text('Revue de presse existante'),
                ),
                DropdownMenuItem(
                  value: 'podcast',
                  child: Text('Podcast existant'),
                ),
                DropdownMenuItem(
                  value: 'pdf',
                  child: Text('Autre fichier PDF'),
                ),
                DropdownMenuItem(value: 'url', child: Text('Lien web externe')),
                DropdownMenuItem(
                  value: 'internal',
                  child: Text('Page interne'),
                ),
                DropdownMenuItem(
                  value: 'news',
                  child: Text('Ancienne actualité / URL'),
                ),
              ],
              onChanged: (v) => _changeActionType(v ?? 'none'),
            ),
            if (_usesContentPicker) ...[
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _saving ? null : _pickExistingContent,
                icon: Icon(_selectionIcon),
                label: Text(_selectionButtonLabel),
              ),
              if (_selectedContentTitle?.isNotEmpty == true)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(_selectionIcon),
                  title: const Text('Contenu sélectionné'),
                  subtitle: Text(
                    _selectedContentTitle!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: IconButton(
                    tooltip: 'Retirer',
                    onPressed: () => setState(() {
                      _actionValue.clear();
                      _selectedContentTitle = null;
                    }),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ),
            ] else if (_actionType == 'pdf') ...[
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _saving ? null : _pickPdf,
                icon: const Icon(Icons.picture_as_pdf_rounded),
                label: Text(
                  _selectedContentTitle?.isNotEmpty == true
                      ? _selectedContentTitle!
                      : 'Choisir un fichier PDF',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (_selectedContentTitle?.isNotEmpty == true)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    'PDF sélectionné : $_selectedContentTitle',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
            ] else if (_actionType != 'none') ...[
              TextFormField(
                controller: _actionValue,
                decoration: InputDecoration(
                  labelText: _actionType == 'url'
                      ? 'URL https://… *'
                      : 'Route / identifiant / référence *',
                  helperText: switch (_actionType) {
                    'internal' =>
                      '/actualites, /revue-presse, /representants, '
                          '/notifications ou /espace-militant',
                    'news' => 'URL de l’article ou identifiant d’actualité',
                    _ => null,
                  },
                ),
                validator: (v) {
                  if (_actionType == 'none') return null;
                  if (v == null || v.trim().isEmpty)
                    return 'Destination obligatoire';
                  if (_actionType == 'url') {
                    final uri = Uri.tryParse(v.trim());
                    if (uri == null ||
                        !{'https', 'http'}.contains(uri.scheme)) {
                      return 'URL invalide';
                    }
                  }
                  return null;
                },
              ),
            ],
            if (_actionType != 'none') ...[
              TextFormField(
                controller: _actionLabel,
                decoration: const InputDecoration(labelText: 'Libellé du lien'),
              ),
            ],
            const SizedBox(height: 16),
            Text('Public', style: Theme.of(context).textTheme.titleMedium),
            Wrap(
              spacing: 8,
              children: ['all', 'adherent', 'militant', 'admin']
                  .map(
                    (v) => FilterChip(
                      label: Text(v == 'all' ? 'Tous' : v),
                      selected: _audiences.contains(v),
                      onSelected: (_) => _toggleSet(_audiences, v),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 12),
            Text('Plateformes', style: Theme.of(context).textTheme.titleMedium),
            Wrap(
              spacing: 8,
              children: ['all', 'ios', 'android', 'web']
                  .map(
                    (v) => FilterChip(
                      label: Text(v == 'all' ? 'Toutes' : v),
                      selected: _platforms.contains(v),
                      onSelected: (_) => _toggleSet(_platforms, v),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickDate(start: true),
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: Text(
                      _startsAt == null
                          ? 'Début libre'
                          : _formatDate(_startsAt!),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                if (_startsAt != null)
                  IconButton(
                    onPressed: () => setState(() => _startsAt = null),
                    icon: const Icon(Icons.clear),
                  ),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickDate(start: false),
                    icon: const Icon(Icons.stop_rounded),
                    label: Text(
                      _endsAt == null ? 'Fin libre' : _formatDate(_endsAt!),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                if (_endsAt != null)
                  IconButton(
                    onPressed: () => setState(() => _endsAt = null),
                    icon: const Icon(Icons.clear),
                  ),
              ],
            ),
            TextFormField(
              controller: _sortOrder,
              decoration: const InputDecoration(labelText: 'Ordre / priorité'),
              keyboardType: TextInputType.number,
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Actif'),
              value: _active,
              onChanged: (v) => setState(() => _active = v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('L’utilisateur peut le fermer'),
              value: _dismissible,
              onChanged: (v) => setState(() => _dismissible = v),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_rounded),
              label: const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatDate(DateTime value) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(value.day)}/${two(value.month)}/${value.year} ${two(value.hour)}:${two(value.minute)}';
}
