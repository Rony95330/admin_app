import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/runtime_control/app_runtime_control_model.dart';

class AppRuntimeControlScreen extends StatelessWidget {
  const AppRuntimeControlScreen({
    super.key,
    required this.state,
    required this.onRetry,
    required this.retrying,
  });

  final AppRuntimeState state;
  final Future<void> Function() onRetry;
  final bool retrying;

  static const Color _orange = Color(0xFFF45A0A);
  static const Color _navy = Color(0xFF13233F);
  static const Color _blue = Color(0xFF1455A3);

  @override
  Widget build(BuildContext context) {
    final maintenance = state.mode == AppRuntimeMode.maintenance;
    final title = maintenance
        ? 'Application temporairement indisponible'
        : 'Application momentanément désactivée';
    final defaultBody = maintenance
        ? 'Une opération de maintenance est en cours.\n\n'
              'Nous faisons le nécessaire pour rétablir le service dans les meilleurs délais.'
        : 'L’accès à l’application est temporairement suspendu.\n\n'
              'Pour toute information complémentaire, veuillez contacter votre administrateur.';
    final info = maintenance
        ? 'Merci de réessayer dans quelques instants.'
        : 'Merci de réessayer ultérieurement.';
    final asset = maintenance
        ? 'assets/runtime_control/maintenance_illustration.png'
        : 'assets/runtime_control/suspended_illustration.png';

    final customMessage = state.publicMessage?.trim();
    final body = customMessage == null || customMessage.isEmpty
        ? defaultBody
        : customMessage;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              Color(0xFFFFF8F3),
              Color(0xFFF8FAFF),
              Color(0xFFFFFBF8),
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 650),
                child: Column(
                  children: <Widget>[
                    const _CfdtHeader(),
                    const SizedBox(height: 24),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(24, 28, 24, 22),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.98),
                        borderRadius: BorderRadius.circular(34),
                        boxShadow: const <BoxShadow>[
                          BoxShadow(
                            blurRadius: 34,
                            offset: Offset(0, 12),
                            color: Color(0x18000000),
                          ),
                        ],
                      ),
                      child: Column(
                        children: <Widget>[
                          Image.asset(
                            asset,
                            height: 240,
                            fit: BoxFit.contain,
                            semanticLabel: maintenance
                                ? 'Illustration de maintenance'
                                : 'Illustration de suspension du service',
                          ),
                          const SizedBox(height: 18),
                          Text(
                            title,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: _navy,
                              fontSize: 34,
                              height: 1.05,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 18),
                          Container(
                            width: 42,
                            height: 3,
                            decoration: BoxDecoration(
                              color: _orange,
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            body,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Color(0xFF28364E),
                              fontSize: 18,
                              height: 1.45,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                          const SizedBox(height: 22),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 16,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF0F6FF),
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Row(
                              children: <Widget>[
                                const Icon(
                                  Icons.info_outline_rounded,
                                  color: _blue,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    info,
                                    style: const TextStyle(
                                      color: _blue,
                                      fontSize: 16,
                                      height: 1.3,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 22),
                          SizedBox(
                            width: double.infinity,
                            height: 58,
                            child: FilledButton(
                              onPressed: retrying ? null : onRetry,
                              style: FilledButton.styleFrom(
                                backgroundColor: _orange,
                                foregroundColor: Colors.white,
                                disabledBackgroundColor: _orange.withValues(
                                  alpha: 0.55,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                              ),
                              child: retrying
                                  ? const SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text(
                                      'Réessayer',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                            ),
                          ),
                          if (!kIsWeb) ...<Widget>[
                            const SizedBox(height: 8),
                            TextButton(
                              onPressed: () => SystemNavigator.pop(),
                              child: const Text(
                                'Fermer',
                                style: TextStyle(
                                  color: _blue,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w600,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CfdtHeader extends StatelessWidget {
  const _CfdtHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Container(
          width: 64,
          height: 64,
          decoration: const BoxDecoration(
            color: AppRuntimeControlScreen._orange,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: const Text(
            'Cfdt:',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 14),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'CFDT',
                style: TextStyle(
                  color: AppRuntimeControlScreen._orange,
                  fontSize: 27,
                  fontWeight: FontWeight.w800,
                  height: 1,
                ),
              ),
              SizedBox(height: 6),
              Text(
                'S’ENGAGER POUR CHACUN\nAGIR POUR TOUS',
                style: TextStyle(
                  color: AppRuntimeControlScreen._navy,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
        const Icon(
          Icons.account_circle_outlined,
          color: AppRuntimeControlScreen._orange,
          size: 38,
        ),
      ],
    );
  }
}
