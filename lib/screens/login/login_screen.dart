import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/auth_service.dart';
import '../../utils/firestore_sanitizer.dart';
import '../../utils/theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _nipController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final AuthService _authService = AuthService();

  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _nipController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _prosesLogin() async {
    if (_nipController.text.trim().isEmpty ||
        _passwordController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Nomor Urut/NIP dan Sandi wajib diisi.'),
            backgroundColor: AppTheme.warning),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _authService.login(
        _nipController.text.trim(),
        _passwordController.text.trim(),
      );
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final reference =
            FirebaseFirestore.instance.collection('users').doc(user.uid);
        final profile = await reference.get();
        final data = profile.data() ?? <String, dynamic>{};
        final number = _nipController.text.trim();
        final roster = await FirebaseFirestore.instance
            .collection('users')
            .doc('roster_${number.padLeft(2, '0')}')
            .get();
        final rosterName = (roster.data()?['nama'] ?? '').toString().trim();
        var currentName = (data['nama'] ?? '').toString().trim();
        if ((currentName.isEmpty ||
                currentName.toLowerCase() == 'guru $number' ||
                currentName == 'Tanpa Nama') &&
            rosterName.isNotEmpty) {
          currentName = rosterName;
        }
        if (currentName.isEmpty ||
            currentName.toLowerCase() == 'guru $number' ||
            currentName == 'Tanpa Nama') {
          final controller = TextEditingController();
          final saved = await showDialog<bool>(
            context: context,
            barrierDismissible: false,
            builder: (dialogContext) => AlertDialog(
              title: const Text('Lengkapi Nama'),
              content: TextField(
                  controller: controller,
                  autofocus: true,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                      labelText: 'Masukkan Nama Lengkap Anda')),
              actions: [
                FilledButton(
                    onPressed: () {
                      if (controller.text.trim().length >= 3)
                        Navigator.pop(dialogContext, true);
                    },
                    child: const Text('Simpan'))
              ],
            ),
          );
          if (saved == true) currentName = controller.text.trim();
          controller.dispose();
        }
        final numberInt = int.tryParse(number) ?? 0;
        await reference.set(
            sanitizeFirestoreData({
              'nama': currentName.isNotEmpty ? currentName : rosterName,
              'nip': number,
              'nomor_urut': numberInt,
              'role': numberInt == 1 ? 'admin' : 'guru',
              'isActive': true,
            }),
            SetOptions(merge: true));
      }
      // Jika berhasil, StreamBuilder di main.dart otomatis memindahkan halaman
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: AppTheme.error),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primary,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.1), blurRadius: 10)
                    ],
                  ),
                  child: const Icon(Icons.school,
                      size: 60, color: AppTheme.primary), // Ganti dengan logo
                ),
                const SizedBox(height: 24),
                const Text('AbsenMA',
                    style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white)),
                const Text('Pondok Pesantren Sabilul Hasanah',
                    style: TextStyle(color: Colors.white70, fontSize: 14)),
                const SizedBox(height: 40),
                Card(
                  elevation: 8,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24)),
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Masuk',
                            style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textPrimary)),
                        const SizedBox(height: 24),
                        TextField(
                          controller: _nipController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Nomor Urut / NIP',
                            prefixIcon: Icon(Icons.badge_outlined,
                                color: AppTheme.primary),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          decoration: InputDecoration(
                            labelText: 'Kata Sandi',
                            prefixIcon: const Icon(Icons.lock_outline,
                                color: AppTheme.primary),
                            suffixIcon: IconButton(
                              icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                  color: Colors.grey),
                              onPressed: () => setState(
                                  () => _obscurePassword = !_obscurePassword),
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _prosesLogin,
                            child: _isLoading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                        color: Colors.white, strokeWidth: 2))
                                : const Text('Masuk Aplikasi'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
