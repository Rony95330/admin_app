import 'package:flutter/material.dart';

class SideMenu extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onItemSelected;

  const SideMenu({
    super.key,
    required this.selectedIndex,
    required this.onItemSelected,
  });

  @override
  Widget build(BuildContext context) {
    final items = ["Dashboard", "Base de données", "Notifications"];

    return Container(
      width: 220,
      color: Colors.blueGrey.shade50,
      child: ListView.builder(
        itemCount: items.length,
        itemBuilder: (context, index) {
          final isSelected = index == selectedIndex;
          return ListTile(
            leading: Icon(
              [Icons.home, Icons.storage, Icons.notifications][index],
              color: isSelected ? Colors.blue : Colors.black54,
            ),
            title: Text(
              items[index],
              style: TextStyle(
                color: isSelected ? Colors.blue : Colors.black87,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            selected: isSelected,
            onTap: () => onItemSelected(index),
          );
        },
      ),
    );
  }
}
