import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class RiwayatScreen extends StatefulWidget {
  const RiwayatScreen({super.key});

  @override
  State<RiwayatScreen> createState() => _RiwayatScreenState();
}

class _RiwayatScreenState extends State<RiwayatScreen> {
  int _month = DateTime.now().month;

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const Center(child: Text('Silakan login kembali.'));
    final today = DateTime.now();
    final monthPrefix =
        '${today.year.toString().padLeft(4, '0')}-${_month.toString().padLeft(2, '0')}';
    return Scaffold(
      backgroundColor: const Color(0xFFF7FAF8),
      appBar: AppBar(title: const Text('Riwayat Kehadiran')),
      body: Column(children: [
        Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: DropdownButtonFormField<int>(
              value: _month,
              decoration: const InputDecoration(labelText: 'Pilih bulan'),
              items: List.generate(12, (index) => index + 1)
                  .map((month) => DropdownMenuItem(
                      value: month, child: Text(_monthName(month))))
                  .toList(),
              onChanged: (value) {
                if (value != null) setState(() => _month = value);
              },
            )),
        Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('absensi')
              .where('userId', isEqualTo: uid)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError)
              return Center(
                  child: Text('Riwayat gagal dimuat: ${snapshot.error}'));
            if (!snapshot.hasData)
              return const Center(child: CircularProgressIndicator());
            final docs = snapshot.data!.docs
                .where((doc) => (doc.data()['tanggal'] ?? '')
                    .toString()
                    .startsWith(monthPrefix))
                .toList()
              ..sort((a, b) => (b.data()['tanggal'] ?? '')
                  .toString()
                  .compareTo((a.data()['tanggal'] ?? '').toString()));
            if (docs.isEmpty)
              return const Center(
                  child: Text('Belum ada riwayat kehadiran pada bulan ini.'));
            return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final data = docs[index].data();
                  final status = (data['status'] ?? 'Hadir').toString();
                  final late = status.toLowerCase().contains('telat') ||
                      status.toLowerCase().contains('terlambat');
                  final time = data['waktuMasuk'] is Timestamp
                      ? (data['waktuMasuk'] as Timestamp).toDate()
                      : null;
                  final clock = time == null
                      ? '—'
                      : '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
                  return Card(
                      color: Colors.white,
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      child: ListTile(
                        leading: CircleAvatar(
                            backgroundColor: late
                                ? const Color(0xFFFFF0D7)
                                : const Color(0xFFE8F5E9),
                            child: Icon(
                                late
                                    ? Icons.schedule
                                    : Icons.check_circle_outline,
                                color: late
                                    ? Colors.deepOrange
                                    : const Color(0xFF1B5E20))),
                        title: Text((data['tanggal'] ?? '').toString(),
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(
                            'Jam masuk $clock${(data['jamPulang'] ?? '').toString().isNotEmpty ? ' • Pulang ${data['jamPulang']}' : ''}'),
                        trailing: Text(late ? 'Terlambat' : 'Tepat Waktu',
                            style: TextStyle(
                                color: late
                                    ? Colors.deepOrange
                                    : const Color(0xFF1B5E20),
                                fontWeight: FontWeight.w700)),
                      ));
                });
          },
        )),
      ]),
    );
  }

  String _monthName(int month) => const [
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
        'Desember'
      ][month];
}
