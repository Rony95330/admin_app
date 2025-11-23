// lib/pages/admin/questionnaire_editor_page.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../questionnaire.dart';
import '../questionnaire_service.dart';

class QuestionnaireEditorPage extends StatefulWidget {
  const QuestionnaireEditorPage({super.key});

  @override
  State<QuestionnaireEditorPage> createState() =>
      _QuestionnaireEditorPageState();
}

class _QuestionnaireEditorPageState extends State<QuestionnaireEditorPage> {
  final _formKey = GlobalKey<FormState>();
  final _service = QuestionnaireService();

  final _titreController = TextEditingController();
  final _descriptionController = TextEditingController();

  // TODO: adapter à tes vrais CSE
  final List<String> _allCseCodes = [
    'HUB',
    'COURT_COURRIER',
    'CENTRAL',
    'CSE1',
    'CSE2',
  ];

  final List<String> _selectedCse = [];
  final List<String> _categories = ['technicien', 'cadre', 'ouvrier'];
  final List<String> _selectedCategories = [];

  final List<String> _publics = [
    'ALL',
    'militants',
    'adherents',
    'sympathisants'
  ];
  String _selectedPublic = 'ALL';

  DateTime? _dateDebut;
  DateTime? _dateFin;

  final List<QuestionnaireQuestion> _questions = [];
  bool _saving = false;

  @override
  void dispose() {
    _titreController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickDate({
    required bool isStart,
  }) async {
    final now = DateTime.now();
    final initial = isStart ? (_dateDebut ?? now) : (_dateFin ?? now);

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
      locale: const Locale('fr', 'FR'),
    );

    if (picked != null) {
      setState(() {
        if (isStart) {
          _dateDebut = picked;
        } else {
          _dateFin = picked;
        }
      });
    }
  }

  void _addQuestion() {
    setState(() {
      _questions.add(
        QuestionnaireQuestion(
          id: const Uuid().v4(),
          label: '',
          type: QuestionType.text,
          options: [],
          required: true,
        ),
      );
    });
  }

  void _removeQuestion(QuestionnaireQuestion q) {
    setState(() {
      _questions.removeWhere((element) => element.id == q.id);
    });
  }

