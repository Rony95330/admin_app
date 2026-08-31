import 'package:flutter/material.dart';

import '../../services/admin_data_service.dart';
import '../../theme/brand_colors.dart';
import 'admin_collections.dart';

class ManagedCollectionPage extends StatefulWidget {
  const ManagedCollectionPage({super.key, required this.definition});

  final AdminCollectionDefinition definition;

  @override
  State<ManagedCollectionPage> createState() => _ManagedCollectionPageState();
}

class _ManagedCollectionPageState extends State<ManagedCollectionPage> {
  final AdminDataService _service = AdminDataService();
  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> _rows = const <Map<String, dynamic>>[];
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await _service.list(widget.definition.resource);
      if (!mounted) return;
      setState(() => _rows = rows);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> get _filteredRows {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return _rows;
    return _rows.where((row) {
      return row.values.any(
        (value) => value?.toString().toLowerCase().contains(query) ?? false,
      );
    }).toList();
  }

  Future<void> _openEditor({Map<String, dynamic>? row}) async {
    if (_saving) return;
    final isNew = row == null;
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ManagedRowDialog(
        definition: widget.definition,
        initialRow: row ?? const <String, dynamic>{},
        isNew: isNew,
      ),
    );
    if (result == null || !mounted) return;

    setState(() => _saving = true);
    try {
      await _service.save(
        resource: widget.definition.resource,
        row: result,
        isNew: isNew,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isNew ? 'Élément ajouté.' : 'Modifications enregistrées.',
          ),
          backgroundColor: AppColors.bleuPetrole,
        ),
      );
      await _load();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Enregistrement impossible : $error'),
          backgroundColor: AppColors.danger,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete(Map<String, dynamic> row) async {
    if (_saving || !widget.definition.allowDelete) return;
    final primaryValue = row[widget.definition.primaryKey];
    if (primaryValue == null || primaryValue.toString().isEmpty) return;

    final label = _titleFor(row);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmer la suppression'),
        content: Text('Supprimer « $label » ? Cette action est définitive.'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _saving = true);
    try {
      await _service.delete(
        resource: widget.definition.resource,
        primaryValue: primaryValue,
      );
      await _load();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Suppression impossible : $error'),
          backgroundColor: AppColors.danger,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _titleFor(Map<String, dynamic> row) {
    final combinedTitle = widget.definition.titleKeys
        .map((key) => row[key]?.toString().trim() ?? '')
        .where((value) => value.isNotEmpty)
        .join(' ');
    if (combinedTitle.isNotEmpty) return combinedTitle;

    final value = row[widget.definition.titleKey]?.toString().trim() ?? '';
    if (value.isNotEmpty) return value;
    return row[widget.definition.primaryKey]?.toString() ?? 'Élément';
  }

  String _subtitleFor(Map<String, dynamic> row) {
    return widget.definition.subtitleKeys
        .map((key) => row[key])
        .where((value) => value != null && value.toString().trim().isNotEmpty)
        .map((value) {
          if (value is List) return value.join(', ');
          if (value is bool) return value ? 'Oui' : 'Non';
          return value.toString();
        })
        .join(' • ');
  }

  Widget _rowCard(Map<String, dynamic> row) {
    final title = _titleFor(row);
    final subtitle = _subtitleFor(row);
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: _saving ? null : () => _openEditor(row: row),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: <Widget>[
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.orange.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(widget.definition.icon, color: AppColors.orange),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Tooltip(
                      message: title,
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    if (subtitle.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 5),
                      Flexible(
                        child: Text(
                          subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'Actions',
                onSelected: (value) {
                  if (value == 'edit') _openEditor(row: row);
                  if (value == 'delete') _delete(row);
                },
                itemBuilder: (_) => <PopupMenuEntry<String>>[
                  const PopupMenuItem<String>(
                    value: 'edit',
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.edit_outlined),
                      title: Text('Modifier'),
                    ),
                  ),
                  if (widget.definition.allowDelete)
                    const PopupMenuItem<String>(
                      value: 'delete',
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          Icons.delete_outline,
                          color: AppColors.danger,
                        ),
                        title: Text('Supprimer'),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rows = _filteredRows;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.definition.title),
        actions: <Widget>[
          IconButton(
            tooltip: 'Actualiser',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: widget.definition.allowCreate
          ? FloatingActionButton.extended(
              onPressed: _saving ? null : () => _openEditor(),
              icon: const Icon(Icons.add),
              label: const Text('Ajouter'),
            )
          : null,
      body: Column(
        children: <Widget>[
          Container(
            width: double.infinity,
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  widget.definition.subtitle,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _searchController,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText:
                        'Rechercher dans ${widget.definition.title.toLowerCase()}',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Effacer',
                            onPressed: () {
                              _searchController.clear();
                              setState(() {});
                            },
                            icon: const Icon(Icons.close),
                          ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? _ManagedError(message: _error!, onRetry: _load)
                : rows.isEmpty
                ? const _ManagedEmpty()
                : LayoutBuilder(
                    builder: (context, constraints) {
                      final columns = constraints.maxWidth >= 1180
                          ? 3
                          : constraints.maxWidth >= 720
                          ? 2
                          : 1;
                      return GridView.builder(
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 96),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: columns,
                          crossAxisSpacing: 14,
                          mainAxisSpacing: 14,
                          mainAxisExtent: 112,
                        ),
                        itemCount: rows.length,
                        itemBuilder: (_, index) => _rowCard(rows[index]),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _ManagedError extends StatelessWidget {
  const _ManagedError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Icon(
                    Icons.cloud_off_outlined,
                    size: 48,
                    color: AppColors.danger,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Chargement impossible',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(message, textAlign: TextAlign.center),
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Réessayer'),
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

class _ManagedEmpty extends StatelessWidget {
  const _ManagedEmpty();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.inbox_outlined, size: 52, color: AppColors.anthracite),
            SizedBox(height: 12),
            Text('Aucune donnée à afficher.'),
          ],
        ),
      ),
    );
  }
}

class _ManagedRowDialog extends StatefulWidget {
  const _ManagedRowDialog({
    required this.definition,
    required this.initialRow,
    required this.isNew,
  });

  final AdminCollectionDefinition definition;
  final Map<String, dynamic> initialRow;
  final bool isNew;

  @override
  State<_ManagedRowDialog> createState() => _ManagedRowDialogState();
}

class _ManagedRowDialogState extends State<_ManagedRowDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final Map<String, TextEditingController> _controllers =
      <String, TextEditingController>{};
  final Map<String, bool> _booleans = <String, bool>{};

  @override
  void initState() {
    super.initState();
    for (final field in widget.definition.fields) {
      final value = widget.initialRow[field.key];
      if (field.kind == AdminFieldKind.booleanValue) {
        _booleans[field.key] = value == true;
      } else {
        final text = value is List
            ? value.join(', ')
            : (value?.toString() ?? '');
        _controllers[field.key] = TextEditingController(text: text);
      }
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  bool _isReadOnly(AdminFieldDefinition field) {
    return field.readOnly || (field.immutableOnEdit && !widget.isNew);
  }

  Widget _buildField(AdminFieldDefinition field) {
    if (field.kind == AdminFieldKind.booleanValue) {
      return Card(
        margin: EdgeInsets.zero,
        child: SwitchListTile(
          value: _booleans[field.key] ?? false,
          onChanged: _isReadOnly(field)
              ? null
              : (value) => setState(() => _booleans[field.key] = value),
          title: Text(field.label),
          subtitle: field.helperText == null ? null : Text(field.helperText!),
        ),
      );
    }

    final controller = _controllers[field.key]!;
    if (field.kind == AdminFieldKind.choice) {
      final current = field.options.contains(controller.text)
          ? controller.text
          : null;
      return DropdownButtonFormField<String>(
        initialValue: current,
        decoration: InputDecoration(
          labelText: field.label,
          helperText: field.helperText,
        ),
        items: field.options
            .map(
              (option) =>
                  DropdownMenuItem<String>(value: option, child: Text(option)),
            )
            .toList(),
        onChanged: _isReadOnly(field)
            ? null
            : (value) => controller.text = value ?? '',
        validator: (value) {
          if (field.required && (value == null || value.trim().isEmpty)) {
            return 'Champ obligatoire';
          }
          return null;
        },
      );
    }

    return TextFormField(
      controller: controller,
      readOnly: _isReadOnly(field),
      minLines: field.kind == AdminFieldKind.longText ? 3 : 1,
      maxLines: field.kind == AdminFieldKind.longText ? 6 : 1,
      keyboardType: field.kind == AdminFieldKind.integer
          ? TextInputType.number
          : TextInputType.text,
      decoration: InputDecoration(
        labelText: field.label,
        helperText: field.helperText,
        suffixIcon: _isReadOnly(field)
            ? const Icon(Icons.lock_outline, size: 18)
            : null,
      ),
      validator: (value) {
        final text = value?.trim() ?? '';
        if (field.required && text.isEmpty) return 'Champ obligatoire';
        if (field.kind == AdminFieldKind.integer &&
            text.isNotEmpty &&
            int.tryParse(text) == null) {
          return 'Nombre entier attendu';
        }
        return null;
      },
    );
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final row = Map<String, dynamic>.from(widget.initialRow);

    for (final field in widget.definition.fields) {
      if (field.kind == AdminFieldKind.booleanValue) {
        row[field.key] = _booleans[field.key] ?? false;
        continue;
      }

      final text = _controllers[field.key]?.text.trim() ?? '';
      if (text.isEmpty) {
        if (widget.isNew && field.readOnly) {
          row.remove(field.key);
        } else {
          row[field.key] = null;
        }
        continue;
      }

      if (field.kind == AdminFieldKind.integer) {
        row[field.key] = int.parse(text);
      } else if (field.kind == AdminFieldKind.stringList) {
        row[field.key] = text
            .split(',')
            .map((value) => value.trim())
            .where((value) => value.isNotEmpty)
            .toList();
      } else {
        row[field.key] = text;
      }
    }

    Navigator.pop(context, row);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return Dialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: size.width < 680 ? 12 : 40,
        vertical: 24,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 680,
          maxHeight: size.height * 0.9,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 12, 12),
              child: Row(
                children: <Widget>[
                  Icon(widget.definition.icon, color: AppColors.orange),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.isNew ? 'Ajouter' : 'Modifier',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Fermer',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: widget.definition.fields
                        .map(
                          (field) => Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: _buildField(field),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: <Widget>[
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Annuler'),
                  ),
                  const SizedBox(width: 10),
                  FilledButton.icon(
                    onPressed: _submit,
                    icon: const Icon(Icons.save_outlined),
                    label: const Text('Enregistrer'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
