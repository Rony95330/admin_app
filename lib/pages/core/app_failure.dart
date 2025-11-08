import 'dart:io';

sealed class AppFailure {
  final String code; // ex: postgres:23505, net:timeout, auth:unauthorized...
  final Object? raw;
  final StackTrace? stack;
  const AppFailure(this.code, {this.raw, this.stack});

  /// Message utilisateur (FR, vouvoiement)
  String get message => switch (this) {
    NetworkFailure() =>
      "Oups… il semble qu’il y ait un souci de connexion. Veuillez vérifier votre accès Internet et réessayer.",
    TimeoutFailure() =>
      "Le serveur met trop de temps à répondre. Veuillez réessayer dans un instant.",
    RateLimitFailure() =>
      "Vous effectuez trop de requêtes en même temps. Veuillez réessayer dans quelques secondes.",
    PermissionFailure() => "Action non autorisée pour votre compte.",
    AuthFailure() => "Votre session a expiré. Veuillez vous reconnecter.",
    NotFoundFailure() => "Aucune donnée trouvée.",
    ConflictFailure() =>
      "Conflit de données. Veuillez actualiser puis réessayer.",
    ValidationFailure() =>
      "Certaines données sont invalides. Veuillez vérifier les champs saisis.",
    ServerFailure() =>
      "Une erreur serveur est survenue. Veuillez réessayer plus tard.",
    DatabaseFailure() =>
      "Une erreur de base de données est survenue. Veuillez réessayer.",
    UnknownFailure() =>
      "Une erreur inattendue est survenue. Veuillez réessayer.",
  };
}

class NetworkFailure extends AppFailure {
  NetworkFailure({Object? raw, StackTrace? stack})
    : super("net:connection", raw: raw, stack: stack);
}

class TimeoutFailure extends AppFailure {
  TimeoutFailure({Object? raw, StackTrace? stack})
    : super("net:timeout", raw: raw, stack: stack);
}

class RateLimitFailure extends AppFailure {
  RateLimitFailure({Object? raw, StackTrace? stack})
    : super("net:ratelimit", raw: raw, stack: stack);
}

class PermissionFailure extends AppFailure {
  PermissionFailure({Object? raw, StackTrace? stack})
    : super("auth:forbidden", raw: raw, stack: stack);
}

class AuthFailure extends AppFailure {
  AuthFailure({Object? raw, StackTrace? stack})
    : super("auth:unauthorized", raw: raw, stack: stack);
}

class NotFoundFailure extends AppFailure {
  NotFoundFailure({Object? raw, StackTrace? stack})
    : super("data:not_found", raw: raw, stack: stack);
}

class ConflictFailure extends AppFailure {
  ConflictFailure({Object? raw, StackTrace? stack})
    : super("data:conflict", raw: raw, stack: stack);
}

class ValidationFailure extends AppFailure {
  ValidationFailure({Object? raw, StackTrace? stack})
    : super("data:validation", raw: raw, stack: stack);
}

class ServerFailure extends AppFailure {
  ServerFailure({Object? raw, StackTrace? stack})
    : super("server:error", raw: raw, stack: stack);
}

class DatabaseFailure extends AppFailure {
  DatabaseFailure(String pgCode, {Object? raw, StackTrace? stack})
    : super("postgres:$pgCode", raw: raw, stack: stack);
}

class UnknownFailure extends AppFailure {
  UnknownFailure({Object? raw, StackTrace? stack})
    : super("unknown", raw: raw, stack: stack);
}

/// Mapper d’exceptions (Supabase / PostgREST / réseau) -> AppFailure
AppFailure mapToFailure(Object error, [StackTrace? stack]) {
  final raw = error;

  // Réseau
  if (error is SocketException) return NetworkFailure(raw: raw, stack: stack);
  if (error is HandshakeException)
    return NetworkFailure(raw: raw, stack: stack);
  if (error is TlsException) return NetworkFailure(raw: raw, stack: stack);

  // Timeout (ex. dio/http)
  if (error.toString().contains("TimeoutException") ||
      error.toString().contains("timed out")) {
    return TimeoutFailure(raw: raw, stack: stack);
  }

  // Supabase PostgREST (inspection via toString())
  final s = error.toString();

  // Codes PG fréquents
  String? pg;
  final match = RegExp(
    r'PostgrestException.*code:\s?([0-9A-Z]{5})',
  ).firstMatch(s);
  if (match != null) pg = match.group(1);

  if (pg != null) {
    switch (pg) {
      case '23505':
        return ConflictFailure(raw: raw, stack: stack); // unique_violation
      case '23503':
        return ValidationFailure(
          raw: raw,
          stack: stack,
        ); // foreign_key_violation
      case '22P02':
        return ValidationFailure(
          raw: raw,
          stack: stack,
        ); // invalid_text_representation
      case '42501':
        return PermissionFailure(
          raw: raw,
          stack: stack,
        ); // insufficient_privilege
      case '55P03':
        return ServerFailure(raw: raw, stack: stack); // lock_not_available
      case '40001':
        return RateLimitFailure(
          raw: raw,
          stack: stack,
        ); // serialization_failure
      case '53300':
        return ServerFailure(raw: raw, stack: stack); // too_many_connections
      default:
        return DatabaseFailure(pg, raw: raw, stack: stack);
    }
  }

  if (s.contains("Invalid API key") ||
      s.contains("JWT") ||
      s.contains("auth")) {
    return AuthFailure(raw: raw, stack: stack);
  }
  if (s.contains("Permission denied") || s.contains("RLS")) {
    return PermissionFailure(raw: raw, stack: stack);
  }
  if (s.contains("Failed host lookup") || s.contains("Connection refused")) {
    return NetworkFailure(raw: raw, stack: stack);
  }
  if (s.contains("404") || s.contains("Not Found")) {
    return NotFoundFailure(raw: raw, stack: stack);
  }
  if (s.contains("429")) {
    return RateLimitFailure(raw: raw, stack: stack);
  }
  if (s.contains("5xx") || s.contains("500")) {
    return ServerFailure(raw: raw, stack: stack);
  }
  return UnknownFailure(raw: raw, stack: stack);
}
