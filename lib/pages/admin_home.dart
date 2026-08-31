import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../theme/brand_colors.dart';
import '../widgets/side_menu.dart';
import 'actuality_list_page.dart';
import 'admin/accords_admin_page.dart';
import 'admin/active_sessions_page.dart';
import 'admin/adh_exchange_admin_page.dart';
import 'admin/admin_collections.dart';
import 'admin/admin_collections_hub_page.dart';
import 'admin/admin_election_campaigns_page.dart';
import 'admin/application_stats_page.dart';
import 'admin/coordinator_messages_admin_page.dart';
import 'admin/election_dashboard_page.dart';
import 'admin/goodies_admin_page.dart';
import 'admin/home_banners_admin_page.dart';
import 'admin/managed_collection_page.dart';
import 'admin/members_admin_page.dart';
import 'admin/questionnaire_editor_page.dart';
import 'admin/rh_ai_admin_page.dart';
import 'admin/service_availability_admin_page.dart';
import 'dashboard_page.dart';
import 'database_page.dart';
import 'notifications_page.dart';
import 'revue_presse_list_page.dart';

import 'package:admin_app/pages/admin/podcast_voice_admin_page.dart';

class _AdminDestination {
  const _AdminDestination({required this.menu, required this.page});

  final AdminMenuItem menu;
  final Widget page;
}

class AdminHome extends StatefulWidget {
  const AdminHome({super.key});

  @override
  State<AdminHome> createState() => _AdminHomeState();
}

class _AdminHomeState extends State<AdminHome> {
  int _selectedIndex = 0;

  static const List<_AdminDestination> _baseDestinations = <_AdminDestination>[
    _AdminDestination(
      menu: AdminMenuItem(
        icon: Icons.dashboard_outlined,
        label: 'Tableau de bord',
      ),
      page: DashboardPage(),
    ),
    _AdminDestination(
      menu: AdminMenuItem(icon: Icons.insights_outlined, label: 'Statistiques'),
      page: ApplicationStatsPage(),
    ),
    _AdminDestination(
      menu: AdminMenuItem(
        icon: Icons.manage_accounts_outlined,
        label: 'Comptes utilisateurs',
      ),
      page: DatabasePage(),
    ),
    _AdminDestination(
      menu: AdminMenuItem(
        icon: Icons.notifications_active_outlined,
        label: 'Notifications',
      ),
      page: NotificationsPage(),
    ),
    _AdminDestination(
      menu: AdminMenuItem(
        icon: Icons.campaign_outlined,
        label: 'Bandeaux d’accueil',
      ),
      page: HomeBannersAdminPage(),
    ),
    _AdminDestination(
      menu: AdminMenuItem(
        icon: Icons.format_quote_rounded,
        label: 'Mot du coordinateur',
      ),
      page: CoordinatorMessagesAdminPage(),
    ),
    _AdminDestination(
      menu: AdminMenuItem(
        icon: Icons.devices_outlined,
        label: 'Sessions actives',
      ),
      page: ActiveSessionsPage(),
    ),
    _AdminDestination(
      menu: AdminMenuItem(
        icon: Icons.article_outlined,
        label: 'Actualités publiées',
      ),
      page: ActualityListPage(),
    ),
    _AdminDestination(
      menu: AdminMenuItem(
        icon: Icons.picture_as_pdf_outlined,
        label: 'Revue de presse',
      ),
      page: RevuePresseListPage(),
    ),
    _AdminDestination(
      menu: AdminMenuItem(icon: Icons.card_giftcard_outlined, label: 'Goodies'),
      page: GoodiesAdminPage(),
    ),
    _AdminDestination(
      menu: AdminMenuItem(icon: Icons.poll_outlined, label: 'Questionnaires'),
      page: QuestionnaireEditorPage(),
    ),
    _AdminDestination(
      menu: AdminMenuItem(
        icon: Icons.groups_2_outlined,
        label: 'Représentants',
      ),
      page: MembersAdminPage(),
    ),
    _AdminDestination(
      menu: AdminMenuItem(icon: Icons.folder_copy_outlined, label: 'Accords'),
      page: AccordsAdminPage(),
    ),
    _AdminDestination(
      menu: AdminMenuItem(
        icon: Icons.psychology_alt_outlined,
        label: 'Assistant RH IA',
      ),
      page: RhAiAdminPage(),
    ),
    _AdminDestination(
      menu: AdminMenuItem(icon: Icons.podcasts_outlined, label: 'Podcasts'),
      page: ManagedCollectionPage(definition: AdminCollections.podcasts),
    ),
    _AdminDestination(
      menu: AdminMenuItem(
        icon: Icons.workspace_premium_outlined,
        label: 'Attestations',
      ),
      page: ManagedCollectionPage(definition: AdminCollections.attestations),
    ),
    _AdminDestination(
      menu: AdminMenuItem(icon: Icons.tune_outlined, label: 'Référentiels'),
      page: AdminCollectionsHubPage(
        title: 'Référentiels de l’application',
        subtitle: 'Éléments de configuration lus directement par CFDT V2.',
        collections: <AdminCollectionDefinition>[
          AdminCollections.about,
          AdminCollections.sectors,
          AdminCollections.qrAssets,
          AdminCollections.commissions,
        ],
      ),
    ),
    _AdminDestination(
      menu: AdminMenuItem(
        icon: Icons.rss_feed_outlined,
        label: 'Sources des fils',
      ),
      page: AdminCollectionsHubPage(
        title: 'Sources d’actualités',
        subtitle:
            'Sources serveur des fils aérien et juridique, avec état du dernier chargement.',
        collections: <AdminCollectionDefinition>[
          AdminCollections.aviationSources,
          AdminCollections.labourSources,
        ],
      ),
    ),
    _AdminDestination(
      menu: AdminMenuItem(
        icon: Icons.calendar_month_outlined,
        label: 'Mandats',
      ),
      page: ManagedCollectionPage(definition: AdminCollections.mandates),
    ),
    _AdminDestination(
      menu: AdminMenuItem(
        icon: Icons.forum_outlined,
        label: 'Demandes adhérents',
      ),
      page: AdhExchangeAdminPage(),
    ),
    _AdminDestination(
      menu: AdminMenuItem(icon: Icons.how_to_vote_outlined, label: 'Élections'),
      page: ElectionDashboardPage(),
    ),
    _AdminDestination(
      menu: AdminMenuItem(
        icon: Icons.ballot_outlined,
        label: 'Campagnes électorales',
      ),
      page: AdminElectionCampaignsPage(),
    ),

    _AdminDestination(
      menu: AdminMenuItem(
        icon: Icons.record_voice_over_outlined,
        label: 'Voix Podcast',
      ),
      page: PodcastVoiceAdminPage(),
    ),
  ];

