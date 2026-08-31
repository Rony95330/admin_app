import 'package:supabase_flutter/supabase_flutter.dart';

class AdminProfileSummary {
  const AdminProfileSummary({
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.level,
    required this.cse,
    required this.cseImageUrl,
  });

  final String firstName;
  final String lastName;
  final String email;
  final String level;
  final String cse;
  final String cseImageUrl;

  String get displayName {
    final name = <String>[
      firstName,
      lastName,
    ].where((value) => value.trim().isNotEmpty).join(' ').trim();
    return name.isEmpty ? email : name;
  }
}

class AdminProfileService {
  AdminProfileService({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<AdminProfileSummary> load() async {
    final authUser = _client.auth.currentUser;
    if (authUser == null) {
      throw const AuthException('Session expirée, reconnectez-vous.');
    }

    final rawProfile = await _client
        .from('users')
        .select('prenom, nom, email, level, cse, matriculeaf')
        .eq('id', authUser.id)
        .maybeSingle();

    if (rawProfile == null) {
      throw const AuthException('Profil administrateur introuvable.');
    }

    final profile = Map<String, dynamic>.from(rawProfile);
    final matricule = _text(profile['matriculeaf']);
    var cse = _text(profile['cse']);

    if (cse.isEmpty && matricule.isNotEmpty) {
      final rawContext = await _client.rpc('current_user_context');

      if (rawContext is List &&
          rawContext.isNotEmpty &&
          rawContext.first is Map) {
        cse = _text((rawContext.first as Map)['cse']);
      }
    }

    var imageUrl = '';
    final rawSectors = await _client
        .from('liste_cse')
        .select('cse, image_url')
        .order('cse');
    for (final rawSector in rawSectors) {
      final sector = Map<String, dynamic>.from(rawSector);
      if (_normalizeCse(_text(sector['cse'])) == _normalizeCse(cse)) {
        imageUrl = _text(sector['image_url']);
        break;
      }
    }

    final metadata = authUser.userMetadata ?? const <String, dynamic>{};
    return AdminProfileSummary(
      firstName: _firstNotEmpty(
        _text(profile['prenom']),
        _text(metadata['prenom']),
      ),
      lastName: _firstNotEmpty(_text(profile['nom']), _text(metadata['nom'])),
      email: _firstNotEmpty(_text(profile['email']), authUser.email ?? ''),
      level: _text(profile['level']).isEmpty ? 'user' : _text(profile['level']),
      cse: cse,
      cseImageUrl: imageUrl,
    );
  }

  static String _text(dynamic value) => value?.toString().trim() ?? '';

  static String _firstNotEmpty(String first, String second) {
    return first.trim().isNotEmpty ? first.trim() : second.trim();
  }

  static String _normalizeCse(String value) {
    return value
        .trim()
        .toUpperCase()
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll('’', "'");
  }
}
