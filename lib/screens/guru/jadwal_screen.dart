import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../utils/theme.dart';

class JadwalScreen extends StatelessWidget {
  const JadwalScreen({super.key});

  static const _hari = [
    '',
    'Senin',
    'Selasa',
    'Rabu',
    'Kamis',
    'Jumat',
    'Sabtu',
    'Minggu',
  ];
  static const _bulan = [
    '',
    'Januari',
    'Februari',
    'Maret',
    'April',
    'Mei',
    'Juni',
    'Juli',
    'Agustus',
    'September',
    'Oktober',
    'November',
    'Desember',
  ];

  String _text(
    Map<String, dynamic> data,
    List<String> keys, {
    String fallback = '',
  }) {
    for (final key in keys) {
      final value = data[key];
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString().trim();
      }
    }
    return fallback;
  }

  int _period(Map<String, dynamic> data) {
    final raw = _text(data, ['jamKe', 'jam_ke', 'jam', 'urutanJam', 'period']);
    return int.tryParse(RegExp(r'\d+').firstMatch(raw)?.group(0) ?? '') ?? 999;
  }

  DateTime _updatedTime(Map<String, dynamic> data) {
    final value = data['createdAt'] ?? data['updatedAt'];
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  bool _isToday(Map<String, dynamic> data, String today, String englishToday) {
    final raw = data['hari'] ?? data['day'];
    final values = raw is Iterable ? raw : [raw];
    return values.any((value) {
      final day = value?.toString().trim().toLowerCase() ?? '';
      return day == today.toLowerCase() ||
          day.startsWith(today.toLowerCase()) ||
          day == englishToday.toLowerCase() ||
          day.startsWith(englishToday.toLowerCase());
    });
  }

  bool _belongsToTeacher(
    Map<String, dynamic> data,
    String uid,
    String nip,
    String name,
  ) {
    final fields = [
      'userId',
      'user_id',
      'guruId',
      'guru_id',
      'uid',
      'teacherId',
      'teacher_id',
      'teacherNumber',
      'nomorUrut',
      'nomor_urut',
      'noUrut',
      'no_urut',
      'nip',
      'idGuru',
      'guru',
      'namaGuru',
      'namaPengajar',
    ];
    final accepted = {uid, nip, name}
        .map((value) => value.trim().toLowerCase())
        .where((value) => value.isNotEmpty)
        .toSet();
    for (final field in fields) {
      final raw = data[field];
      if (raw == null) continue;
      final values = raw is Iterable ? raw : [raw];
      for (final value in values) {
        final normalized = value.toString().trim().toLowerCase();
        if (accepted.contains(normalized)) return true;
        final digits = RegExp(r'\d+').firstMatch(normalized)?.group(0);
        if (nip.isNotEmpty && digits == nip.trim()) return true;
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final authUser = FirebaseAuth.instance.currentUser;
    if (authUser == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Jadwal Mengajar')),
        body: const Center(child: Text('Silakan login kembali.')),
      );
    }
    final now = DateTime.now();
    final today = _hari[now.weekday];
    const englishDays = [
      '',
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    final dateLabel =
        '${_hari[now.weekday]}, ${now.day} ${_bulan[now.month]} ${now.year}';

    return Scaffold(
      appBar: AppBar(title: const Text('Jadwal Mengajar')),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(authUser.uid)
            .snapshots(),
        builder: (context, userSnapshot) {
          if (userSnapshot.hasError) {
            return _message('Profil guru gagal dimuat: ${userSnapshot.error}');
          }
          if (!userSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final profile = userSnapshot.data!.data() ?? <String, dynamic>{};
          final nip = (profile['nip'] ??
                  profile['nomor_urut'] ??
                  profile['nomorUrut'] ??
                  '')
              .toString()
              .trim();
          final name = (profile['nama'] ?? 'Guru').toString();

          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance.collection('jadwal').snapshots(),
            builder: (context, scheduleSnapshot) {
              if (scheduleSnapshot.hasError) {
                return _message(
                  'Jadwal gagal dimuat: ${scheduleSnapshot.error}',
                );
              }
              if (!scheduleSnapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final allLessons =
                  scheduleSnapshot.data!.docs.map((doc) => doc.data()).toList();
              final importedLessons = allLessons
                  .where((lesson) => lesson['source'] == 'bt_mash_26_27')
                  .toList();
              final matchingLessons =
                  (importedLessons.isNotEmpty ? importedLessons : allLessons)
                      .where(
                        (lesson) =>
                            _isToday(lesson, today, englishDays[now.weekday]) &&
                            _belongsToTeacher(lesson, authUser.uid, nip, name),
                      )
                      .toList();
              final uniqueLessons = <String, Map<String, dynamic>>{};
              for (final lesson in matchingLessons) {
                final day = _text(lesson, ['hari', 'day']).toLowerCase();
                final className = _text(
                  lesson,
                  ['kelas', 'namaKelas', 'nama_kelas', 'class'],
                ).toLowerCase();
                final key = '$day*${_period(lesson)}*$className'
                    .replaceAll(RegExp(r'\s+'), '');
                final previous = uniqueLessons[key];
                if (previous == null ||
                    _updatedTime(lesson).isAfter(_updatedTime(previous))) {
                  uniqueLessons[key] = lesson;
                }
              }
              final lessons = uniqueLessons.values.toList()
                ..sort((a, b) => _period(a).compareTo(_period(b)));

              if (lessons.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.event_busy,
                          size: 52,
                          color: AppTheme.primary,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          now.weekday == DateTime.friday
                              ? 'Hari Jumat Libur'
                              : 'Belum ada jadwal untuk $name hari ini.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          dateLabel,
                          style: const TextStyle(color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    color: AppTheme.primary,
                    child: ListTile(
                      leading: const Icon(
                        Icons.calendar_month,
                        color: Colors.white,
                      ),
                      title: Text(
                        dateLabel,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: Text(
                        name,
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...lessons.map((lesson) {
                    final period = _text(
                        lesson,
                        [
                          'jam_label',
                          'jamKe',
                          'jam_ke',
                          'jam',
                          'urutanJam',
                          'period',
                        ],
                        fallback: 'Jam');
                    final subject = _text(
                        lesson,
                        [
                          'mataPelajaran',
                          'mata_pelajaran',
                          'mapel',
                          'pelajaran',
                          'subject',
                        ],
                        fallback: 'Mata pelajaran belum diisi');
                    final className = _text(lesson, [
                      'kelas',
                      'namaKelas',
                      'nama_kelas',
                      'class',
                    ]);
                    final time = _text(lesson, [
                      'waktu',
                      'jamMulai',
                      'jam_mulai',
                      'rentangWaktu',
                      'pukul',
                    ]);
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppTheme.primary.withOpacity(.12),
                          child: Text(
                            _period(lesson) == 999 ? '•' : '${_period(lesson)}',
                            style: const TextStyle(
                              color: AppTheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text(
                          '$period • $subject',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          [
                            if (className.isNotEmpty) className,
                            if (time.isNotEmpty) time,
                          ].join('  •  '),
                        ),
                      ),
                    );
                  }),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _message(String message) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(message, textAlign: TextAlign.center),
        ),
      );
}
