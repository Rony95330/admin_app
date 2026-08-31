import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/coordinator_message/coordinator_message_model.dart';
import '../../core/coordinator_message/coordinator_message_service.dart';
import '../../theme/brand_colors.dart';

class CoordinatorMessageEditPage extends StatefulWidget {
  const CoordinatorMessageEditPage({
    super.key,
    this.message,
    this.initialCse,
    this.service,
  });

  final CoordinatorMessage? message;
  final String? initialCse;
  final CoordinatorMessageService? service;

  @override
  State<CoordinatorMessageEditPage> createState() =>
      _CoordinatorMessageEditPageState();
}

class _CoordinatorMessageEditPageState
    extends State<CoordinatorMessageEditPage> {
  final _formKey = GlobalKey<FormState>();
  late final CoordinatorMessageService _service;
  late final TextEditingController _headlineController;
  late final TextEditingController _bodyController;
  late final TextEditingController _sortOrderController;

  List<String> _cseChoices = const <String>[];
  List<CoordinatorMemberChoice> _members = const <CoordinatorMemberChoice>[];
  String? _selectedCse;
  int? _selectedMemberId;
  DateTime? _publishedFrom;
  DateTime? _publishedUntil;
  bool _active = true;
  bool _loadingReferences = true;
  bool _loadingMembers = false;
  bool _saving = false;
  String? _referenceError;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? CoordinatorMessageService();
    final message = widget.message;
    _headlineController = TextEditingController(text: message?.headline ?? '');
    _bodyController = TextEditingController(text: message?.body ?? '');
    _sortOrderController = TextEditingController(
      text: '${message?.sortOrder ?? 100}',
    );
    final requestedCse = (message?.cse ?? widget.initialCse ?? '').trim();
    _selectedCse = requestedCse.isEmpty ? null : requestedCse;
    _selectedMemberId = message?.coordinatorMemberId;
    _publishedFrom = message?.publishedFrom ?? DateTime.now();
    _publishedUntil = message?.publishedUntil;
    _active = message?.isActive ?? true;
    unawaited(_loadReferences());
  }

  @override
  void dispose() {
    _headlineController.dispose();
    _bodyController.dispose();
    _sortOrderController.dispose();
    super.dispose();
  }

  Future<void> _loadReferences() async {
    try {
      final choices = await _service.fetchCseChoices();
      final current = _selectedCse;
      final mutable = List<String>.of(choices);
      if (current != null && current.isNotEmpty && !mutable.contains(current)) {
        mutable.add(current);
        mutable.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
      }
      if (!mounted) return;
      setState(() {
        _cseChoices = mutable;
        _selectedCse ??= mutable.isEmpty ? null : mutable.first;
        _referenceError = null;
      });
      await _loadMembers();
      if (!mounted) return;
      setState(() => _loadingReferences = false);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadingReferences = false;
        _referenceError = 'Chargement des sections impossible : $error';
      });
    }
  }

  Future<void> _loadMembers({bool clearSelection = false}) async {
    final cse = (_selectedCse ?? '').trim();
    if (cse.isEmpty) return;
    setState(() {
      _loadingMembers = true;
      if (clearSelection) _selectedMemberId = null;
    });
    try {
      final members = await _service.fetchMembers(cse);
      final existing = widget.message;
      final mutable = List<CoordinatorMemberChoice>.of(members);
      if (!clearSelection &&
          existing != null &&
          existing.coordinatorMemberId != null &&
          !mutable.any((member) => member.id == existing.coordinatorMemberId)) {
        mutable.add(
          CoordinatorMemberChoice(
            id: existing.coordinatorMemberId!,
            name: existing.coordinatorName,
            role: existing.coordinatorRole ?? '',
            cse: existing.cse,
            photoUrl: existing.coordinatorPhotoUrl ?? '',
          ),
        );
      }
      if (!mounted) return;
      setState(() {
        _members = mutable;
        if (!_members.any((member) => member.id == _selectedMemberId)) {
          _selectedMemberId = null;
        }
        _loadingMembers = false;
        _referenceError = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _members = const <CoordinatorMemberChoice>[];
        _selectedMemberId = null;
        _loadingMembers = false;
        _referenceError = 'Chargement des représentants impossible : $error';
      });
    }
  }

  CoordinatorMemberChoice? get _selectedMember {
    for (final member in _members) {
      if (member.id == _selectedMemberId) return member;
    }
    return null;
  }

  Future<void> _pickDate({required bool start}) async {
    final current = start ? _publishedFrom : _publishedUntil;
    final date = await showDatePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 730)),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
      initialDate: current ?? DateTime.now(),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current ?? DateTime.now()),
    );
    if (time == null || !mounted) return;
    final value = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    setState(() {
      if (start) {
        _publishedFrom = value;
      } else {
        _publishedUntil = value;
      }
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final cse = (_selectedCse ?? '').trim();
    final member = _selectedMember;
    if (cse.isEmpty || member == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Choisissez la section et son coordinateur.'),
        ),
      );
      return;
    }
    if (_publishedFrom != null &&
        _publishedUntil != null &&
        !_publishedUntil!.isAfter(_publishedFrom!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('La date de fin doit être postérieure au début.'),
        ),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final values = <String, dynamic>{
        'cse': cse,
        'coordinator_member_id': member.id,
        'coordinator_name': member.name,
        'coordinator_role': member.role.isEmpty ? null : member.role,
        'coordinator_photo_url': member.photoUrl.isEmpty
            ? null
            : member.photoUrl,
        'headline': _headlineController.text.trim().isEmpty
            ? null
            : _headlineController.text.trim(),
        'body': _bodyController.text.trim(),
        'published_from': _publishedFrom?.toUtc().toIso8601String(),
        'published_until': _publishedUntil?.toUtc().toIso8601String(),
        'is_active': _active,
        'sort_order': int.tryParse(_sortOrderController.text) ?? 100,
      };

      if (widget.message == null) {
        await _service.create(values);
      } else {
        await _service.update(widget.message!.id, values);
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Enregistrement impossible : $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.message == null
              ? 'Nouveau mot du coordinateur'
              : 'Modifier le mot du coordinateur',
        ),
      ),
      body: _loadingReferences
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: Scrollbar(
                thumbVisibility: MediaQuery.sizeOf(context).width >= 600,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
                  children: [
                    const ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundColor: AppColors.orange,
                        foregroundColor: Colors.white,
                        child: Icon(Icons.format_quote_rounded),
                      ),
                      title: Text(
                        'Le mot du coordinateur',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      subtitle: Text(
                        'La carte sera affichée sur l’accueil de la section sélectionnée.',
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedCse,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Section / CSE *',
                        prefixIcon: Icon(Icons.apartment_rounded),
                      ),
                      items: _cseChoices
                          .map(
                            (cse) => DropdownMenuItem<String>(
                              value: cse,
                              child: Text(
                                cse,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(growable: false),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? 'Section obligatoire'
                          : null,
                      onChanged: _saving
                          ? null
                          : (value) {
                              setState(() => _selectedCse = value);
                              unawaited(_loadMembers(clearSelection: true));
                            },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int>(
                      key: ValueKey<String>(
                        'coordinator-${_selectedCse ?? ''}',
                      ),
                      initialValue: _selectedMemberId,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: 'Coordinateur *',
                        prefixIcon: _loadingMembers
                            ? const Padding(
                                padding: EdgeInsets.all(13),
                                child: SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              )
                            : const Icon(Icons.person_rounded),
                      ),
                      items: _members
                          .map(
                            (member) => DropdownMenuItem<int>(
                              value: member.id,
                              child: Text(
                                member.role.isEmpty
                                    ? member.name
                                    : '${member.name} — ${member.role}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(growable: false),
                      validator: (value) =>
                          value == null ? 'Coordinateur obligatoire' : null,
                      onChanged: _saving || _loadingMembers
                          ? null
                          : (value) =>
                                setState(() => _selectedMemberId = value),
                    ),
                    if (_selectedMember != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        _selectedMember!.photoUrl.isEmpty
                            ? 'Ce représentant ne possède pas encore de photo.'
                            : 'La photo du trombinoscope sera utilisée automatiquement.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                    if (_referenceError != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        _referenceError!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                    const SizedBox(height: 18),
                    TextFormField(
                      controller: _headlineController,
                      decoration: const InputDecoration(
                        labelText: 'Accroche (facultative)',
                        hintText: 'Ex. Ensemble, préparons les prochains mois',
                        prefixIcon: Icon(Icons.title_rounded),
                      ),
                      maxLength: 180,
                      textCapitalization: TextCapitalization.sentences,
                    ),
                    TextFormField(
                      controller: _bodyController,
                      decoration: const InputDecoration(
                        labelText: 'Message *',
                        hintText: 'Rédigez ici le message du coordinateur…',
                        alignLabelWithHint: true,
                        prefixIcon: Padding(
                          padding: EdgeInsets.only(bottom: 150),
                          child: Icon(Icons.edit_note_rounded),
                        ),
                      ),
                      minLines: 10,
                      maxLines: 18,
                      maxLength: 10000,
                      textCapitalization: TextCapitalization.sentences,
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? 'Le message est obligatoire'
                          : null,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Période d’affichage',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _DateRow(
                      label: _publishedFrom == null
                          ? 'Publication immédiate'
                          : 'Début : ${_formatDate(_publishedFrom!)}',
                      icon: Icons.play_arrow_rounded,
                      onPick: () => _pickDate(start: true),
                      onClear: _publishedFrom == null
                          ? null
                          : () => setState(() => _publishedFrom = null),
                    ),
                    const SizedBox(height: 8),
                    _DateRow(
                      label: _publishedUntil == null
                          ? 'Pas de date de fin'
                          : 'Fin : ${_formatDate(_publishedUntil!)}',
                      icon: Icons.stop_rounded,
                      onPick: () => _pickDate(start: false),
                      onClear: _publishedUntil == null
                          ? null
                          : () => setState(() => _publishedUntil = null),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _sortOrderController,
                      decoration: const InputDecoration(
                        labelText: 'Priorité',
                        helperText:
                            'La valeur la plus faible est affichée en premier.',
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Publier sur l’accueil'),
                      subtitle: const Text(
                        'L’activation remplace automatiquement l’ancien message actif de cette section.',
                      ),
                      value: _active,
                      onChanged: _saving
                          ? null
                          : (value) => setState(() => _active = value),
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
            ),
    );
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$day/$month/${date.year} à $hour:$minute';
  }
}

class _DateRow extends StatelessWidget {
  const _DateRow({
    required this.label,
    required this.icon,
    required this.onPick,
    required this.onClear,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPick;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: onPick,
            icon: Icon(icon),
            label: Text(label, overflow: TextOverflow.ellipsis),
          ),
        ),
        if (onClear != null) ...[
          const SizedBox(width: 6),
          IconButton(
            tooltip: 'Effacer la date',
            onPressed: onClear,
            icon: const Icon(Icons.clear_rounded),
          ),
        ],
      ],
    );
  }
}
