import 'package:flutter/material.dart';

enum AdminFieldKind {
  text,
  longText,
  integer,
  booleanValue,
  choice,
  stringList,
}

class AdminFieldDefinition {
  const AdminFieldDefinition({
    required this.key,
    required this.label,
    this.kind = AdminFieldKind.text,
    this.required = false,
    this.readOnly = false,
    this.immutableOnEdit = false,
    this.helperText,
    this.options = const <String>[],
  });

  final String key;
  final String label;
  final AdminFieldKind kind;
  final bool required;
  final bool readOnly;
  final bool immutableOnEdit;
  final String? helperText;
  final List<String> options;
}

class AdminCollectionDefinition {
  const AdminCollectionDefinition({
    required this.resource,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.primaryKey,
    required this.titleKey,
    required this.fields,
    this.titleKeys = const <String>[],
    this.subtitleKeys = const <String>[],
    this.allowCreate = true,
    this.allowDelete = true,
  });

  final String resource;
  final String title;
  final String subtitle;
  final IconData icon;
  final String primaryKey;
  final String titleKey;
  final List<String> titleKeys;
  final List<String> subtitleKeys;
  final List<AdminFieldDefinition> fields;
  final bool allowCreate;
  final bool allowDelete;
}

class AdminCollections {
  const AdminCollections._();

  static const users = AdminCollectionDefinition(
    resource: 'users',
    title: 'Comptes utilisateurs',
    subtitle: 'Rôles, habilitations, adhésion et suspension des comptes.',
    icon: Icons.manage_accounts_outlined,
    primaryKey: 'id',
    titleKey: 'email',
    titleKeys: <String>['prenom', 'nom'],
    subtitleKeys: <String>['email', 'matriculeaf', 'level'],
    allowCreate: false,
    allowDelete: false,
    fields: <AdminFieldDefinition>[
      AdminFieldDefinition(key: 'id', label: 'Identifiant', readOnly: true),
      AdminFieldDefinition(key: 'email', label: 'Email', readOnly: true),
      AdminFieldDefinition(key: 'prenom', label: 'Prénom', readOnly: true),
      AdminFieldDefinition(key: 'nom', label: 'Nom', readOnly: true),
      AdminFieldDefinition(
        key: 'matriculeaf',
        label: 'Matricule',
        readOnly: true,
      ),
      AdminFieldDefinition(key: 'pseudo', label: 'Pseudo'),
      AdminFieldDefinition(key: 'telephone', label: 'Téléphone'),
      AdminFieldDefinition(key: 'niveau', label: 'Niveau'),
      AdminFieldDefinition(
        key: 'level',
        label: 'Droit applicatif',
        kind: AdminFieldKind.choice,
        required: true,
        options: <String>['user', 'mili', 'adm', 'supuser'],
      ),
      AdminFieldDefinition(
        key: 'is_adherent',
        label: 'Adhérent',
        kind: AdminFieldKind.booleanValue,
      ),
      AdminFieldDefinition(
        key: 'ban',
        label: 'Compte suspendu',
        kind: AdminFieldKind.booleanValue,
      ),
    ],
  );

  static const about = AdminCollectionDefinition(
    resource: 'about',
    title: 'Page À propos',
    subtitle: 'Coordonnées et identité affichées dans l’application.',
    icon: Icons.info_outline,
    primaryKey: 'id',
    titleKey: 'name',
    subtitleKeys: <String>['email', 'phone'],
    allowCreate: false,
    allowDelete: false,
    fields: <AdminFieldDefinition>[
      AdminFieldDefinition(key: 'id', label: 'Identifiant', readOnly: true),
      AdminFieldDefinition(key: 'name', label: 'Nom', required: true),
      AdminFieldDefinition(key: 'phone', label: 'Téléphone'),
      AdminFieldDefinition(key: 'email', label: 'Email'),
      AdminFieldDefinition(key: 'avatar_url', label: 'URL de l’avatar'),
      AdminFieldDefinition(key: 'brand_logo_url', label: 'URL du logo CFDT'),
    ],
  );

  static const sectors = AdminCollectionDefinition(
    resource: 'sectors',
    title: 'Secteurs CSE',
    subtitle: 'Libellés et images du sélecteur de secteur.',
    icon: Icons.apartment_outlined,
    primaryKey: 'id',
    titleKey: 'cse',
    subtitleKeys: <String>['image_url'],
    fields: <AdminFieldDefinition>[
      AdminFieldDefinition(key: 'id', label: 'Identifiant', readOnly: true),
      AdminFieldDefinition(key: 'cse', label: 'Nom du CSE', required: true),
      AdminFieldDefinition(key: 'image_url', label: 'URL de l’image'),
    ],
  );

