import 'package:flutter/material.dart';
import 'home_content.dart';       // 1. Sekme (Ana Sayfa)
import 'chat_list_tab.dart';      // 2. Sekme (Sohbetler)
import 'mestler_screen.dart';     // 3. Sekme (Mestler Kütüphanesi - MENÜ)
import 'profile_tab.dart';        // 4. Sekme (Profil)

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _selectedIndex = 0;
  final Color mainColor = const Color(0xFFFF5A5F);

  // Sekmelerin Listesi
  final List<Widget> _screens = [
    const HomeContent(),   // Ana Sayfa
    const ChatListTab(),   // Sohbet Listesi
    const MestlerScreen(), // Mestler Kütüphanesi (Artık parametresiz, hata vermez)
    const ProfileTab(),    // Profil
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D11),
      
      // GÖVDE (Seçilen sekmeyi gösterir)
      body: _screens[_selectedIndex],

      // ALT MENÜ
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Colors.white10, width: 0.5)),
        ),
        child: BottomNavigationBar(
          backgroundColor: const Color(0xFF0D0D11),
          type: BottomNavigationBarType.fixed,
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
          selectedItemColor: mainColor,
          unselectedItemColor: Colors.grey,
          showSelectedLabels: true,
          showUnselectedLabels: true,
          selectedFontSize: 12,
          unselectedFontSize: 12,
          items: [
            _buildNavItem(Icons.home_filled, "Ana Sayfa", 0),
            _buildNavItem(Icons.chat_bubble_outline, "Sohbetler", 1),
            _buildNavItem(Icons.grid_view, "Mestler", 2), // Kütüphane ikonu
            _buildNavItem(Icons.person_outline, "Profil", 3),
          ],
        ),
      ),
    );
  }

  // Menü elemanları için özel tasarım
  BottomNavigationBarItem _buildNavItem(IconData icon, String label, int index) {
    bool isSelected = _selectedIndex == index;
    return BottomNavigationBarItem(
      icon: Container(
        padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 20),
        decoration: isSelected 
            ? BoxDecoration(
                color: mainColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: mainColor.withOpacity(0.5))
              )
            : null,
        child: Icon(icon, color: isSelected ? mainColor : Colors.grey),
      ),
      label: label,
    );
  }
}