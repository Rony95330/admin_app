import 'package:flutter/material.dart';

import '../services/admin_profile_service.dart';
import '../theme/brand_colors.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final AdminProfileService _profileService = AdminProfileService();
  late Future<AdminProfileSummary> _profileFuture = _profileService.load();

  void _reload() {
    setState(() => _profileFuture = _profileService.load());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tableau de bord'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Actualiser',
            onPressed: _reload,
            icon: const Icon(Icons.refresh),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: FutureBuilder<AdminProfileSummary>(
        future: _profileFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || snapshot.data == null) {
            return _DashboardError(
              message: snapshot.error?.toString() ?? 'Profil indisponible.',
              onRetry: _reload,
            );
          }

          return _DashboardWelcome(profile: snapshot.data!);
        },
      ),
    );
  }
}

class _DashboardWelcome extends StatelessWidget {
  const _DashboardWelcome({required this.profile});

  final AdminProfileSummary profile;

  @override
  Widget build(BuildContext context) {
    final cseLabel = profile.cse.isEmpty ? 'CSE non renseigné' : profile.cse;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1120),
          child: Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: AppColors.bleuPetrole.withValues(alpha: 0.12),
              ),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: AppColors.anthracite.withValues(alpha: 0.08),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.all(26),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: <Color>[AppColors.bleuPetrole, Color(0xFF12677D)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Wrap(
                    spacing: 18,
                    runSpacing: 18,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: <Widget>[
                      Container(
                        width: 68,
                        height: 68,
                        decoration: BoxDecoration(
                          color: AppColors.orange,
                          borderRadius: BorderRadius.circular(19),
                        ),
                        alignment: Alignment.center,
                        child: const Text(
                          'CFDT',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                          ),
                        ),
                      ),
                      ConstrainedBox(
                        constraints: const BoxConstraints(minWidth: 240),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              'Bienvenue ${profile.displayName}',
                              style: Theme.of(context).textTheme.headlineSmall
                                  ?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: <Widget>[
                                _ProfileBadge(
                                  icon: Icons.admin_panel_settings_outlined,
                                  label: 'Niveau : ${profile.level}',
                                ),
                                _ProfileBadge(
                                  icon: Icons.apartment_outlined,
                                  label: cseLabel,
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Text(
                              'Vous pouvez mettre à jour les données de votre CSE.',
                              style: Theme.of(context).textTheme.bodyLarge
                                  ?.copyWith(
                                    color: Colors.white.withValues(alpha: 0.88),
                                    fontWeight: FontWeight.w500,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Votre CSE',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        cseLabel,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.bleuPetrole,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _CseImage(
                        imageUrl: profile.cseImageUrl,
                        cseLabel: cseLabel,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileBadge extends StatelessWidget {
  const _ProfileBadge({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, color: Colors.white, size: 17),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _CseImage extends StatelessWidget {
  const _CseImage({required this.imageUrl, required this.cseLabel});

  final String imageUrl;
  final String cseLabel;

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      height: 300,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.beige.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Icon(
            Icons.image_not_supported_outlined,
            size: 46,
            color: AppColors.bleuPetrole,
          ),
          const SizedBox(height: 10),
          Text(
            'Aucune image disponible pour $cseLabel',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );

    if (imageUrl.isEmpty) return placeholder;

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 430),
        child: Image.network(
          imageUrl,
          width: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => placeholder,
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return const SizedBox(
              height: 300,
              child: Center(child: CircularProgressIndicator()),
            );
          },
        ),
      ),
    );
  }
}

class _DashboardError extends StatelessWidget {
  const _DashboardError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(
              Icons.cloud_off_outlined,
              color: AppColors.danger,
              size: 48,
            ),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Réessayer'),
            ),
          ],
        ),
      ),
    );
  }
}
