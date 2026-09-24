import 'package:cloud_firestore/cloud_firestore.dart';

class JadwalCleanupService {
  final FirebaseFirestore _firestore;

  JadwalCleanupService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  Future<int> bersihkanJadwalDobel() async {
    final snapshot = await _firestore.collection('jadwal').get();
    final groups =
        <String, List<QueryDocumentSnapshot<Map<String, dynamic>>>>{};

    for (final doc in snapshot.docs) {
      final data = doc.data();
      final year =
          (data['tahunAjaran'] ?? data['tahun_ajaran'] ?? '').toString();
      final source = (data['source'] ?? '').toString();
      if (year != '2026/2027' &&
          source != 'bt_mash_26_27' &&
          !doc.id.startsWith('bt2627_')) continue;

      final day = _value(data, const ['hari', 'day']);
      final periodText = _value(data, const ['jamKe', 'jam_ke', 'jam', 'period']);
      final period = RegExp(r'\d+').firstMatch(periodText)?.group(0) ?? '';
      final className =
          _value(data, const ['kelas', 'namaKelas', 'nama_kelas', 'class']);
      final teacher = _value(data, const [
        'guruId',
        'guru_id',
        'teacherId',
        'teacher_id',
        'nomor_urut',
        'nomorUrut',
        'nip',
        'namaGuru',
      ]);
      if (day.isEmpty || period.isEmpty || className.isEmpty || teacher.isEmpty)
        continue;
      final key = '$day*$period*${className}_$teacher'
          .toLowerCase()
          .replaceAll(RegExp(r'\s+'), '');
      groups.putIfAbsent(key, () => []).add(doc);
    }

    final deleteRefs = <DocumentReference<Map<String, dynamic>>>[];
    for (final docs in groups.values.where((items) => items.length > 1)) {
      docs.sort((a, b) {
        final aTime =
            _date(a.data()['createdAt']) ?? _date(a.data()['updatedAt']);
        final bTime =
            _date(b.data()['createdAt']) ?? _date(b.data()['updatedAt']);
        final byTime = (bTime ?? DateTime.fromMillisecondsSinceEpoch(0))
            .compareTo(aTime ?? DateTime.fromMillisecondsSinceEpoch(0));
        return byTime != 0 ? byTime : a.id.compareTo(b.id);
      });
      deleteRefs.addAll(docs.skip(1).map((doc) => doc.reference));
    }

    for (var start = 0; start < deleteRefs.length; start += 450) {
      final batch = _firestore.batch();
      for (final ref in deleteRefs.skip(start).take(450)) {
        batch.delete(ref);
      }
      await batch.commit();
    }
    return deleteRefs.length;
  }

  static String _value(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final value = data[key];
      if (value != null && value.toString().trim().isNotEmpty)
        return value.toString().trim();
    }
    return '';
  }

  static DateTime? _date(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }
}
