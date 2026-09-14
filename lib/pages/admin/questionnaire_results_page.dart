import 'package:flutter/material.dart';

import '../questionnaire.dart';
import '../questionnaire_service.dart';

class QuestionnaireResultsPage extends StatefulWidget {
  final Questionnaire questionnaire;

  const QuestionnaireResultsPage({super.key, required this.questionnaire});

  @override
  State<QuestionnaireResultsPage> createState() =>
      _QuestionnaireResultsPageState();
}

class _QuestionnaireResultsPageState extends State<QuestionnaireResultsPage> {
  final QuestionnaireService _service = QuestionnaireService();

  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _responses = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final id = widget.questionnaire.id;
    if (id == null) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final rows = await _service.fetchAdminResults(id);

      if (!mounted) return;

      setState(() {
        _responses = rows;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = 'Impossible de charger les résultats : $e';
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  dynamic _value(dynamic raw) {
    if (raw is Map && raw.containsKey('value')) {
      return raw['value'];
    }

    return raw;
  }

  List<dynamic> _answersFor(QuestionnaireQuestion question) {
    final values = <dynamic>[];

    for (final response in _responses) {
      final answer = response['answer'];

      if (answer is! Map) continue;

      final raw = answer[question.id];
      if (raw == null) continue;

      values.add(_value(raw));
    }

    return values;
  }

  String _displayValue(dynamic value) {
    if (value == 'yes') return 'Oui';
    if (value == 'no') return 'Non';

    return value.toString();
  }

  Widget _buildClosedResults(
    QuestionnaireQuestion question,
    List<dynamic> answers,
  ) {
    final counts = <String, int>{};

    for (final value in answers) {
      if (value is List) {
        for (final item in value) {
          final label = _displayValue(item);
          counts[label] = (counts[label] ?? 0) + 1;
        }
      } else {
        final label = _displayValue(value);
        counts[label] = (counts[label] ?? 0) + 1;
      }
    }

    final entries = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    if (entries.isEmpty) {
      return const Text('Aucune réponse.');
    }

    final respondentCount = answers.length;

    return Column(
      children: entries.map((entry) {
        final ratio = respondentCount == 0
            ? 0.0
            : entry.value / respondentCount;

        return Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(child: Text(entry.key)),
                  Text(
                    '${entry.value} '
                    '(${(ratio * 100).toStringAsFixed(1)} %)',
                  ),
                ],
              ),
              const SizedBox(height: 5),
              LinearProgressIndicator(value: ratio.clamp(0.0, 1.0)),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTextResults(List<dynamic> answers) {
    if (answers.isEmpty) {
      return const Text('Aucune réponse.');
    }

    return Column(
      children: answers.map((answer) {
        return Container(
          width: double.infinity,
          margin: const EdgeInsets.only(top: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(color: Theme.of(context).dividerColor),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(_displayValue(answer)),
        );
      }).toList(),
    );
  }

  Widget _buildQuestionCard(QuestionnaireQuestion question, int index) {
    final answers = _answersFor(question);
    final missing = _responses.length - answers.length;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Question ${index + 1}',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 4),
            Text(
              question.label,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              '${answers.length} réponse(s)'
              '${missing > 0 ? ' • $missing sans réponse' : ''}',
            ),
            const Divider(height: 24),
            if (question.type == QuestionType.text)
              _buildTextResults(answers)
            else
              _buildClosedResults(question, answers),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Résultats du questionnaire'),
        actions: [
          IconButton(
            tooltip: 'Actualiser',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text(_error!))
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    widget.questionnaire.title,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${_responses.length} répondant(s)',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 20),
                  if (_responses.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(
                          child: Text('Aucune réponse enregistrée.'),
                        ),
                      ),
                    )
                  else
                    ...widget.questionnaire.questions.asMap().entries.map(
                      (entry) => _buildQuestionCard(entry.value, entry.key),
                    ),
                ],
              ),
            ),
    );
  }
}