  static const qrAssets = AdminCollectionDefinition(
    resource: 'qr_assets',
    title: 'QR codes',
    subtitle: 'Textes et emplacements Storage des QR codes.',
    icon: Icons.qr_code_2_outlined,
    primaryKey: 'key',
    titleKey: 'title',
    subtitleKeys: <String>['key', 'object_path'],
    fields: <AdminFieldDefinition>[
      AdminFieldDefinition(
        key: 'key',
        label: 'Clé',
        required: true,
        immutableOnEdit: true,
      ),
      AdminFieldDefinition(key: 'title', label: 'Titre', required: true),
      AdminFieldDefinition(
        key: 'description',
        label: 'Description',
        kind: AdminFieldKind.longText,
      ),
      AdminFieldDefinition(key: 'bucket', label: 'Bucket', required: true),
      AdminFieldDefinition(
        key: 'object_path',
        label: 'Chemin du fichier',
        required: true,
      ),
      AdminFieldDefinition(
        key: 'is_active',
        label: 'Actif',
        kind: AdminFieldKind.booleanValue,
      ),
    ],
  );

  static const commissions = AdminCollectionDefinition(
    resource: 'commissions',
    title: 'Commissions',
    subtitle: 'Référentiel proposé lors de la saisie des mandats.',
    icon: Icons.event_note_outlined,
    primaryKey: 'id',
    titleKey: 'code',
    fields: <AdminFieldDefinition>[
      AdminFieldDefinition(key: 'id', label: 'Identifiant', readOnly: true),
      AdminFieldDefinition(key: 'code', label: 'Code', required: true),
      AdminFieldDefinition(
        key: 'is_active',
        label: 'Actif',
        kind: AdminFieldKind.booleanValue,
      ),
    ],
  );

  static const podcasts = AdminCollectionDefinition(
    resource: 'podcasts',
    title: 'Podcasts',
    subtitle: 'Émissions audio disponibles dans l’espace adhérent.',
    icon: Icons.podcasts_outlined,
    primaryKey: 'id',
    titleKey: 'title',
    subtitleKeys: <String>['cse', 'published_at'],
    fields: <AdminFieldDefinition>[
      AdminFieldDefinition(key: 'id', label: 'Identifiant', readOnly: true),
      AdminFieldDefinition(key: 'title', label: 'Titre', required: true),
      AdminFieldDefinition(
        key: 'audio_url',
        label: 'URL audio',
        required: true,
      ),
      AdminFieldDefinition(key: 'cse', label: 'CSE', required: true),
      AdminFieldDefinition(
        key: 'published_at',
        label: 'Date de publication',
        helperText: 'Format ISO, par exemple 2026-08-16T21:00:00Z',
      ),
      AdminFieldDefinition(
        key: 'is_active',
        label: 'Actif',
        kind: AdminFieldKind.booleanValue,
      ),
      AdminFieldDefinition(
        key: 'nb_listens',
        label: 'Écoutes',
        kind: AdminFieldKind.integer,
        readOnly: true,
      ),
      AdminFieldDefinition(
        key: 'nb_likes',
        label: 'J’aime',
        kind: AdminFieldKind.integer,
        readOnly: true,
      ),
      AdminFieldDefinition(
        key: 'nb_dislikes',
        label: 'Je n’aime pas',
        kind: AdminFieldKind.integer,
        readOnly: true,
      ),
    ],
  );

  static const attestations = AdminCollectionDefinition(
    resource: 'attestations',
    title: 'Attestations',
    subtitle: 'Référencement des attestations syndicales par matricule.',
    icon: Icons.workspace_premium_outlined,
    primaryKey: 'id',
    titleKey: 'matricule',
    subtitleKeys: <String>['nom', 'prenom', 'annee'],
    fields: <AdminFieldDefinition>[
      AdminFieldDefinition(key: 'id', label: 'Identifiant', readOnly: true),
      AdminFieldDefinition(
        key: 'matricule',
        label: 'Matricule',
        required: true,
      ),
      AdminFieldDefinition(key: 'nom', label: 'Nom', required: true),
      AdminFieldDefinition(key: 'prenom', label: 'Prénom', required: true),
      AdminFieldDefinition(
        key: 'annee',
        label: 'Année',
        kind: AdminFieldKind.integer,
        required: true,
      ),
      AdminFieldDefinition(
        key: 'storage_path',
        label: 'Chemin dans le bucket attestations',
        required: true,
      ),
      AdminFieldDefinition(
        key: 'created_at',
        label: 'Créée le',
        readOnly: true,
      ),
    ],
  );

