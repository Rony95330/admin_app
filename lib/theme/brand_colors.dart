import 'package:flutter/material.dart';

/// Palette CFDT partagée avec l'application mobile.
class AppColors {
  const AppColors._();

  static const orange = Color(0xFFE7591C);
  static const blanc = Color(0xFFFFFFFF);
  static const anthracite = Color(0xFF555554);

  static const beige = Color(0xFFFBD6B9);
  static const rose = Color(0xFFF2AAC8);
  static const orangeClair = Color(0xFFF6A924);
  static const olive = Color(0xFFADA34B);
  static const kakiFonce = Color(0xFF59562F);
  static const citron = Color(0xFFE4E039);
  static const bordeaux = Color(0xFF6B3A3F);
  static const bleu = Color(0xFF6A85BE);
  static const violet = Color(0xFF474090);
  static const bleuPetrole = Color(0xFF00455E);
  static const lavande = Color(0xFFBB9AC4);
  static const turquoise = Color(0xFF89CCCF);
  static const grisBleute = Color(0xFFDFE7EC);
  static const greige = Color(0xFFD4CBC7);
  static const vert = Color(0xFFAAC955);

  static const surfaceLight = Color(0xFFFFFFFF);
  static const surfaceAltLight = Color(0xFFF7F9FB);
  static const surfaceDark = Color(0xFF171716);
  static const surfaceDarkAlt = Color(0xFF232321);

  static const success = vert;
  static const warning = orangeClair;
  static const info = bleu;
  static const danger = Color(0xFFB3261E);

  // Alias conservés pour les écrans historiques de la console. Ils pointent
  // désormais exclusivement vers la palette CFDT.
  static const marine = bleuPetrole;
  static const cyan = turquoise;
  static const jaune = citron;
  static const ardoise = anthracite;
  static const canard = bleuPetrole;
  static const prune = bordeaux;
  static const cie = grisBleute;
  static const rouge = danger;
}
