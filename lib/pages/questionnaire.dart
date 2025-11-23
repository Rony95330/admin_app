// lib/models/questionnaire.dart
import 'dart:convert';

enum QuestionType { text, singleChoice, multipleChoice }

QuestionType questionTypeFromString(String value) {
  switch (value) {
    case 'single_choice':
      return QuestionType.singleChoice;
    case 'multiple_choice':
      return QuestionType.multipleChoice;
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
    case QuestionType.text:
    default:
      return 'text';
  }
}

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

class Questionnaire {
  final int? id;
  String titre;
  String? description;
  List<String> cseTarget;
  String publicCible;
  List<String> categories;
  List<QuestionnaireQuestion> questions;
  DateTime? dateDebut;
  DateTime? dateFin;

  Questionnaire({
    this.id,
    required this.titre,
    this.description,
    this.cseTarget = const [],
    required this.publicCible,
    this.categories = const [],
    this.questions = const [],
    this.dateDebut,
    this.dateFin,
  });

  Map<String, dynamic> toInsertMap() {
    return {
      'titre': titre,
      'description': description,
      'cse_target': cseTarget,
      'public_cible': publicCible,
      'categories': categories,
      'questions': questions.map((q) => q.toJson()).toList(),
      'date_debut': dateDebut?.toIso8601String(),
      'date_fin': dateFin?.toIso8601String(),
    };
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
    } else if (questionsRaw is String) {
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
      titre: map['titre'] as String? ?? '',
      description: map['description'] as String?,
      cseTarget:
          (map['cse_target'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      publicCible: map['public_cible'] as String? ?? 'ALL',
      categories:
          (map['categories'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      questions: questions,
      dateDebut: map['date_debut'] != null
          ? DateTime.parse(map['date_debut'] as String)
          : null,
      dateFin: map['date_fin'] != null
          ? DateTime.parse(map['date_fin'] as String)
          : null,
    );
  }
}
