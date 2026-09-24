import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../utils/theme.dart';

class JurnalScreen extends StatefulWidget {
  final String namaGuru;
  const JurnalScreen({super.key, required this.namaGuru});

  @override
  State<JurnalScreen> createState() => _JurnalScreenState();
}

class _JurnalScreenState extends State<JurnalScreen> {
  final TextEditingController _kelasController = TextEditingController();
  final TextEditingController _mapelController = TextEditingController();
  final TextEditingController _materiController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _kelasController.dispose();
    _mapelController.dispose();
    _materiController.dispose();
    super.dispose();
  }

  Future<void> _kirimJurnal() async {
    if (_kelasController.text.trim().isEmpty || 
        _mapelController.text.trim().isEmpty || 
        _materiController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Semua kolom wajib diisi!'), backgroundColor: AppTheme.warning),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      User? user = FirebaseAuth.instance.currentUser;
      await FirebaseFirestore.instance.collection('jurnal_mengajar').add({
        'userId': user?.uid ?? '',
        'nama': widget.namaGuru,
        'kelas': _kelasController.text.trim(),
        'mapel': _mapelController.text.trim(),
        'materi': _materiController.text.trim(),
        'waktu': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Jurnal berhasil disimpan ke sistem!'), backgroundColor: AppTheme.success),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal menyimpan jurnal: $e'), backgroundColor: AppTheme.error),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('E-Jurnal Mengajar')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Catat Laporan Kegiatan Belajar Mengajar', 
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.textPrimary)),
            const SizedBox(height: 20),
            TextField(
              controller: _mapelController,
              decoration: const InputDecoration(
                labelText: 'Mata Pelajaran',
                prefixIcon: Icon(Icons.book_outlined, color: AppTheme.primary),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _kelasController,
              decoration: const InputDecoration(
                labelText: 'Kelas (Cth: X.1 / XI Agama)',
                prefixIcon: Icon(Icons.class_outlined, color: AppTheme.primary),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _materiController,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Ringkasan Materi / Topik Pembahasan',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _kirimJurnal,
                child: _isLoading 
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('SIMPAN JURNAL'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}