import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../pages/login_page.dart';
import '../theme/brand_colors.dart';

class AdminMenuItem {
  const AdminMenuItem({required this.icon, required this.label});

  final IconData icon;
  final String label;
}

class SideMenu extends StatelessWidget {
  const SideMenu({
    super.key,
    required this.selectedIndex,
    required this.onItemSelected,
    required this.items,
    this.closeOnSelect = false,
  });

  final int selectedIndex;
  final ValueChanged<int> onItemSelected;
  final List<AdminMenuItem> items;
  final bool closeOnSelect;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      width: 284,
      color: Colors.white,
      child: SafeArea(
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
              child: Row(
                children: <Widget>[
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: AppColors.orange,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    alignment: Alignment.center,
                    child: const Text(
                      'CFDT',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Console admin',
                          style: text.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: AppColors.anthracite,
                          ),
                        ),
                        Text(
                          'Air France',
                          style: text.bodySmall?.copyWith(
                            color: AppColors.bleuPetrole,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 12,
                ),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index];
                  final selected = selectedIndex == index;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 3),
                    child: Material(
                      color: selected
                          ? AppColors.orange.withValues(alpha: 0.11)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(13),
                      child: ListTile(
                        dense: true,
                        minLeadingWidth: 24,
                        leading: Icon(
                          item.icon,
                          color: selected
                              ? AppColors.orange
                              : AppColors.anthracite.withValues(alpha: 0.72),
                        ),
                        title: Text(
                          item.label,
                          style: text.bodyMedium?.copyWith(
                            color: selected
                                ? AppColors.orange
                                : AppColors.anthracite,
                            fontWeight: selected
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                        ),
                        selected: selected,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(13),
                        ),
                        onTap: () {
                          onItemSelected(index);
                          if (closeOnSelect) Navigator.maybePop(context);
                        },
                      ),
                    ),
                  );
                },
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(14),
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.danger,
                  side: BorderSide(
                    color: AppColors.danger.withValues(alpha: 0.45),
                  ),
                  minimumSize: const Size.fromHeight(46),
                ),
                icon: const Icon(Icons.logout),
                label: const Text('Se déconnecter'),
                onPressed: () async {
                  await Supabase.instance.client.auth.signOut();
                  if (!context.mounted) return;
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute<void>(builder: (_) => const LoginPage()),
                    (_) => false,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
