// lib/questionnaire_service.dart
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'questionnaire.dart';

class QuestionnaireService {
  final SupabaseClient _client = Supabase.instance.client;

  String? _formatDate(DateTime? dt) {
    if (dt == null) return null;
    // Colonne SQL = date → format YYYY-MM-DD
    return DateFormat('yyyy-MM-dd').format(dt);
  }

  Future<Questionnaire> createQuestionnaire(Questionnaire questionnaire) async {
    final data = {
      'title': questionnaire.title,
      'description': questionnaire.description,
      'start_date': _formatDate(questionnaire.startDate),
      'end_date': _formatDate(questionnaire.endDate),

      // tableaux texte[] optionnels
      'population_raw': questionnaire.populationRaw.isEmpty
          ? null
          : questionnaire.populationRaw,
      'cse_targets': questionnaire.cseTargets.isEmpty
          ? null
          : questionnaire.cseTargets,
      'level_targets': questionnaire.levelTargets.isEmpty
          ? null
          : questionnaire.levelTargets,
      'metier_targets': questionnaire.metierTargets.isEmpty
          ? null
          : questionnaire.metierTargets,

      // JSONB des questions
      'questions': questionnaire.questions.map((q) => q.toJson()).toList(),
    };

    final inserted = await _client
        .from('questionnaires')
        .insert(data)
        .select()
        .single(); // plus de cast ici

    return Questionnaire.fromMap(inserted);
  }

  Future<List<Questionnaire>> fetchAll() async {
    final List<dynamic> rows = await _client
        .from('questionnaires')
        .select()
        .order('created_at', ascending: false);

    return rows
        .map((e) => Questionnaire.fromMap(e as Map<String, dynamic>))
        .toList();
  }
}
