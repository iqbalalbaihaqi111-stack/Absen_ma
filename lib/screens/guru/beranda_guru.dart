import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../attendance/attendance_screen.dart';
import 'info_sekolah_screen.dart';
import 'izin_screen.dart';
import 'jadwal_screen.dart';
import 'jurnal_screen.dart';

class BerandaGuruScreen extends StatelessWidget {
  const BerandaGuruScreen({super.key});

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 11) return 'Selamat Pagi';
    if (hour >= 11 && hour < 15) return 'Selamat Siang';
    if (hour >= 15 && hour < 18) return 'Selamat Sore';
    return 'Selamat Malam';
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const Center(child: Text('Silakan login kembali.'));
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream:
          FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError)
          return Center(child: Text('Profil gagal dimuat: ${snapshot.error}'));
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());
        final user = snapshot.data!.data() ?? <String, dynamic>{};
        final name = (user['nama'] ?? 'Guru').toString().trim();
        final role = (user['role'] ?? 'guru').toString().toLowerCase();
        final isAdmin = role == 'admin';
        return Scaffold(
          backgroundColor: const Color(0xFFF7FAF8),
          body: SafeArea(
            child: RefreshIndicator(
              onRefresh: () async {},
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                children: [
                  Row(children: [
                    ClipOval(
                      child: Image.asset('assets/images/logo.png',
                          width: 52,
                          height: 52,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const CircleAvatar(
                              radius: 26,
                              backgroundColor: Color(0xFFE8F5E9),
                              child: Icon(Icons.school,
                                  color: Color(0xFF0D4B2E)))),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                        child: Text('Pondok Sabilul Hasanah',
                            style: TextStyle(
                                color: Color(0xFF0D4B2E),
                                fontWeight: FontWeight.w800,
                                fontSize: 18))),
                    IconButton(
                        onPressed: () {},
                        icon: const Icon(Icons.notifications_none_rounded,
                            color: Color(0xFF0D4B2E))),
                  ]),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                        color: const Color(0xFFE8F5E9),
                        borderRadius: BorderRadius.circular(18)),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Assalamualaikum,',
                              style: TextStyle(color: Color(0xFF45624A))),
                          const SizedBox(height: 5),
                          Text(
                              '${_greeting()} ${isAdmin ? 'Kepala Sekolah' : 'Bapak/Ibu'} $name',
                              style: const TextStyle(
                                  color: Color(0xFF0D4B2E),
                                  fontWeight: FontWeight.w800,
                                  fontSize: 19)),
                          const SizedBox(height: 6),
                          Text(
                              DateFormat('EEEE, d MMMM yyyy', 'id_ID')
                                  .format(DateTime.now()),
                              style: const TextStyle(color: Color(0xFF52705A))),
                        ]),
                  ),
                  const SizedBox(height: 20),
                  if (!isAdmin) ...[
                    _attendanceCard(context, name),
                    const SizedBox(height: 24)
                  ],
                  const Text('Layanan Utama',
                      style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0D4B2E))),
                  const SizedBox(height: 12),
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.22,
                    children: [
                      _service(
                          context,
                          Icons.calendar_month_outlined,
                          'Jadwal Mengajar',
                          () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const JadwalScreen()))),
                      _service(
                          context,
                          Icons.menu_book_outlined,
                          'Jurnal Mengajar',
                          () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) =>
                                      JurnalScreen(namaGuru: name)))),
                      _service(
                          context,
                          Icons.medical_information_outlined,
                          'Izin / Sakit',
                          () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => IzinScreen(namaGuru: name)))),
                      _service(
                          context,
                          Icons.account_balance_outlined,
                          'Info Sekolah',
                          () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const InfoSekolahScreen()))),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _agenda(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _attendanceCard(BuildContext context, String name) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: const [
              BoxShadow(
                  color: Color(0x120D4B2E),
                  blurRadius: 14,
                  offset: Offset(0, 5))
            ]),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [
            Icon(Icons.fingerprint, color: Color(0xFF0D4B2E), size: 30),
            SizedBox(width: 10),
            Expanded(
                child: Text('Absensi Kehadiran',
                    style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0D4B2E),
                        fontSize: 16)))
          ]),
          const SizedBox(height: 14),
          SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                  onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => AttendanceScreen(namaGuru: name))),
                  child: const Text('ABSEN MASUK SEKARANG'))),
        ]),
      );

  Widget _service(BuildContext context, IconData icon, String title,
          VoidCallback tap) =>
      Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
            onTap: tap,
            borderRadius: BorderRadius.circular(18),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: const [
                    BoxShadow(
                        color: Color(0x100D4B2E),
                        blurRadius: 12,
                        offset: Offset(0, 4))
                  ]),
              child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                        width: 60,
                        height: 60,
                        decoration: const BoxDecoration(
                            color: Color(0xFFE8F5E9), shape: BoxShape.circle),
                        child: Icon(icon,
                            color: const Color(0xFF0D4B2E), size: 29)),
                    const SizedBox(height: 9),
                    Text(title,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0D4B2E))),
                  ]),
            )),
      );

  Widget _agenda() =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Agenda Terdekat',
            style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0D4B2E))),
        const SizedBox(height: 12),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('agenda')
              .orderBy('tanggal')
              .limit(1)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError)
              return _agendaCard('Agenda belum dapat dimuat.', '', '');
            if (!snapshot.hasData)
              return const Center(child: CircularProgressIndicator());
            if (snapshot.data!.docs.isEmpty)
              return _agendaCard(
                  'Belum ada agenda di pondok maupun sekolah', '', '');
            final data = snapshot.data!.docs.first.data();
            final rawDate = data['tanggal'];
            final date = rawDate is Timestamp
                ? DateFormat('d MMM yyyy', 'id_ID').format(rawDate.toDate())
                : (rawDate ?? '').toString();
            return _agendaCard(
                (data['judul'] ?? data['nama'] ?? 'Agenda').toString(),
                '${data['lokasi'] ?? data['tempat'] ?? ''}  ${data['jam'] ?? ''}',
                date);
          },
        ),
      ]);

  Widget _agendaCard(String title, String detail, String date) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
            gradient: const LinearGradient(
                colors: [Color(0xFF0D4B2E), Color(0xFF16A34A)]),
            borderRadius: BorderRadius.circular(20)),
        child: Row(children: [
          ClipOval(
            child: Image.asset('assets/images/logo.png',
                width: 54,
                height: 54,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const CircleAvatar(
                    radius: 27,
                    backgroundColor: Colors.white,
                    child: Icon(Icons.school, color: Color(0xFF0D4B2E)))),
          ),
          const SizedBox(width: 14),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 16)),
                if (detail.isNotEmpty)
                  Padding(
                      padding: const EdgeInsets.only(top: 5),
                      child: Text(detail,
                          style: const TextStyle(color: Colors.white70))),
                if (date.isNotEmpty)
                  Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(date,
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 12)))
              ])),
        ]),
      );
}
