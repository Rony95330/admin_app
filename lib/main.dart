import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'pages/dashboard_page.dart';
import 'pages/database_page.dart';
import 'pages/notifications_page.dart';
import 'widgets/side_menu.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ⚡️ Initialisation Supabase
  await Supabase.initialize(
    url:
        'https://qfvogtbdqotbvmpxalwx.supabase.co', // ← remplace par ton URL Supabase
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFmdm9ndGJkcW90YnZtcHhhbHd4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTQ1NjgyNzgsImV4cCI6MjA3MDE0NDI3OH0.noHGv6Oa70cKfKIefPqU_feufiYB5JOwyWLo2H4Pp3A', // ← remplace par ta clé anonyme
  );

  runApp(const AdminApp());
}

class AdminApp extends StatelessWidget {
  const AdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Admin Panel',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const AdminHome(),
    );
  }
}

class AdminHome extends StatefulWidget {
  const AdminHome({super.key});

  @override
  State<AdminHome> createState() => _AdminHomeState();
}

class _AdminHomeState extends State<AdminHome> {
  int _selectedIndex = 0;

  final List<Widget> _pages = const [
    DashboardPage(),
    DatabasePage(),
    NotificationsPage(),
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
          Expanded(child: _pages[_selectedIndex]),
        ],
      ),
    );
  }
}
