import 'package:flutter/material.dart';
import '../core/app_failure.dart';

void showFailureSnackBar(
  BuildContext context,
  AppFailure failure, {
  String? overrideMessage,
}) {
  final msg = overrideMessage ?? failure.message;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(msg),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 4),
    ),
  );
}

/// Petit widget d’état d’erreur réutilisable
class ErrorStateView extends StatelessWidget {
  final AppFailure failure;
  final VoidCallback? onRetry;
  const ErrorStateView({super.key, required this.failure, this.onRetry});

  @override
  Widget build(BuildContext context) {
    final text = failure.message;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.wifi_off, size: 40),
          const SizedBox(height: 8),
          Text(text, textAlign: TextAlign.center),
          if (onRetry != null) ...[
            const SizedBox(height: 12),
            FilledButton(onPressed: onRetry, child: const Text("Réessayer")),
          ],
        ],
      ),
    );
  }
}
