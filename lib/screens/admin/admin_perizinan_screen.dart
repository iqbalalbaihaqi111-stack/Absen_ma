import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AdminPerizinanScreen extends StatelessWidget {
  const AdminPerizinanScreen({super.key});

  Future<void> _setStatus(
      BuildContext context, String collection, String id, String status,
      {bool? approved}) async {
    try {
      await FirebaseFirestore.instance.collection(collection).doc(id).update({
        'status': status,
        if (approved != null) 'isApproved': approved,
        'reviewedAt': FieldValue.serverTimestamp(),
      });
    } catch (error) {
      if (context.mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Perubahan gagal disimpan: $error')));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xFFF7FAF8),
        appBar: AppBar(title: const Text('Persetujuan Kehadiran')),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          const Text('Keterlambatan dan Alpa',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0D4B2E))),
          const SizedBox(height: 8),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance.collection('absensi').where(
                'status',
                whereIn: const ['Terlambat', 'Alpa']).snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError)
                return Text('Data kehadiran gagal dimuat: ${snapshot.error}');
              if (!snapshot.hasData)
                return const Center(child: CircularProgressIndicator());
              final docs = snapshot.data!.docs
                  .where((d) =>
                      (d.data()['alasan'] ?? '').toString().trim().isNotEmpty)
                  .toList();
              if (docs.isEmpty)
                return const Card(
                    child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('Tidak ada permohonan yang menunggu.')));
              return Column(
                  children: docs.map((doc) {
                final data = doc.data();
                return Card(
                    color: Colors.white,
                    margin: const EdgeInsets.only(bottom: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                  '${data['nama'] ?? 'Guru'} • ${data['tanggal'] ?? ''}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w800)),
                              const SizedBox(height: 5),
                              Text('Alasan: ${data['alasan'] ?? '—'}'),
                              const SizedBox(height: 10),
                              Row(children: [
                                Expanded(
                                    child: FilledButton(
                                        onPressed: () => _setStatus(
                                            context, 'absensi', doc.id, 'Hadir',
                                            approved: true),
                                        child: const Text('ACC / TERIMA'))),
                                const SizedBox(width: 8),
                                Expanded(
                                    child: OutlinedButton(
                                        onPressed: () => _setStatus(
                                            context, 'absensi', doc.id, 'Alpa',
                                            approved: false),
                                        child: const Text('Tolak')))
                              ]),
                            ])));
              }).toList());
            },
          ),
          const SizedBox(height: 18),
          const Text('Pengajuan Izin / Sakit',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0D4B2E))),
          const SizedBox(height: 8),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('izin_sakit')
                .where('status', isEqualTo: 'Menunggu')
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError)
                return Text('Pengajuan izin gagal dimuat: ${snapshot.error}');
              if (!snapshot.hasData)
                return const Center(child: CircularProgressIndicator());
              if (snapshot.data!.docs.isEmpty)
                return const Card(
                    child: Padding(
                        padding: EdgeInsets.all(16),
                        child:
                            Text('Tidak ada pengajuan izin yang menunggu.')));
              return Column(
                  children: snapshot.data!.docs.map((doc) {
                final data = doc.data();
                return Card(
                    color: Colors.white,
                    child: ListTile(
                      leading: const CircleAvatar(
                          backgroundColor: Color(0xFFFFF1D6),
                          child:
                              Icon(Icons.hourglass_top, color: Colors.orange)),
                      title: Text(
                          '${data['nama'] ?? 'Guru'} • ${data['jenis'] ?? 'Izin'}'),
                      subtitle: Text(
                          '${data['alasan'] ?? ''}\n${data['tanggal'] ?? ''}'),
                      isThreeLine: true,
                      trailing: PopupMenuButton<String>(
                          onSelected: (value) =>
                              _setStatus(context, 'izin_sakit', doc.id, value),
                          itemBuilder: (_) => const [
                                PopupMenuItem(
                                    value: 'Diterima', child: Text('Terima')),
                                PopupMenuItem(
                                    value: 'Ditolak', child: Text('Tolak'))
                              ],
                          icon: const Icon(Icons.more_vert)),
                    ));
              }).toList());
            },
          ),
        ]),
      );
}
