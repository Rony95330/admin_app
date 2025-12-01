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

  /// Liste des CSE (issue de liste_cse_rows.csv)
  final List<String> _allCseCodes = const [
    'CSE EXPLOITATION COURT COURRIER',
    "CSE SYSTEMES D'INFORMATION",
    'CSE INDUSTRIEL',
    'CSE EXPLOITATION HUB',
    'CSE PILOTAGE ECONOMIQUE',
    'CSE AIR FRANCE CARGO',
    'CSE EXPLOITATION AERIENNE',
  ];

  /// CSE sélectionnés (vide = tous)
  final List<String> _selectedCse = [];

  /// Niveaux
  final List<String> _categories = const [
    'Cadres',
    'Employés',
    'Managers',
    'Techniciens',
  ];
  final List<String> _selectedCategories = [];

  /// Population visée : codes => libellés
  final Map<String, String> _publics = const {
    'ALL': 'Tous',
    'MILITANTS': 'Militants',
    'ADHERENTS': 'Adhérents',
    'ENROLES': 'Enrolés',
  };

  /// Codes sélectionnés (vide = ALL implicite)
  final List<String> _selectedPublics = [];

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

  Future<void> _pickDate({required bool isStart}) async {
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
          options: const [],
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

    // Vérif rapide : les questions à choix doivent avoir des options
    for (final q in _questions) {
      if ((q.type == QuestionType.singleChoice ||
              q.type == QuestionType.multipleChoice) &&
          q.options.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'La question "${q.label.isEmpty ? 'sans titre' : q.label}" est à choix mais sans options.',
            ),
          ),
        );
        return;
      }
    }

    // Gestion "Tous" pour la population :
    List<String> publicsCodes = List<String>.from(_selectedPublics);
    if (publicsCodes.isEmpty) {
      publicsCodes = ['ALL'];
    } else if (publicsCodes.contains('ALL')) {
      publicsCodes = ['ALL'];
    }

    setState(() {
      _saving = true;
    });

    try {
      final questionnaire = Questionnaire(
        title: _titreController.text.trim(),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        cseTargets: List<String>.from(_selectedCse),
        populationRaw: publicsCodes,
        levelTargets: List<String>.from(_selectedCategories),
        metierTargets: const [],
        startDate: _dateDebut,
        endDate: _dateFin,
        questions: List<QuestionnaireQuestion>.from(_questions),
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
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Créer un questionnaire')),
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
                    style: theme.textTheme.titleLarge,
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

                  // CSE ciblés
                  Text('CSE ciblés', style: theme.textTheme.titleMedium),
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
                  const SizedBox(height: 4),
                  Text(
                    'Si aucun CSE n’est sélectionné, le questionnaire sera envoyé à tous.',
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 16),

                  // Population visée
                  Text('Population visée', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: _publics.entries.map((entry) {
                      final code = entry.key;
                      final label = entry.value;
                      final selected = _selectedPublics.contains(code);
                      return FilterChip(
                        label: Text(label),
                        selected: selected,
                        onSelected: (value) {
                          setState(() {
                            if (code == 'ALL') {
                              if (value) {
                                _selectedPublics
                                  ..clear()
                                  ..add('ALL');
                              } else {
                                _selectedPublics.remove('ALL');
                              }
                            } else {
                              if (value) {
                                _selectedPublics.add(code);
                                _selectedPublics.remove('ALL');
                              } else {
                                _selectedPublics.remove(code);
                              }
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Si rien n’est sélectionné ou si "Tous" est coché, le questionnaire sera envoyé à tous.',
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 16),

                  // Niveaux
                  Text(
                    'Niveaux ciblés (optionnel)',
                    style: theme.textTheme.titleMedium,
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
                  const SizedBox(height: 4),
                  Text(
                    'Si aucun niveau n’est sélectionné, le questionnaire sera envoyé à tous les niveaux.',
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 16),

                  // Période de validité
                  Text(
                    'Période de validité (optionnel)',
                    style: theme.textTheme.titleMedium,
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
                      Text('Questions', style: theme.textTheme.titleLarge),
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
                                  style: theme.textTheme.titleMedium,
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
                                if (value == null || value.trim().isEmpty) {
                                  return 'Cette question doit avoir un intitulé.';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 8),
                            DropdownButtonFormField<QuestionType>(
                              value: q.type,
                              decoration: const InputDecoration(
                                labelText: 'Type de question',
                                border: OutlineInputBorder(),
                              ),
                              items: const [
                                DropdownMenuItem<QuestionType>(
                                  value: QuestionType.text,
                                  child: Text('Texte libre'),
                                ),
                                DropdownMenuItem<QuestionType>(
                                  value: QuestionType.yesNo,
                                  child: Text('Oui / Non'),
                                ),
                                DropdownMenuItem<QuestionType>(
                                  value: QuestionType.singleChoice,
                                  child: Text('Choix unique'),
                                ),
                                DropdownMenuItem<QuestionType>(
                                  value: QuestionType.multipleChoice,
                                  child: Text('Choix multiple'),
                                ),
                                DropdownMenuItem<QuestionType>(
                                  value: QuestionType.likert1to5,
                                  child: Text('Échelle 1 à 5'),
                                ),
                              ],
                              onChanged: (value) {
                                if (value == null) return;
                                setState(() {
                                  q.type = value;
                                  // Pour les types sans options libres, on vide la liste
                                  if (q.type == QuestionType.text ||
                                      q.type == QuestionType.yesNo ||
                                      q.type == QuestionType.likert1to5) {
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
                                  hintText: 'Ex : Oui, Non, Peut-être',
                                  border: OutlineInputBorder(),
                                ),
                                onChanged: (value) {
                                  q.options = value
                                      .split(',')
                                      .map((s) => s.trim())
                                      .where((s) => s.isNotEmpty)
                                      .toList();
                                },
                              )
                            else if (q.type == QuestionType.yesNo)
                              const Text(
                                'Réponses possibles : Oui / Non (fixes)',
                                style: TextStyle(fontStyle: FontStyle.italic),
                              )
                            else if (q.type == QuestionType.likert1to5)
                              const Text(
                                'Échelle de 1 (faible) à 5 (fort).',
                                style: TextStyle(fontStyle: FontStyle.italic),
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
                  }),

                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _saving ? null : _save,
                      icon: const Icon(Icons.save),
                      label: Text(
                        _saving
                            ? 'Enregistrement...'
                            : 'Enregistrer le questionnaire',
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
            if (_saving) const LinearProgressIndicator(minHeight: 2),
          ],
        ),
      ),
    );
  }
}
