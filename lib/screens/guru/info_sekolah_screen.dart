import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../services/storage_service.dart';

class InfoSekolahScreen extends StatefulWidget {
  const InfoSekolahScreen({super.key});

  @override
  State<InfoSekolahScreen> createState() => _InfoSekolahScreenState();
}

class _InfoSekolahScreenState extends State<InfoSekolahScreen> {
  final _vision = TextEditingController();
  final _mission = TextEditingController();
  bool _editing = false;
  bool _saving = false;
  final _storage = StorageService();

  Widget _galleryImage(String? value) {
    final url = value?.trim() ?? '';
    final uri = Uri.tryParse(url);
    if (url.isEmpty ||
        uri == null ||
        (uri.scheme != 'http' && uri.scheme != 'https')) {
      return const SizedBox(
        height: 80,
        child: Center(child: Icon(Icons.image_not_supported_outlined)),
      );
    }
    return Image.network(
      url,
      height: 150,
      width: double.infinity,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => const SizedBox(
        height: 80,
        child: Center(child: Icon(Icons.image_not_supported_outlined)),
      ),
    );
  }

  Future<void> _addMedia(Map<String, dynamic> data) async {
    final result = await FilePicker.pickFiles(type: FileType.any);
    if (result.isEmpty || result.first.path == null) return;
    final file = File(result.first.path!);
    final uploaded = await _storage.uploadGeneralFile(
        file, 'info_sekolah', DateTime.now().millisecondsSinceEpoch.toString());
    final name = uploaded['name'] ?? result.first.name;
    final url = uploaded['url'] ?? '';
    final ext = (uploaded['ext'] ?? '').toLowerCase();
    final field = const {'png', 'jpg', 'jpeg', 'webp'}.contains(ext)
        ? 'galeri'
        : 'lampiran';
    await FirebaseFirestore.instance
        .collection('info_sekolah')
        .doc('utama')
        .set({
      field: FieldValue.arrayUnion([
        {'name': name, 'url': url, 'ext': ext}
      ])
    }, SetOptions(merge: true));
  }

  Future<void> _removeMedia(String field, Map<String, dynamic> item) async {
    await FirebaseFirestore.instance
        .collection('info_sekolah')
        .doc('utama')
        .update({
      field: FieldValue.arrayRemove([item])
    });
  }

  @override
  void dispose() {
    _vision.dispose();
    _mission.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await FirebaseFirestore.instance
          .collection('info_sekolah')
          .doc('utama')
          .set({
        'visi': _vision.text.trim(),
        'misi': _mission.text.trim(),
        'updatedAt': FieldValue.serverTimestamp()
      }, SetOptions(merge: true));
      if (mounted) setState(() => _editing = false);
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Tidak dapat menyimpan info: $error')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return Scaffold(
      backgroundColor: const Color(0xFFF7FAF8),
      appBar: AppBar(title: const Text('Info Sekolah')),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream:
            FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
        builder: (context, roleSnapshot) {
          final isAdmin = (roleSnapshot.data?.data()?['role'] ?? '')
                  .toString()
                  .toLowerCase() ==
              'admin';
          return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('info_sekolah')
                .doc('utama')
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError)
                return Center(
                    child:
                        Text('Info sekolah gagal dimuat: ${snapshot.error}'));
              if (!snapshot.hasData)
                return const Center(child: CircularProgressIndicator());
              final data = snapshot.data!.data() ?? <String, dynamic>{};
              if (!_editing) {
                _vision.text = (data['visi'] ?? '').toString();
                _mission.text = (data['misi'] ?? '').toString();
              }
              return ListView(padding: const EdgeInsets.all(18), children: [
                if (isAdmin)
                  Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                          color: const Color(0xFFE8F5E9),
                          borderRadius: BorderRadius.circular(14)),
                      child: const Text(
                          'Mode Admin: informasi sekolah dapat diedit.',
                          style: TextStyle(
                              color: Color(0xFF0D4B2E),
                              fontWeight: FontWeight.w700))),
                const SizedBox(height: 14),
                _contentCard('Visi', _vision, 'Tuliskan visi sekolah'),
                const SizedBox(height: 12),
                _contentCard('Misi', _mission, 'Tuliskan misi sekolah'),
                const SizedBox(height: 14),
                Card(
                    child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                const Expanded(
                                    child: Text('Galeri dan Lampiran',
                                        style: TextStyle(
                                            fontWeight: FontWeight.w800,
                                            color: Color(0xFF0D4B2E),
                                            fontSize: 17))),
                                if (isAdmin)
                                  IconButton(
                                      onPressed: () => _addMedia(data),
                                      icon: const Icon(
                                          Icons.add_photo_alternate_outlined))
                              ]),
                              for (final item
                                  in (data['galeri'] as List? ?? const [])
                                      .whereType<Map>()
                                      .map((e) => Map<String, dynamic>.from(e)))
                                ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Stack(children: [
                                      _galleryImage(item['url']?.toString()),
                                      if (isAdmin)
                                        Positioned(
                                            right: 6,
                                            top: 6,
                                            child: IconButton(
                                                onPressed: () => _removeMedia(
                                                    'galeri', item),
                                                icon: const Icon(Icons.delete,
                                                    color: Colors.white),
                                                style: IconButton.styleFrom(
                                                    backgroundColor:
                                                        Colors.black54)))
                                    ])),
                              for (final item
                                  in (data['lampiran'] as List? ?? const [])
                                      .whereType<Map>()
                                      .map((e) => Map<String, dynamic>.from(e)))
                                ListTile(
                                    leading: const Icon(
                                        Icons.description_outlined,
                                        color: Color(0xFF0D4B2E)),
                                    title: Text('${item['name'] ?? 'Berkas'}'),
                                    onTap: () => _storage.downloadAndOpen(
                                        '${item['url']}', '${item['name']}'),
                                    trailing: isAdmin
                                        ? IconButton(
                                            onPressed: () =>
                                                _removeMedia('lampiran', item),
                                            icon: const Icon(
                                                Icons.delete_outline,
                                                color: Colors.red))
                                        : null),
                            ]))),
                const SizedBox(height: 18),
                if (isAdmin)
                  SizedBox(
                      height: 50,
                      child: FilledButton.icon(
                          onPressed: _saving
                              ? null
                              : _editing
                                  ? _save
                                  : () => setState(() => _editing = true),
                          icon: Icon(_editing ? Icons.check : Icons.edit),
                          label: Text(_saving
                              ? 'Menyimpan...'
                              : _editing
                                  ? 'Simpan Perubahan'
                                  : 'Edit Informasi'))),
                if (!isAdmin && data.isEmpty)
                  const Center(
                      child: Padding(
                          padding: EdgeInsets.all(20),
                          child: Text(
                              'Informasi sekolah belum ditambahkan admin.'))),
              ]);
            },
          );
        },
      ),
    );
  }

  Widget _contentCard(
          String title, TextEditingController controller, String hint) =>
      Card(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0D4B2E))),
                    const SizedBox(height: 10),
                    TextField(
                        controller: controller,
                        enabled: _editing,
                        maxLines: title == 'Misi' ? 6 : 4,
                        decoration: InputDecoration(
                            hintText: hint,
                            filled: _editing,
                            fillColor: const Color(0xFFF0FDF4),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12))))
                  ])));
}
