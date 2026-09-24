import 'package:flutter/material.dart';
import '../../utils/theme.dart';
import '../guru/beranda_guru.dart';
import '../guru/chat_screen.dart';
import '../guru/profil_screen.dart'; // Akan kita buatkan juga sebentar
import 'admin_rekap_screen.dart';
import 'admin_panel_screen.dart';

class AdminMainScreen extends StatefulWidget {
  const AdminMainScreen({super.key});

  @override
  State<AdminMainScreen> createState() => _AdminMainScreenState();
}

class _AdminMainScreenState extends State<AdminMainScreen> {
  int _currentIndex = 0;

  final List<Widget> _pages = [
    const BerandaGuruScreen(),
    const ChatScreen(namaPengguna: 'Kepala Sekolah (Admin)', isAdmin: true),
    const AdminRekapScreen(),
    const AdminPanelScreen(),
    const ProfilScreen(namaGuru: 'Kepala Sekolah (Admin)'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_currentIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          backgroundColor: Colors.white,
          selectedItemColor: AppTheme.primary,
          unselectedItemColor: AppTheme.textSecondary,
          type: BottomNavigationBarType.fixed,
          elevation: 0,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home_filled), label: 'Beranda'),
            BottomNavigationBarItem(icon: Icon(Icons.chat_bubble), label: 'Chat'),
            BottomNavigationBarItem(icon: Icon(Icons.bar_chart_rounded), label: 'Rekap'),
            BottomNavigationBarItem(icon: Icon(Icons.admin_panel_settings_rounded), label: 'Kelola'),
            BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profil'),
          ],
        ),
      ),
    );
  }
}