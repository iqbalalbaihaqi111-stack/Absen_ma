import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/attendance_model.dart';
import 'storage_service.dart';

class AttendanceService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final StorageService _storageService = StorageService();

  Future<AttendanceModel?> getAbsenHariIni(String userId) async {
    try {
      String tanggalHariIni = DateTime.now().toIso8601String().split('T')[0];
      QuerySnapshot query = await _db
          .collection('absensi')
          .where('userId', isEqualTo: userId)
          .where('tanggal', isEqualTo: tanggalHariIni)
          .get();

      if (query.docs.isNotEmpty) {
        return AttendanceModel.fromMap(
          query.docs.first.data() as Map<String, dynamic>,
          query.docs.first.id,
        );
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<void> clockIn({
    required String userId,
    required String nama,
    required int nomorUrut,
    required String status,
    String alasan = '',
    required double lat,
    required double lon,
    required double akurasi,
    required double jarak,
    File? foto,
  }) async {
    String fotoUrl = '';
    if (foto != null) {
      fotoUrl = await _storageService.uploadFotoAbsen(
          foto, userId, DateTime.now().toIso8601String(), 'masuk');
    }

    String tanggalHariIni = DateTime.now().toIso8601String().split('T')[0];
    final now = DateTime.now();
    final date = now.toIso8601String().split('T')[0];
    await _db.collection('absensi').doc('${userId}_$date').set({
      'userId': userId,
      'nama': nama,
      'nomor_urut': nomorUrut,
      'tanggal': tanggalHariIni,
      'waktuMasuk': FieldValue.serverTimestamp(),
      'status': status,
      'alasan': alasan,
      'isApproved': status != 'Terlambat',
      'latMasuk': lat,
      'lonMasuk': lon,
      'akurasiMasuk': akurasi,
      'jarakMasuk': jarak,
      'fotoMasukUrl': fotoUrl,
    });
  }
}
