import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../utils/firestore_sanitizer.dart';

class ProfilScreen extends StatelessWidget {
  final String namaGuru;
  const ProfilScreen({super.key, required this.namaGuru});

  Future<void> _rename(
      BuildContext context, String uid, String currentName) async {
    final controller = TextEditingController(text: currentName);
    final save = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
              title: const Text('Ganti Nama'),
              content: TextField(
                  controller: controller,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Nama lengkap')),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(dialogContext, false),
                    child: const Text('Batal')),
                FilledButton(
                    onPressed: () => Navigator.pop(dialogContext, true),
                    child: const Text('Simpan'))
              ],
            ));
    final name = controller.text.trim();
    controller.dispose();
    if (save != true || name.length < 3) return;
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .set(sanitizeFirestoreData({'nama': name}), SetOptions(merge: true));
      if (context.mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Nama berhasil diperbarui.')));
    } catch (error) {
      if (context.mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Nama gagal diperbarui: $error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null)
      return const Center(child: Text('Sesi login tidak ditemukan.'));
    return Scaffold(
      backgroundColor: const Color(0xFFF7FAF8),
      appBar: AppBar(title: const Text('Profil')),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream:
            FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError)
            return Center(
                child: Text('Profil gagal dimuat: ${snapshot.error}'));
          if (!snapshot.hasData)
            return const Center(child: CircularProgressIndicator());
          final data = snapshot.data!.data() ?? <String, dynamic>{};
          final name = (data['nama'] ?? namaGuru).toString();
          return ListView(padding: const EdgeInsets.all(22), children: [
            const SizedBox(height: 14),
            Center(
                child: CircleAvatar(
                    radius: 58,
                    backgroundColor: const Color(0xFFE8F5E9),
                    child: const Icon(Icons.person,
                        size: 62, color: Color(0xFF0D4B2E)))),
            const SizedBox(height: 16),
            Text(name,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0D4B2E))),
            const SizedBox(height: 4),
            Text(
                'Nomor Urut: ${(data['nip'] ?? data['nomor_urut'] ?? data['nomorUrut'] ?? '—')}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.black54)),
            const SizedBox(height: 22),
            Card(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18)),
                child: Column(children: [
                  ListTile(
                      leading: const Icon(Icons.badge_outlined,
                          color: Color(0xFF0D4B2E)),
                      title: const Text('Nomor Urut'),
                      subtitle: Text((data['nip'] ??
                              data['nomor_urut'] ??
                              data['nomorUrut'] ??
                              'Belum tersedia')
                          .toString())),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  ListTile(
                      leading: const Icon(Icons.email_outlined,
                          color: Color(0xFF0D4B2E)),
                      title: const Text('Email'),
                      subtitle: Text(FirebaseAuth.instance.currentUser?.email ??
                          'Tidak tersedia')),
                ])),
            const SizedBox(height: 14),
            Card(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                child: ListTile(
                    leading: const Icon(Icons.edit_outlined,
                        color: Color(0xFF0D4B2E)),
                    title: const Text('Ganti Nama',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _rename(context, uid, name))),
            Card(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                child: ListTile(
                    leading: const Icon(Icons.logout, color: Colors.red),
                    title: const Text('Logout',
                        style: TextStyle(
                            color: Colors.red, fontWeight: FontWeight.w700)),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () async {
                      await FirebaseAuth.instance.signOut();
                    })),
          ]);
        },
      ),
    );
  }
}
