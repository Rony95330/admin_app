enum AppRuntimeMode {
  active,
  maintenance,
  suspended;

  static AppRuntimeMode fromDatabase(Object? value) {
    switch (value?.toString().trim().toLowerCase()) {
      case 'maintenance':
        return AppRuntimeMode.maintenance;
      case 'suspended':
        return AppRuntimeMode.suspended;
      case 'active':
      default:
        return AppRuntimeMode.active;
    }
  }

  String get databaseValue => name;
}

class AppRuntimeState {
  const AppRuntimeState({
    required this.mode,
    this.publicMessage,
    this.updatedAt,
  });

  const AppRuntimeState.active()
    : mode = AppRuntimeMode.active,
      publicMessage = null,
      updatedAt = null;

  final AppRuntimeMode mode;
  final String? publicMessage;
  final DateTime? updatedAt;

  bool get blocksAccess => mode != AppRuntimeMode.active;
}
