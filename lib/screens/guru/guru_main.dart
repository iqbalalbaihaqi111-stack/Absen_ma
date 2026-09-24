import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../utils/theme.dart';
import 'beranda_guru.dart';
import 'chat_screen.dart';
import 'profil_screen.dart';
import 'riwayat_screen.dart';

class GuruMainScreen extends StatefulWidget {
  const GuruMainScreen({super.key});

  @override
  State<GuruMainScreen> createState() => _GuruMainScreenState();
}

class _GuruMainScreenState extends State<GuruMainScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const BerandaGuruScreen();
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream:
          FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
      builder: (context, snapshot) {
        final name = (snapshot.data?.data()?['nama'] ?? 'Guru').toString();
        final pages = <Widget>[
          const BerandaGuruScreen(),
          const RiwayatScreen(),
          ChatScreen(namaPengguna: name, isAdmin: false),
          ProfilScreen(namaGuru: name),
        ];
        return Scaffold(
          body: pages[_currentIndex],
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: (index) => setState(() => _currentIndex = index),
            backgroundColor: Colors.white,
            selectedItemColor: AppTheme.primary,
            unselectedItemColor: AppTheme.textSecondary,
            type: BottomNavigationBarType.fixed,
            items: const [
              BottomNavigationBarItem(
                  icon: Icon(Icons.home_filled), label: 'Beranda'),
              BottomNavigationBarItem(
                  icon: Icon(Icons.access_time_filled), label: 'Riwayat'),
              BottomNavigationBarItem(
                  icon: Icon(Icons.chat_bubble), label: 'Chat'),
              BottomNavigationBarItem(
                  icon: Icon(Icons.person), label: 'Profil'),
            ],
          ),
        );
      },
    );
  }
}
