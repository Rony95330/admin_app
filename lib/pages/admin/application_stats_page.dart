import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/admin_profile_service.dart';
import '../../theme/brand_colors.dart';

class ApplicationStatsPage extends StatefulWidget {
  const ApplicationStatsPage({super.key});

  @override
  State<ApplicationStatsPage> createState() => _ApplicationStatsPageState();
}

class _ApplicationStatsPageState extends State<ApplicationStatsPage> {
  final SupabaseClient _client = Supabase.instance.client;
  final AdminProfileService _profileService = AdminProfileService();

  bool _loading = true;
  String? _error;
  AdminProfileSummary? _profile;
  List<_StatsCardData> _cards = const <_StatsCardData>[];
  DateTime? _lastUpdated;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final profile = await _profileService.load();
      if (profile.cse.trim().isEmpty) {
        throw Exception(
          'Aucun CSE n’est associé à votre compte. Vérifiez la table users.',
        );
      }

      final cse = profile.cse.trim();
      final responses = await Future.wait<dynamic>(<Future<dynamic>>[
        _client.rpc(
          'stats_users_kpis',
          params: <String, dynamic>{'p_cse': cse},
        ),
        _client.rpc(
          'stats_articles_kpis',
          params: <String, dynamic>{'p_cse': cse},
        ),
        _client.rpc('stats_revue_kpis'),
        _client.rpc(
          'stats_podcasts_kpis',
          params: <String, dynamic>{'p_cse': cse},
        ),
        _client.rpc(
          'stats_outbox_kpis',
          params: <String, dynamic>{'p_cse': cse, 'p_include_tous': true},
        ),
      ]);

      final users = _firstRow(responses[0]);
      final articles = _firstRow(responses[1]);
      final revue = _firstRow(responses[2]);
      final podcasts = _firstRow(responses[3]);
      final notifications = _firstRow(responses[4]);

      final cards = <_StatsCardData>[
        _StatsCardData(
          title: 'Utilisateurs',
          icon: Icons.groups_2_outlined,
          color: AppColors.orange,
          metrics: <_StatsMetric>[
            _StatsMetric('Total', _asInt(users['total'])),
            _StatsMetric('Nouveaux sur 7 jours', _asInt(users['new_7d'])),
            _StatsMetric(
              'Notifications activées',
              _asInt(users['notif_enabled']),
            ),
          ],
        ),
        _contentCard(
          title: 'Actualités',
          icon: Icons.article_outlined,
          color: AppColors.violet,
          row: articles,
        ),
        _contentCard(
          title: 'Revue de presse',
          icon: Icons.library_books_outlined,
          color: AppColors.bleu,
          row: revue,
        ),
        _StatsCardData(
          title: 'Podcasts',
          icon: Icons.podcasts_outlined,
          color: AppColors.rose,
          metrics: <_StatsMetric>[
            _StatsMetric('Podcasts', _asInt(podcasts['items_count'])),
            _StatsMetric('Écoutes', _asInt(podcasts['listens'])),
            _StatsMetric('Avis positifs', _asInt(podcasts['likes'])),
          ],
        ),
        _contentCard(
          title: 'Notifications',
          icon: Icons.notifications_active_outlined,
          color: AppColors.citron,
          row: notifications,
        ),
      ];

      if (!mounted) return;
      setState(() {
        _profile = profile;
        _cards = cards;
        _lastUpdated = DateTime.now();
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  _StatsCardData _contentCard({
    required String title,
    required IconData icon,
    required Color color,
    required Map<String, dynamic> row,
  }) {
    return _StatsCardData(
      title: title,
      icon: icon,
      color: color,
      metrics: <_StatsMetric>[
        _StatsMetric('Publications', _asInt(row['items_count'])),
        _StatsMetric('Ouvertures', _asInt(row['opens'])),
        _StatsMetric('Téléchargements', _asInt(row['downloads'])),
      ],
    );
  }

  Map<String, dynamic> _firstRow(dynamic response) {
    if (response is List && response.isNotEmpty && response.first is Map) {
      return Map<String, dynamic>.from(response.first as Map);
    }
    if (response is Map) return Map<String, dynamic>.from(response);
    return <String, dynamic>{};
  }

  int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _timeLabel(DateTime? value) {
    if (value == null) return '—';
    final hours = value.hour.toString().padLeft(2, '0');
    final minutes = value.minute.toString().padLeft(2, '0');
    return '$hours:$minutes';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Statistiques de l’application'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Actualiser',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _StatsError(message: _error!, onRetry: _load)
          : LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 1180
                    ? 3
                    : constraints.maxWidth >= 720
                    ? 2
                    : 1;
                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      _StatsHeader(
                        cse: _profile?.cse ?? '',
                        updatedAt: _timeLabel(_lastUpdated),
                      ),
                      const SizedBox(height: 18),
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: columns,
                          crossAxisSpacing: 14,
                          mainAxisSpacing: 14,
                          mainAxisExtent: 190,
                        ),
                        itemCount: _cards.length,
                        itemBuilder: (_, index) =>
                            _StatsCard(data: _cards[index]),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}

class _StatsMetric {
  const _StatsMetric(this.label, this.value);

  final String label;
  final int value;
}

class _StatsCardData {
  const _StatsCardData({
    required this.title,
    required this.icon,
    required this.color,
    required this.metrics,
  });

  final String title;
  final IconData icon;
  final Color color;
  final List<_StatsMetric> metrics;
}

class _StatsHeader extends StatelessWidget {
  const _StatsHeader({required this.cse, required this.updatedAt});

  final String cse;
  final String updatedAt;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: <Color>[AppColors.bleuPetrole, Color(0xFF12677D)],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Wrap(
        spacing: 14,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: <Widget>[
          const Icon(Icons.insights_outlined, color: Colors.white, size: 38),
          Text(
            'CSE : $cse',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            'Dernière mise à jour : $updatedAt',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.82),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsCard extends StatelessWidget {
  const _StatsCard({required this.data});

  final _StatsCardData data;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: data.color.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(data.icon, color: data.color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    data.title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const Spacer(),
            for (final metric in data.metrics)
              Padding(
                padding: const EdgeInsets.only(top: 7),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        metric.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      metric.value.toString(),
                      style: TextStyle(
                        color: data.color,
                        fontWeight: FontWeight.w900,
                        fontSize: 17,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _StatsError extends StatelessWidget {
  const _StatsError({required this.message, required this.onRetry});

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
            const Icon(Icons.error_outline, color: AppColors.danger, size: 48),
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
