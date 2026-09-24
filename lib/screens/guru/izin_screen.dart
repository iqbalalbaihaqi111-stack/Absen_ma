import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../utils/theme.dart';
import '../../services/storage_service.dart';

class IzinScreen extends StatefulWidget {
  final String namaGuru;
  const IzinScreen({super.key, required this.namaGuru});

  @override
  State<IzinScreen> createState() => _IzinScreenState();
}

class _IzinScreenState extends State<IzinScreen> {
  final StorageService _storageService = StorageService();
  String _jenis = 'Sakit';
  File? _fotoBukti;
  final TextEditingController _ketController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _ketController.dispose();
    super.dispose();
  }

  Future<void> _ambilFoto() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 50,
    );
    if (pickedFile != null && mounted) {
      setState(() => _fotoBukti = File(pickedFile.path));
    }
  }

  Future<void> _kirimIzin() async {
    if (_ketController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Keterangan izin/sakit wajib diisi!'),
          backgroundColor: AppTheme.warning,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      User? user = FirebaseAuth.instance.currentUser;
      String requestId = DateTime.now().millisecondsSinceEpoch.toString();
      String fotoUrl = '';

      if (_fotoBukti != null && user != null) {
        fotoUrl = await _storageService.uploadBuktiIzin(
          _fotoBukti!,
          user.uid,
          requestId,
        );
      }

      await FirebaseFirestore.instance
          .collection('izin_sakit')
          .doc(requestId)
          .set({
            'userId': user?.uid ?? '',
            'nama': widget.namaGuru,
            'jenis': _jenis,
            'alasan': _ketController.text.trim(),
            'fotoUrl': fotoUrl,
            'status': 'Menunggu',
            'waktu': FieldValue.serverTimestamp(),
          });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pengajuan izin berhasil dikirim ke Admin!'),
          backgroundColor: AppTheme.success,
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal mengirim izin: $e'),
          backgroundColor: AppTheme.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Form Izin / Sakit')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Pilih Jenis Pengajuan',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _jenis,
              decoration: const InputDecoration(
                prefixIcon: Icon(
                  Icons.category_outlined,
                  color: AppTheme.primary,
                ),
              ),
              items: <String>[
                'Sakit',
                'Izin Berhalangan',
              ].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
              onChanged: (v) => setState(() => _jenis = v!),
            ),
            const SizedBox(height: 20),
            const Text(
              'Bukti Pendukung (Surat Dokter / Foto)',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _ambilFoto,
              child: Container(
                height: 180,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  border: Border.all(color: Colors.grey.shade300, width: 1.5),
                  borderRadius: BorderRadius.circular(16),
                  image: _fotoBukti != null
                      ? DecorationImage(
                          image: FileImage(_fotoBukti!),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: _fotoBukti == null
                    ? const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.camera_alt_rounded,
                            size: 40,
                            color: Colors.grey,
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Ketuk untuk ambil foto bukti',
                            style: TextStyle(
                              color: Colors.grey,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      )
                    : null,
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _ketController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Keterangan / Alasan Lengkap',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.warning,
                ),
                onPressed: _isLoading ? null : _kirimIzin,
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text('KIRIM PENGAJUAN'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
