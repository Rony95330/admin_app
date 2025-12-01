import 'package:flutter/material.dart';

import '../widgets/side_menu.dart';
import 'dashboard_page.dart';
import 'database_page.dart';
import 'notifications_page.dart';
import 'admin/active_sessions_page.dart';
import 'actuality_list_page.dart';
import 'package:admin_app/pages/revue_presse_list_page.dart';
import 'admin/goodies_admin_page.dart'; // 👈 NEW
import 'admin/questionnaire_editor_page.dart';

class AdminHome extends StatefulWidget {
  const AdminHome({super.key});

  @override
  State<AdminHome> createState() => _AdminHomeState();
}

class _AdminHomeState extends State<AdminHome> {
  int _selectedIndex = 0;

  final List<Widget> _pages = const [
    DashboardPage(), // 0
    DatabasePage(), // 1
    NotificationsPage(), // 2
    ActiveSessionsPage(), // 3
    ActualityListPage(), // 4
    RevuePresseListPage(), // 5
    GoodiesAdminPage(), // 6 🆕
    QuestionnaireEditorPage(), // 7
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: Row(
        children: [
          SideMenu(
            selectedIndex: _selectedIndex,
            onItemSelected: (index) {
              setState(() => _selectedIndex = index);
            },
          ),
          Expanded(
            child: Container(
              color: cs.surface,
              child: (_selectedIndex < _pages.length)
                  ? _pages[_selectedIndex]
                  : const Center(child: Text('Page inexistante')),
            ),
          ),
        ],
      ),
    );
  }
}