  static const mandates = AdminCollectionDefinition(
    resource: 'mandates',
    title: 'Mandats',
    subtitle: 'Correction et suivi des mandats saisis par les militants.',
    icon: Icons.calendar_month_outlined,
    primaryKey: 'id',
    titleKey: 'cse_code',
    subtitleKeys: <String>['date_start', 'title', 'sent_to_section'],
    allowCreate: false,
    fields: <AdminFieldDefinition>[
      AdminFieldDefinition(key: 'id', label: 'Identifiant', readOnly: true),
      AdminFieldDefinition(
        key: 'user_id',
        label: 'Utilisateur',
        readOnly: true,
      ),
      AdminFieldDefinition(key: 'cse_code', label: 'CSE', required: true),
      AdminFieldDefinition(key: 'date_start', label: 'Date', required: true),
      AdminFieldDefinition(
        key: 'all_day',
        label: 'Journée entière',
        kind: AdminFieldKind.booleanValue,
      ),
      AdminFieldDefinition(key: 'start_time', label: 'Heure de début'),
      AdminFieldDefinition(key: 'end_time', label: 'Heure de fin'),
      AdminFieldDefinition(key: 'title', label: 'Intitulé'),
      AdminFieldDefinition(
        key: 'sent_to_section',
        label: 'Envoyé à la section',
        kind: AdminFieldKind.booleanValue,
      ),
      AdminFieldDefinition(key: 'sent_at', label: 'Envoyé le', readOnly: true),
    ],
  );

  static const aviationSources = AdminCollectionDefinition(
    resource: 'aviation_sources',
    title: 'Sources du Fil aérien',
    subtitle: 'Flux, ordre et état des sources aéronautiques.',
    icon: Icons.flight_takeoff_outlined,
    primaryKey: 'id',
    titleKey: 'name',
    subtitleKeys: <String>['feed_url', 'last_success_at'],
    fields: <AdminFieldDefinition>[
      AdminFieldDefinition(
        key: 'id',
        label: 'Clé technique',
        required: true,
        immutableOnEdit: true,
      ),
      AdminFieldDefinition(key: 'name', label: 'Nom', required: true),
      AdminFieldDefinition(
        key: 'feed_url',
        label: 'URL du flux',
        required: true,
      ),
      AdminFieldDefinition(
        key: 'is_active',
        label: 'Actif',
        kind: AdminFieldKind.booleanValue,
      ),
      AdminFieldDefinition(
        key: 'is_specialized_press',
        label: 'Presse spécialisée',
        kind: AdminFieldKind.booleanValue,
      ),
      AdminFieldDefinition(
        key: 'sort_order',
        label: 'Ordre',
        kind: AdminFieldKind.integer,
        required: true,
      ),
      AdminFieldDefinition(
        key: 'last_attempt_at',
        label: 'Dernier essai',
        readOnly: true,
      ),
      AdminFieldDefinition(
        key: 'last_success_at',
        label: 'Dernier succès',
        readOnly: true,
      ),
      AdminFieldDefinition(
        key: 'last_error',
        label: 'Dernière erreur',
        kind: AdminFieldKind.longText,
        readOnly: true,
      ),
    ],
  );

  static const labourSources = AdminCollectionDefinition(
    resource: 'labour_sources',
    title: 'Sources du Fil juridique',
    subtitle: 'Flux, catégories et thématiques du droit du travail.',
    icon: Icons.gavel_outlined,
    primaryKey: 'id',
    titleKey: 'name',
    subtitleKeys: <String>['channel_name', 'last_success_at'],
    fields: <AdminFieldDefinition>[
      AdminFieldDefinition(
        key: 'id',
        label: 'Clé technique',
        required: true,
        immutableOnEdit: true,
      ),
      AdminFieldDefinition(key: 'name', label: 'Nom', required: true),
      AdminFieldDefinition(key: 'channel_name', label: 'Canal'),
      AdminFieldDefinition(key: 'feed_url', label: 'URL du flux'),
      AdminFieldDefinition(
        key: 'source_kind',
        label: 'Type de source',
        kind: AdminFieldKind.choice,
        required: true,
        options: <String>['feed', 'google_news', 'judilibre'],
      ),
      AdminFieldDefinition(
        key: 'source_category',
        label: 'Catégorie',
        kind: AdminFieldKind.choice,
        required: true,
        options: <String>['official', 'institutional', 'specialized'],
      ),
      AdminFieldDefinition(
        key: 'is_active',
        label: 'Actif',
        kind: AdminFieldKind.booleanValue,
      ),
      AdminFieldDefinition(
        key: 'sort_order',
        label: 'Ordre',
        kind: AdminFieldKind.integer,
        required: true,
      ),
      AdminFieldDefinition(
        key: 'default_topics',
        label: 'Thématiques par défaut',
        kind: AdminFieldKind.stringList,
        helperText: 'Séparer les valeurs par des virgules.',
      ),
      AdminFieldDefinition(
        key: 'requires_filter',
        label: 'Filtrage renforcé',
        kind: AdminFieldKind.booleanValue,
      ),
      AdminFieldDefinition(
        key: 'last_attempt_at',
        label: 'Dernier essai',
        readOnly: true,
      ),
      AdminFieldDefinition(
        key: 'last_success_at',
        label: 'Dernier succès',
        readOnly: true,
      ),
      AdminFieldDefinition(
        key: 'last_error',
        label: 'Dernière erreur',
        kind: AdminFieldKind.longText,
        readOnly: true,
      ),
    ],
  );
}
