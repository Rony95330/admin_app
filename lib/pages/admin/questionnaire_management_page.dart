import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../questionnaire.dart';
import '../questionnaire_service.dart';
import 'questionnaire_editor_page.dart';
import 'questionnaire_results_page.dart';

class QuestionnaireManagementPage extends StatefulWidget {
  const QuestionnaireManagementPage({super.key});

  @override
  State<QuestionnaireManagementPage> createState() =>
      _QuestionnaireManagementPageState();
}

class _QuestionnaireManagementPageState
    extends State<QuestionnaireManagementPage> {
  final QuestionnaireService _service = QuestionnaireService();

  bool _loading = true;
  String? _error;

  List<Questionnaire> _questionnaires = [];
  Map<int, int> _responseCounts = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final questionnaires = await _service.fetchAll();
      final counts = await _service.fetchAdminCounts();

      if (!mounted) return;

      setState(() {
        _questionnaires = questionnaires;
        _responseCounts = counts;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = 'Impossible de charger les questionnaires : $e';
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _createQuestionnaire() async {
    final created = await Navigator.of(context).push<Questionnaire>(
      MaterialPageRoute(builder: (_) => const QuestionnaireEditorPage()),
    );

    if (created != null && mounted) {
      await _load();
    }
  }

  Future<void> _editQuestionnaire(Questionnaire questionnaire) async {
    final updated = await Navigator.of(context).push<Questionnaire>(
      MaterialPageRoute(
        builder: (_) => QuestionnaireEditorPage(initial: questionnaire),
      ),
    );

    if (updated != null && mounted) {
      await _load();
    }
  }

  Future<void> _showResults(Questionnaire questionnaire) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => QuestionnaireResultsPage(questionnaire: questionnaire),
      ),
    );

    if (mounted) {
      await _load();
    }
  }

  Future<void> _toggleArchive(Questionnaire questionnaire) async {
    final id = questionnaire.id;
    if (id == null) return;

    final willArchive = !questionnaire.isArchived;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(
            willArchive
                ? 'Archiver le questionnaire ?'
                : 'Désarchiver le questionnaire ?',
          ),
          content: Text(
            willArchive
                ? 'Le questionnaire "${questionnaire.title}" '
                      'ne sera plus proposé aux utilisateurs.'
                : 'Le questionnaire "${questionnaire.title}" '
                      'sera de nouveau disponible si sa période de validité '
                      'le permet.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(willArchive ? 'Archiver' : 'Désarchiver'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      await _service.setArchived(id, willArchive);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            willArchive
                ? 'Questionnaire archivé.'
                : 'Questionnaire désarchivé.',
          ),
        ),
      );

      await _load();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Impossible de modifier l’archivage : $e')),
      );
    }
  }

  DateTime _dateOnly(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }

  _QuestionnaireStatus _statusOf(Questionnaire q) {
    if (q.isArchived) {
      return _QuestionnaireStatus.archived;
    }

    final today = _dateOnly(DateTime.now());

    final start = q.startDate == null ? null : _dateOnly(q.startDate!);

    final end = q.endDate == null ? null : _dateOnly(q.endDate!);

    if (start != null && start.isAfter(today)) {
      return _QuestionnaireStatus.upcoming;
    }

    if (end != null && end.isBefore(today)) {
      return _QuestionnaireStatus.finished;
    }

    return _QuestionnaireStatus.active;
  }

  String _statusLabel(_QuestionnaireStatus status) {
    switch (status) {
      case _QuestionnaireStatus.active:
        return 'En cours';
      case _QuestionnaireStatus.upcoming:
        return 'À venir';
      case _QuestionnaireStatus.finished:
        return 'Terminé';
      case _QuestionnaireStatus.archived:
        return 'Archivé';
    }
  }

  IconData _statusIcon(_QuestionnaireStatus status) {
    switch (status) {
      case _QuestionnaireStatus.active:
        return Icons.play_circle_outline_rounded;
      case _QuestionnaireStatus.upcoming:
        return Icons.schedule_rounded;
      case _QuestionnaireStatus.finished:
        return Icons.check_circle_outline_rounded;
      case _QuestionnaireStatus.archived:
        return Icons.archive_outlined;
    }
  }

  String _formatDate(DateTime? value) {
    if (value == null) return 'Non définie';

    return DateFormat('dd/MM/yyyy').format(value);
  }

  String _formatTargets(List<String> values) {
    if (values.isEmpty || values.contains('ALL')) {
      return 'Tous';
    }

    return values.join(', ');
  }

  int _countFor(Questionnaire questionnaire) {
    final id = questionnaire.id;
    if (id == null) return 0;

    return _responseCounts[id] ?? 0;
  }

  Widget _infoLine({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 8),
          SizedBox(
            width: 105,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Widget _buildCard(Questionnaire q) {
    final status = _statusOf(q);
    final responseCount = _countFor(q);

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.poll_outlined, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        q.title,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      if (q.description != null &&
                          q.description!.trim().isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(q.description!.trim()),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Chip(
                  avatar: Icon(_statusIcon(status), size: 18),
                  label: Text(_statusLabel(status)),
                ),
              ],
            ),
            const Divider(height: 28),
            _infoLine(
              icon: Icons.calendar_today_outlined,
              label: 'Début',
              value: _formatDate(q.startDate),
            ),
            _infoLine(
              icon: Icons.event_available_outlined,
              label: 'Fin',
              value: _formatDate(q.endDate),
            ),
            _infoLine(
              icon: Icons.quiz_outlined,
              label: 'Questions',
              value: '${q.questions.length}',
            ),
            _infoLine(
              icon: Icons.people_alt_outlined,
              label: 'Répondants',
              value: '$responseCount',
            ),
            _infoLine(
              icon: Icons.groups_outlined,
              label: 'Population',
              value: _formatTargets(q.populationRaw),
            ),
            _infoLine(
              icon: Icons.business_outlined,
              label: 'CSE',
              value: _formatTargets(q.cseTargets),
            ),
            _infoLine(
              icon: Icons.badge_outlined,
              label: 'Niveau',
              value: _formatTargets(q.levelTargets),
            ),
            if (q.metierTargets.isNotEmpty)
              _infoLine(
                icon: Icons.work_outline_rounded,
                label: 'Métier',
                value: _formatTargets(q.metierTargets),
              ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: q.id == null ? null : () => _showResults(q),
                  icon: const Icon(Icons.bar_chart_rounded),
                  label: Text('Résultats ($responseCount)'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _editQuestionnaire(q),
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Modifier'),
                ),
                OutlinedButton.icon(
                  onPressed: q.id == null ? null : () => _toggleArchive(q),
                  icon: Icon(
                    q.isArchived
                        ? Icons.unarchive_outlined
                        : Icons.archive_outlined,
                  ),
                  label: Text(q.isArchived ? 'Désarchiver' : 'Archiver'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _content() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 80),
          Icon(
            Icons.error_outline_rounded,
            size: 52,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(height: 16),
          Text(_error!, textAlign: TextAlign.center),
          const SizedBox(height: 20),
          Center(
            child: FilledButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Réessayer'),
            ),
          ),
        ],
      );
    }

    if (_questionnaires.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: const [
          SizedBox(height: 80),
          Icon(Icons.poll_outlined, size: 60),
          SizedBox(height: 16),
          Text('Aucun questionnaire créé.', textAlign: TextAlign.center),
        ],
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      itemCount: _questionnaires.length,
      itemBuilder: (context, index) {
        return _buildCard(_questionnaires[index]);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Questionnaires'),
        actions: [
          IconButton(
            tooltip: 'Actualiser',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createQuestionnaire,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Créer un questionnaire'),
      ),
      body: RefreshIndicator(onRefresh: _load, child: _content()),
    );
  }
}

enum _QuestionnaireStatus { active, upcoming, finished, archived }