  bool _isSuperuser = false;

  @override
  void initState() {
    super.initState();
    _loadSuperuserAccess();
  }

  Future<void> _loadSuperuserAccess() async {
    try {
      final dynamic role = await Supabase.instance.client.rpc(
        'security_current_role',
      );

      if (!mounted) return;

      setState(() {
        _isSuperuser = role?.toString() == 'supuser';
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _isSuperuser = false;
      });
    }
  }

  List<_AdminDestination> get _destinations => <_AdminDestination>[
    ..._baseDestinations,
    if (_isSuperuser)
      const _AdminDestination(
        menu: AdminMenuItem(
          icon: Icons.health_and_safety_outlined,
          label: 'Disponibilité du service',
        ),
        page: ServiceAvailabilityAdminPage(),
      ),
  ];

  List<AdminMenuItem> get _menuItems =>
      _destinations.map((destination) => destination.menu).toList();

  void _select(int index) {
    if (index < 0 || index >= _destinations.length) return;
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 920;
    final page = _destinations[_selectedIndex].page;

    if (compact) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: AppColors.bleuPetrole,
          foregroundColor: Colors.white,
          title: Text(_destinations[_selectedIndex].menu.label),
        ),
        drawer: Drawer(
          width: 284,
          child: SideMenu(
            selectedIndex: _selectedIndex,
            onItemSelected: _select,
            items: _menuItems,
            closeOnSelect: true,
          ),
        ),
        body: page,
      );
    }

    return Scaffold(
      body: Row(
        children: <Widget>[
          SideMenu(
            selectedIndex: _selectedIndex,
            onItemSelected: _select,
            items: _menuItems,
          ),
          const VerticalDivider(width: 1),
          Expanded(child: page),
        ],
      ),
    );
  }
}
