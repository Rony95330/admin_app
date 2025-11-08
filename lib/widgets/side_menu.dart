import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../pages/login_page.dart';

class SideMenu extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onItemSelected;

  const SideMenu({
    super.key,
    required this.selectedIndex,
    required this.onItemSelected,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    final menuItems = [
      {'icon': Icons.dashboard_outlined, 'label': 'Tableau de bord'},
      {'icon': Icons.storage_rounded, 'label': 'Base de données'},
      {'icon': Icons.notifications_active_outlined, 'label': 'Notifications'},
      {'icon': Icons.people_outline, 'label': 'Sessions actives'},
      {'icon': Icons.list_alt_outlined, 'label': 'Actualités publiées'}, // 📰
    ];

    return Container(
      width: 250,
      color: cs.primary.withOpacity(0.05),
      child: Column(
        children: [
          const SizedBox(height: 40),

          // 🔹 En-tête / logo
          Text(
            'CFE-CGC\nAdmin Console',
            textAlign: TextAlign.center,
            style: text.titleLarge?.copyWith(
              color: cs.primary,
              fontWeight: FontWeight.bold,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 32),

          // 🔹 Liste de navigation
          Expanded(
            child: ListView.builder(
              itemCount: menuItems.length,
              itemBuilder: (context, index) {
                final item = menuItems[index];
                return _buildMenuButton(
                  context,
                  index,
                  item['icon'] as IconData,
                  item['label'] as String,
                );
              },
            ),
          ),

          const Divider(thickness: 0.8, height: 1),
          const SizedBox(height: 12),

          // 🔹 Déconnexion
          Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: cs.errorContainer.withOpacity(0.85),
                foregroundColor: cs.onErrorContainer,
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.logout),
              label: const Text('Se déconnecter'),
              onPressed: () async {
                await Supabase.instance.client.auth.signOut();
                if (context.mounted) {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginPage()),
                    (route) => false,
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuButton(
    BuildContext context,
    int index,
    IconData icon,
    String label,
  ) {
    final cs = Theme.of(context).colorScheme;
    final isSelected = index == selectedIndex;

    return ListTile(
      leading: Icon(
        icon,
        color: isSelected ? cs.primary : cs.onSurface.withOpacity(0.7),
      ),
      title: Text(
        label,
        style: TextStyle(
          color: isSelected ? cs.primary : cs.onSurface.withOpacity(0.8),
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
      selected: isSelected,
      selectedTileColor: cs.primary.withOpacity(0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      onTap: () => onItemSelected(index),
    );
  }
}