  Future<void> _save() async {
    if (_questions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ajoute au moins une question.')),
      );
      return;
    }

    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedCse.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sélectionne au moins un CSE.')),
      );
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      final questionnaire = Questionnaire(
        titre: _titreController.text.trim(),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        cseTarget: List<String>.from(_selectedCse),
        publicCible: _selectedPublic,
        categories: List<String>.from(_selectedCategories),
        questions: List<QuestionnaireQuestion>.from(_questions),
        dateDebut: _dateDebut,
        dateFin: _dateFin,
      );

      final created = await _service.createQuestionnaire(questionnaire);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Questionnaire créé (id ${created.id})')),
      );

      Navigator.of(context).pop(created);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors de la sauvegarde : $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Non défini';
    return DateFormat('dd/MM/yyyy').format(date);
  }

  @override
  Widget build(BuildContext context) {
    // Tu peux adapter les couleurs à ta charte (Marine, Vert, Rose, etc.)
    return Scaffold(
      appBar: AppBar(
        title: const Text('Créer un questionnaire'),
      ),
      body: AbsorbPointer(
        absorbing: _saving,
        child: Stack(
          children: [
            Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16.0),
                children: [
                  Text(
                    'Informations générales',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _titreController,
                    decoration: const InputDecoration(
                      labelText: 'Titre *',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Le titre est obligatoire.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _descriptionController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // CSE
                  Text(
                    'CSE ciblés *',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: _allCseCodes.map((cse) {
                      final selected = _selectedCse.contains(cse);
                      return FilterChip(
                        label: Text(cse),
                        selected: selected,
                        onSelected: (value) {
                          setState(() {
                            if (value) {
                              _selectedCse.add(cse);
                            } else {
                              _selectedCse.remove(cse);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),

                  // Public cible
                  Text(
                    'Public cible',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedPublic,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                    ),
                    items: _publics
                        .map(
                          (p) => DropdownMenuItem(
                            value: p,
                            child: Text(p),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() {
                        _selectedPublic = value;
                      });
                    },
                  ),
                  const SizedBox(height: 16),

                  // Catégories
                  Text(
                    'Catégories (optionnel)',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: _categories.map((cat) {
                      final selected = _selectedCategories.contains(cat);
                      return FilterChip(
                        label: Text(cat),
                        selected: selected,
                        onSelected: (value) {
                          setState(() {
                            if (value) {
                              _selectedCategories.add(cat);
                            } else {
                              _selectedCategories.remove(cat);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),

                  // Dates
                  Text(
                    'Période de validité (optionnel)',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Date début'),
                          subtitle: Text(_formatDate(_dateDebut)),
                          onTap: () => _pickDate(isStart: true),
                        ),
                      ),
                      Expanded(
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Date fin'),
                          subtitle: Text(_formatDate(_dateFin)),
                          onTap: () => _pickDate(isStart: false),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 32),

                  // Questions
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Questions',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      FilledButton.icon(
                        onPressed: _addQuestion,
                        icon: const Icon(Icons.add),
                        label: const Text('Ajouter une question'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (_questions.isEmpty)
                    const Text(
                      'Aucune question pour le moment.',
                      style: TextStyle(fontStyle: FontStyle.italic),
                    ),
                  const SizedBox(height: 8),
                  ..._questions.map((q) {
                    final index = _questions.indexOf(q) + 1;
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  'Question $index',
                                  style:
                                      Theme.of(context).textTheme.titleMedium,
                                ),
                                const Spacer(),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline),
                                  onPressed: () => _removeQuestion(q),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              initialValue: q.label,
                              decoration: const InputDecoration(
                                labelText: 'Intitulé de la question *',
                                border: OutlineInputBorder(),
                              ),
                              onChanged: (value) {
                                q.label = value;
                              },
                              validator: (value) {
                                if (value == null ||
                                    value.trim().isEmpty ||
                                    _questions
                                        .where((element) => element == q)
                                        .isEmpty) {
                                  // juste pour éviter de casser la validation globale
                                  return null;
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 8),
                            DropdownButtonFormField<QuestionType>(
                              initialValue: q.type,
                              decoration: const InputDecoration(
                                labelText: 'Type de question',
                                border: OutlineInputBorder(),
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: QuestionType.text,
                                  child: Text('Texte libre'),
                                ),
                                DropdownMenuItem(
                                  value: QuestionType.singleChoice,
                                  child: Text('Choix unique'),
                                ),
                                DropdownMenuItem(
                                  value: QuestionType.multipleChoice,
                                  child: Text('Choix multiple'),
                                ),
                              ],
                              onChanged: (value) {
                                if (value == null) return;
                                setState(() {
                                  q.type = value;
                                  if (q.type == QuestionType.text) {
                                    q.options = [];
                                  }
                                });
                              },
                            ),
                            const SizedBox(height: 8),
                            if (q.type == QuestionType.singleChoice ||
                                q.type == QuestionType.multipleChoice)
                              TextFormField(
                              initialValue: q.options.join(', '),
                              decoration: const InputDecoration(
                                labelText:
                                    'Options (séparées par des virgules)',
                                border: OutlineInputBorder(),
                              ),
                              onChanged: (value) {
                                q.options = value
                                    .split(',')
                                    .map((s) => s.trim())
                                    .where((s) => s.isNotEmpty)
                                    .toList();
                              },
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Text('Réponse obligatoire'),
                                const SizedBox(width: 8),
                                Switch(
                                  value: q.required,
                                  onChanged: (value) {
                                    setState(() {
                                      q.required = value;
                                    });
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),

                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _saving ? null : _save,
                      icon: const Icon(Icons.save),
                      label: Text(_saving
                          ? 'Enregistrement...'
                          : 'Enregistrer le questionnaire'),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
            if (_saving)
              const LinearProgressIndicator(
                minHeight: 2,
              ),
          ],
        ),
      ),
    );
  }
}
