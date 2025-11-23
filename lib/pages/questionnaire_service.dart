// lib/services/questionnaire_service.dart
import 'package:supabase_flutter/supabase_flutter.dart';

import 'questionnaire.dart';

class QuestionnaireService {
  final SupabaseClient _client;

  QuestionnaireService({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  Future<Questionnaire> createQuestionnaire(Questionnaire questionnaire) async {
    final data = questionnaire.toInsertMap();

    final response = await _client
        .from('questionnaires')
        .insert(data)
        .select()
        .single();

    return Questionnaire.fromMap(
      response is Map<String, dynamic>
          ? response
          : Map<String, dynamic>.from(response as Map),
    );
  }

  Future<List<Questionnaire>> listQuestionnaires() async {
    final rows = await _client
        .from('questionnaires')
        .select()
        .order('id', ascending: false);

    return (rows as List<dynamic>)
        .map(
          (row) => Questionnaire.fromMap(
            row is Map<String, dynamic>
                ? row
                : Map<String, dynamic>.from(row as Map),
          ),
        )
        .toList();
  }

  Future<void> deleteQuestionnaire(int id) async {
    await _client.from('questionnaires').delete().eq('id', id);
  }
}
