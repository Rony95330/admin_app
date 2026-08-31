import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/runtime_control/app_runtime_control_model.dart';

class AppRuntimeControlService {
  AppRuntimeControlService({SupabaseClient? client}) : _providedClient = client;

  final SupabaseClient? _providedClient;

  SupabaseClient get _client => _providedClient ?? Supabase.instance.client;

  static const Duration _networkTimeout = Duration(seconds: 5);
  static const String _cachePrefix = 'app_runtime_control';

  Future<AppRuntimeState> loadCached(String target) async {
    final prefs = await SharedPreferences.getInstance();
    final mode = AppRuntimeMode.fromDatabase(
      prefs.getString('${_cachePrefix}_${target}_mode'),
    );
    final message = prefs.getString('${_cachePrefix}_${target}_message');
    final updatedRaw = prefs.getString('${_cachePrefix}_${target}_updated_at');

    return AppRuntimeState(
      mode: mode,
      publicMessage: message,
      updatedAt: updatedRaw == null ? null : DateTime.tryParse(updatedRaw),
    );
  }

  Future<AppRuntimeState?> fetchRemote(String target) async {
    final dynamic response = await _client
        .rpc(
          'get_app_runtime_control',
          params: <String, dynamic>{'p_target': target},
        )
        .timeout(_networkTimeout);

    Map<String, dynamic>? row;

    if (response is List && response.isNotEmpty && response.first is Map) {
      row = Map<String, dynamic>.from(response.first as Map);
    } else if (response is Map) {
      row = Map<String, dynamic>.from(response);
    }

    if (row == null || row.isEmpty) return null;

    return AppRuntimeState(
      mode: AppRuntimeMode.fromDatabase(row['mode']),
      publicMessage: row['public_message']?.toString(),
      updatedAt: DateTime.tryParse(row['updated_at']?.toString() ?? ''),
    );
  }

  Future<AppRuntimeState> resolve(String target) async {
    final cached = await loadCached(target);

    try {
      final remote = await fetchRemote(target);
      if (remote == null) return cached;
      await _save(target, remote);
      return remote;
    } catch (_) {
      // Comportement volontaire : on conserve le dernier état connu.
      // - si l'app était active, une panne Supabase ne la coupe pas ;
      // - si elle était suspendue, un simple redémarrage hors ligne
      //   ne contourne pas la suspension déjà reçue.
      return cached;
    }
  }

  Future<AppRuntimeState?> refresh(String target) async {
    try {
      final remote = await fetchRemote(target);
      if (remote == null) return null;
      await _save(target, remote);
      return remote;
    } catch (_) {
      return null;
    }
  }

  Future<void> _save(String target, AppRuntimeState state) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      '${_cachePrefix}_${target}_mode',
      state.mode.databaseValue,
    );

    final message = state.publicMessage?.trim();
    if (message == null || message.isEmpty) {
      await prefs.remove('${_cachePrefix}_${target}_message');
    } else {
      await prefs.setString('${_cachePrefix}_${target}_message', message);
    }

    if (state.updatedAt == null) {
      await prefs.remove('${_cachePrefix}_${target}_updated_at');
    } else {
      await prefs.setString(
        '${_cachePrefix}_${target}_updated_at',
        state.updatedAt!.toUtc().toIso8601String(),
      );
    }
  }
}
