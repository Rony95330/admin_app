import 'package:flutter/material.dart';

import '../widgets/side_menu.dart';
import 'dashboard_page.dart';
import 'database_page.dart';
import 'notifications_page.dart';
import 'admin/active_sessions_page.dart';
import 'actuality_list_page.dart';
import 'package:admin_app/pages/revue_presse_list_page.dart';
import 'admin/goodies_admin_page.dart';
import 'admin/questionnaire_editor_page.dart';

// ✅ NEW: pages admin
import 'admin/members_admin_page.dart';
import 'package:admin_app/pages/admin/accords_admin_page.dart';

class AdminHome extends StatefulWidget {
  const AdminHome({super.key});

  @override
  State<AdminHome> createState() => _AdminHomeState();
}

class _AdminHomeState extends State<AdminHome> {
  int _selectedIndex = 0;

  // 🧭 Ordre synchronisé avec SideMenu.menuItems
  // 0: DashboardPage()
  // 1: DatabasePage()
  // 2: NotificationsPage()
  // 3: ActiveSessionsPage()
  // 4: ActualityListPage()
  // 5: RevuePresseListPage()
  // 6: GoodiesAdminPage()
  // 7: QuestionnaireEditorPage()
  // 8: MembersAdminPage()
  // 9: AccordsAdminPage() ✅ AJOUT
  final List<Widget> _pages = const [
    DashboardPage(), // 0
    DatabasePage(), // 1
    NotificationsPage(), // 2
    ActiveSessionsPage(), // 3
    ActualityListPage(), // 4
    RevuePresseListPage(), // 5
    GoodiesAdminPage(), // 6
    QuestionnaireEditorPage(), // 7
    MembersAdminPage(), // 8
    AccordsAdminPage(), // 9 ✅ AJOUT
  ];

  @override
  Widget build(BuildContext context) {
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
            child: (_selectedIndex < _pages.length)
                ? _pages[_selectedIndex]
                : Center(
                    child: Text(
                      'Page inexistante (index=$_selectedIndex, pages=${_pages.length})',
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
