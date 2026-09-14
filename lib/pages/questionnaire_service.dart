import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'questionnaire.dart';

class QuestionnaireService {
  final SupabaseClient _client = Supabase.instance.client;

  String? _formatDate(DateTime? dt) {
    if (dt == null) return null;
    return DateFormat('yyyy-MM-dd').format(dt);
  }

  Map<String, dynamic> _toPayload(Questionnaire questionnaire) {
    return {
      'title': questionnaire.title,
      'description': questionnaire.description,
      'start_date': _formatDate(questionnaire.startDate),
      'end_date': _formatDate(questionnaire.endDate),
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
      'questions': questionnaire.questions.map((q) => q.toJson()).toList(),
    };
  }

  Future<Questionnaire> createQuestionnaire(Questionnaire questionnaire) async {
    final inserted = await _client
        .from('questionnaires')
        .insert(_toPayload(questionnaire))
        .select()
        .single();

    return Questionnaire.fromMap(inserted);
  }

  Future<Questionnaire> updateQuestionnaire(Questionnaire questionnaire) async {
    final id = questionnaire.id;

    if (id == null) {
      throw StateError('Questionnaire sans identifiant.');
    }

    final updated = await _client
        .from('questionnaires')
        .update(_toPayload(questionnaire))
        .eq('id', id)
        .select()
        .single();

    return Questionnaire.fromMap(updated);
  }

  Future<void> setArchived(int questionnaireId, bool archived) async {
    await _client
        .from('questionnaires')
        .update({'is_archived': archived})
        .eq('id', questionnaireId);
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

  Future<Map<int, int>> fetchAdminCounts() async {
    final dynamic raw = await _client.rpc('questionnaire_admin_counts');

    final result = <int, int>{};

    if (raw is List) {
      for (final row in raw) {
        if (row is! Map) continue;

        final id = int.tryParse(row['questionnaire_id'].toString());
        final count = int.tryParse(row['response_count'].toString()) ?? 0;

        if (id != null) {
          result[id] = count;
        }
      }
    }

    return result;
  }

  Future<List<Map<String, dynamic>>> fetchAdminResults(
    int questionnaireId,
  ) async {
    final dynamic raw = await _client.rpc(
      'questionnaire_admin_results',
      params: {'p_questionnaire_id': questionnaireId},
    );

    if (raw is! List) return const [];

    return raw
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
  }
}
