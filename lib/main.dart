import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'utils/theme.dart';
import 'screens/login/login_screen.dart';
import 'screens/guru/guru_main.dart';
import 'screens/admin/admin_main.dart';
import 'models/user_model.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await initializeDateFormatting('id_ID', null);
  runApp(const AbsenMaApp());
}

class AbsenMaApp extends StatelessWidget {
  const AbsenMaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AbsenMA',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
                body: Center(child: CircularProgressIndicator()));
          }
          if (snapshot.hasData && snapshot.data != null) {
            // Cek role dari Firestore berdasarkan UID
            return FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance
                  .collection('users')
                  .doc(snapshot.data!.uid)
                  .get(),
              builder: (context, userSnap) {
                if (userSnap.connectionState == ConnectionState.waiting) {
                  return const Scaffold(
                      body: Center(child: CircularProgressIndicator()));
                }
                if (userSnap.hasData && userSnap.data!.exists) {
                  UserModel user = UserModel.fromMap(
                      userSnap.data!.data() as Map<String, dynamic>,
                      userSnap.data!.id);
                  if (user.isAdmin) {
                    return const AdminMainScreen();
                  }
                }
                return const GuruMainScreen();
              },
            );
          }
          return const LoginScreen();
        },
      ),
    );
  }
}
