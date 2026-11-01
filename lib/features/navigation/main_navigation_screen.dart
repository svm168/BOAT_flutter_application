import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../bikes/screens/bike_list_screen.dart';
import '../scanner/screens/mesh_status_screen.dart';
import '../scanner/screens/nfc_scanner_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    BikeListScreen(),
    NfcScannerScreen(),
    MeshStatusScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.border, width: 1)),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          selectedItemColor: AppColors.moss,
          unselectedItemColor: AppColors.inkMuted,
          backgroundColor: Colors.white,
          type: BottomNavigationBarType.fixed,
          onTap: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.pedal_bike_outlined),
              activeIcon: Icon(Icons.directions_bike_rounded),
              label: 'Bicycles',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.nfc_outlined),
              activeIcon: Icon(Icons.nfc_rounded),
              label: 'Scan NFC',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.radar_outlined),
              activeIcon: Icon(Icons.radar_rounded),
              label: 'Mesh Diagnostics',
            ),
          ],
        ),
      ),
    );
  }
}
