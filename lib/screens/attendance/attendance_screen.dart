import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../utils/theme.dart';
import '../../services/location_service.dart';
import '../../services/attendance_service.dart';
import '../../models/attendance_model.dart';

class AttendanceScreen extends StatefulWidget {
  final String namaGuru;
  const AttendanceScreen({super.key, required this.namaGuru});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  final LocationService _locationService = LocationService();
  final AttendanceService _attendanceService = AttendanceService();

  File? _imageFile;
  bool _isLoading = false;
  AttendanceModel? _statusAbsenHariIni;
  bool _isCheckingStatus = true;

  @override
  void initState() {
    super.initState();
    _cekStatusAbsen();
  }

  Future<void> _cekStatusAbsen() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      AttendanceModel? absen =
          await _attendanceService.getAbsenHariIni(user.uid);
      if (!mounted) return;
      setState(() {
        _statusAbsenHariIni = absen;
        _isCheckingStatus = false;
      });
    } else {
      if (mounted) setState(() => _isCheckingStatus = false);
    }
  }

  Future<void> _ambilFotoSelfie() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.front,
      imageQuality: 50,
    );

    if (pickedFile != null && mounted) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });
    }
  }

  Future<void> _kirimAbsenMasuk() async {
    final sekarang = DateTime.now();
    if (sekarang.hour < 6) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content:
              Text('Belum waktunya absen. Absensi dibuka mulai pukul 06.00.')));
      return;
    }
    if (_imageFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Mohon ambil foto selfie terlebih dahulu!'),
            backgroundColor: AppTheme.warning),
      );
      return;
    }

    String alasan = '';
    final terlambat =
        sekarang.hour > 8 || (sekarang.hour == 8 && sekarang.minute > 0);
    if (terlambat) {
      final controller = TextEditingController();
      final submitted = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) => AlertDialog(
                title: const Text('Alasan Keterlambatan'),
                content: TextField(
                    controller: controller,
                    maxLines: 3,
                    decoration: const InputDecoration(
                        labelText: 'Masukkan alasan keterlambatan')),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(dialogContext, false),
                      child: const Text('Batal')),
                  FilledButton(
                      onPressed: () {
                        if (controller.text.trim().isNotEmpty)
                          Navigator.pop(dialogContext, true);
                      },
                      child: const Text('Kirim'))
                ],
              ));
      alasan = controller.text.trim();
      controller.dispose();
      if (submitted != true || alasan.isEmpty || !mounted) return;
    }

    setState(() => _isLoading = true);

    try {
      // 1. Cek Lokasi GPS & Radius 2 KM
      Map<String, dynamic> gpsResult = await _locationService.cekLokasiAbsen();
      if (!gpsResult['valid']) {
        throw Exception(gpsResult['pesan']);
      }

      User? authUser = FirebaseAuth.instance.currentUser;
      if (authUser == null)
        throw Exception('Sesi login berakhir. Silakan login ulang.');

      final profile = await FirebaseFirestore.instance
          .collection('users')
          .doc(authUser.uid)
          .get();
      final userData = profile.data() ?? <String, dynamic>{};
      final number = int.tryParse(
              '${userData['nomor_urut'] ?? userData['nomorUrut'] ?? userData['nip'] ?? ''}') ??
          0;
      final status = terlambat ? 'Terlambat' : 'Tepat Waktu';

      // 3. Simpan ke Database
      await _attendanceService.clockIn(
        userId: authUser.uid,
        nama: widget.namaGuru,
        nomorUrut: number,
        status: status,
        alasan: alasan,
        lat: gpsResult['latitude'],
        lon: gpsResult['longitude'],
        akurasi: gpsResult['accuracy'],
        jarak: gpsResult['jarak'],
        foto: _imageFile,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Absen Masuk berhasil dicatat!'),
            backgroundColor: AppTheme.success),
      );

      _cekStatusAbsen();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Gagal Absen: $e'), backgroundColor: AppTheme.error),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Kehadiran Harian')),
      body: _isCheckingStatus
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  // Jika sudah absen hari ini
                  if (_statusAbsenHariIni != null) ...[
                    const Spacer(),
                    const Icon(Icons.check_circle_rounded,
                        size: 80, color: AppTheme.success),
                    const SizedBox(height: 16),
                    const Text('Anda sudah melakukan absensi hari ini!',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary)),
                    const SizedBox(height: 8),
                    Text('Status: ${_statusAbsenHariIni!.status}',
                        style: const TextStyle(
                            fontSize: 16,
                            color: AppTheme.primary,
                            fontWeight: FontWeight.w600)),
                    const Spacer(),
                  ] else ...[
                    // Jika belum absen
                    const Text(
                        'Silakan ambil foto selfie untuk melakukan absensi masuk.',
                        style: TextStyle(
                            fontSize: 14, color: AppTheme.textSecondary),
                        textAlign: TextAlign.center),
                    const SizedBox(height: 20),

                    // Kotak Kamera Selfie
                    GestureDetector(
                      onTap: _ambilFotoSelfie,
                      child: Container(
                        height: 250,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                              color: AppTheme.primary.withOpacity(0.3),
                              width: 2),
                        ),
                        child: _imageFile != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(14),
                                child:
                                    Image.file(_imageFile!, fit: BoxFit.cover))
                            : const Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.camera_alt_rounded,
                                      size: 50, color: AppTheme.primary),
                                  SizedBox(height: 8),
                                  Text('Ketuk untuk Ambil Foto Selfie',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.primary)),
                                ],
                              ),
                      ),
                    ),
                    const Spacer(),

                    // Tombol Kirim Absen
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isLoading ? null : _kirimAbsenMasuk,
                        icon: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2))
                            : const Icon(Icons.location_on_rounded,
                                color: Colors.white),
                        label: Text(_isLoading
                            ? 'Memeriksa GPS & Mengirim...'
                            : 'Kirim Absen Masuk Sekarang'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}
