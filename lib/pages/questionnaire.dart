// lib/questionnaire.dart
import 'dart:convert';

/// Types de questions possibles
enum QuestionType {
  text, // question ouverte (texte libre)
  yesNo, // Oui / Non
  singleChoice, // Choix unique (radio)
  multipleChoice, // Choix multiples (checkbox)
  likert1to5, // Échelle 1 à 5
}

QuestionType questionTypeFromString(String value) {
  switch (value) {
    case 'single_choice':
      return QuestionType.singleChoice;
    case 'multiple_choice':
      return QuestionType.multipleChoice;
    case 'yes_no':
      return QuestionType.yesNo;
    case 'likert_1_5':
      return QuestionType.likert1to5;
    case 'text':
    default:
      return QuestionType.text;
  }
}

String questionTypeToString(QuestionType type) {
  switch (type) {
    case QuestionType.singleChoice:
      return 'single_choice';
    case QuestionType.multipleChoice:
      return 'multiple_choice';
    case QuestionType.yesNo:
      return 'yes_no';
    case QuestionType.likert1to5:
      return 'likert_1_5';
    case QuestionType.text:
    default:
      return 'text';
  }
}

/// Une question individuelle du questionnaire
class QuestionnaireQuestion {
  String id;
  String label;
  QuestionType type;
  List<String> options;
  bool required;

  QuestionnaireQuestion({
    required this.id,
    required this.label,
    this.type = QuestionType.text,
    this.options = const [],
    this.required = true,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'label': label,
      'type': questionTypeToString(type),
      'options': options,
      'required': required,
    };
  }

  factory QuestionnaireQuestion.fromJson(Map<String, dynamic> json) {
    return QuestionnaireQuestion(
      id: json['id'] as String? ?? '',
      label: json['label'] as String? ?? '',
      type: questionTypeFromString(json['type'] as String? ?? 'text'),
      options:
          (json['options'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      required: json['required'] as bool? ?? true,
    );
  }
}

/// Modèle aligné sur ta table `public.questionnaires`
class Questionnaire {
  final int? id;
  final String title;
  final String? description;

  final DateTime? startDate;
  final DateTime? endDate;

  /// colonnes SQL : population_raw, cse_targets, level_targets, metier_targets
  final List<String> populationRaw;
  final List<String> cseTargets;
  final List<String> levelTargets;
  final List<String> metierTargets;

  final int nbReponses;
  final bool isArchived;
  final DateTime? createdAt;
  final String? createdBy;

  /// Colonne JSONB `questions`
  final List<QuestionnaireQuestion> questions;

  Questionnaire({
    this.id,
    required this.title,
    this.description,
    this.startDate,
    this.endDate,
    this.populationRaw = const [],
    this.cseTargets = const [],
    this.levelTargets = const [],
    this.metierTargets = const [],
    this.nbReponses = 0,
    this.isArchived = false,
    this.createdAt,
    this.createdBy,
    this.questions = const [],
  });

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String && value.isNotEmpty) {
      return DateTime.parse(value);
    }
    return null;
  }

  static List<String> _parseTextArray(dynamic raw) {
    if (raw == null) return const [];
    if (raw is List) {
      return raw.map((e) => e.toString()).toList();
    }
    return const [];
  }

  factory Questionnaire.fromMap(Map<String, dynamic> map) {
    final questionsRaw = map['questions'];
    List<QuestionnaireQuestion> questions = [];

    if (questionsRaw is List) {
      questions = questionsRaw
          .map(
            (e) => QuestionnaireQuestion.fromJson(
              e is Map<String, dynamic>
                  ? e
                  : Map<String, dynamic>.from(e as Map),
            ),
          )
          .toList();
    } else if (questionsRaw is String && questionsRaw.isNotEmpty) {
      final decoded = jsonDecode(questionsRaw) as List<dynamic>;
      questions = decoded
          .map(
            (e) => QuestionnaireQuestion.fromJson(
              e is Map<String, dynamic>
                  ? e
                  : Map<String, dynamic>.from(e as Map),
            ),
          )
          .toList();
    }

    return Questionnaire(
      id: map['id'] as int?,
      title: map['title'] as String? ?? '',
      description: map['description'] as String?,
      startDate: _parseDate(map['start_date']),
      endDate: _parseDate(map['end_date']),
      populationRaw: _parseTextArray(map['population_raw']),
      cseTargets: _parseTextArray(map['cse_targets']),
      levelTargets: _parseTextArray(map['level_targets']),
      metierTargets: _parseTextArray(map['metier_targets']),
      nbReponses: map['nb_reponses'] as int? ?? 0,
      isArchived: map['is_archived'] as bool? ?? false,
      createdAt: _parseDate(map['created_at']),
      createdBy: map['created_by']?.toString(),
      questions: questions,
    );
  }
}
