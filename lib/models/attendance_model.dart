import 'package:cloud_firestore/cloud_firestore.dart';

class AttendanceModel {
  final String? id;
  final String userId;
  final String nama;
  final String tanggal; 
  final DateTime? waktuMasuk;
  final DateTime? waktuPulang;
  final String status; // Hadir, Telat, Alpha
  final int menitTelat;
  
  final String? fotoMasukUrl;
  final double? latMasuk;
  final double? lonMasuk;
  final double? akurasiMasuk;
  final double? jarakMasuk;

  final String? fotoPulangUrl;
  final double? latPulang;
  final double? lonPulang;
  final double? akurasiPulang;
  final double? jarakPulang;

  AttendanceModel({
    this.id,
    required this.userId,
    required this.nama,
    required this.tanggal,
    this.waktuMasuk,
    this.waktuPulang,
    required this.status,
    this.menitTelat = 0,
    this.fotoMasukUrl,
    this.latMasuk,
    this.lonMasuk,
    this.akurasiMasuk,
    this.jarakMasuk,
    this.fotoPulangUrl,
    this.latPulang,
    this.lonPulang,
    this.akurasiPulang,
    this.jarakPulang,
  });

  factory AttendanceModel.fromMap(Map<String, dynamic> data, String documentId) {
    return AttendanceModel(
      id: documentId,
      userId: data['userId'] ?? '',
      nama: data['nama'] ?? 'Tanpa Nama',
      tanggal: data['tanggal'] ?? '',
      waktuMasuk: data['waktuMasuk'] != null ? (data['waktuMasuk'] as Timestamp).toDate() : null,
      waktuPulang: data['waktuPulang'] != null ? (data['waktuPulang'] as Timestamp).toDate() : null,
      status: data['status'] ?? 'Alpha',
      menitTelat: data['menitTelat'] ?? 0,
      fotoMasukUrl: data['fotoMasukUrl'],
      latMasuk: data['latMasuk'],
      lonMasuk: data['lonMasuk'],
      akurasiMasuk: data['akurasiMasuk'],
      jarakMasuk: data['jarakMasuk'],
      fotoPulangUrl: data['fotoPulangUrl'],
      latPulang: data['latPulang'],
      lonPulang: data['lonPulang'],
      akurasiPulang: data['akurasiPulang'],
      jarakPulang: data['jarakPulang'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'nama': nama,
      'tanggal': tanggal,
      'waktuMasuk': waktuMasuk != null ? Timestamp.fromDate(waktuMasuk!) : null,
      'waktuPulang': waktuPulang != null ? Timestamp.fromDate(waktuPulang!) : null,
      'status': status,
      'menitTelat': menitTelat,
      'fotoMasukUrl': fotoMasukUrl,
      'latMasuk': latMasuk,
      'lonMasuk': lonMasuk,
      'akurasiMasuk': akurasiMasuk,
      'jarakMasuk': jarakMasuk,
      'fotoPulangUrl': fotoPulangUrl,
      'latPulang': latPulang,
      'lonPulang': lonPulang,
      'akurasiPulang': akurasiPulang,
      'jarakPulang': jarakPulang,
    };
  }
}