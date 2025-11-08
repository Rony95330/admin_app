import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'theme/app_theme.dart';
import 'pages/login_page.dart';
import 'pages/admin_home.dart'; // ✅ nouvelle import

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://qfvogtbdqotbvmpxalwx.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFmdm9ndGJkcW90YnZtcHhhbHd4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTQ1NjgyNzgsImV4cCI6MjA3MDE0NDI3OH0.noHGv6Oa70cKfKIefPqU_feufiYB5JOwyWLo2H4Pp3A',
  );

  runApp(const AdminApp());
}

class AdminApp extends StatelessWidget {
  const AdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Console CFE-CGC Air France',
      theme: buildLightTheme(),
      darkTheme: buildDarkTheme(),
      themeMode: ThemeMode.light,
      home: Supabase.instance.client.auth.currentUser == null
          ? const LoginPage()
          : const AdminHome(), // ✅ redirection auto
    );
  }
}
