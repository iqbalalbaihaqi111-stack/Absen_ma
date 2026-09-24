import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:csv/csv.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class AdminRekapScreen extends StatefulWidget {
  const AdminRekapScreen({super.key});

  @override
  State<AdminRekapScreen> createState() => _AdminRekapScreenState();
}

class _AdminRekapScreenState extends State<AdminRekapScreen> {
  int _tab = 0;
  int _month = DateTime.now().month;
  int _year = DateTime.now().year;
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  String _date(DateTime d) => DateFormat('yyyy-MM-dd').format(d);
  String _monthName(int month) =>
      DateFormat('MMMM', 'id_ID').format(DateTime(2020, month));

  ({DateTime start, DateTime end}) _range(DateTime now) {
    if (_tab == 0) {
      final day = DateTime(now.year, now.month, now.day);
      return (start: day, end: day.add(const Duration(days: 1)));
    }
    if (_tab == 1) {
      final day = DateTime(now.year, now.month, now.day);
      final daysAfterSaturday = (day.weekday + 1) % 7;
      final start = day.subtract(Duration(days: daysAfterSaturday));
      final end = day.add(const Duration(days: 1));
      final thursdayEnd = start.add(const Duration(days: 6));
      return (start: start, end: end.isBefore(thursdayEnd) ? end : thursdayEnd);
    }
    return (
      start: DateTime(_year, _month, 1),
      end: DateTime(_year, _month + 1, 1)
    );
  }

  bool _present(Map<String, dynamic> d) => ['hadir', 'tepat waktu']
      .contains((d['status'] ?? '').toString().toLowerCase());
  bool _late(Map<String, dynamic> d) =>
      (d['status'] ?? '').toString().toLowerCase().contains('terlambat') ||
      (d['status'] ?? '').toString().toLowerCase() == 'telat';
  bool _leave(Map<String, dynamic> d) => ['izin', 'sakit']
      .any((s) => (d['status'] ?? '').toString().toLowerCase().contains(s));

  Future<Directory> _exportDirectory() async =>
      await getDownloadsDirectory() ?? await getApplicationDocumentsDirectory();

  Future<void> _export(List<Map<String, dynamic>> rows, bool asPdf) async {
    try {
      final dateLabel = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
      final directory = await _exportDirectory();
      if (asPdf) {
        final doc = pw.Document();
        doc.addPage(pw.MultiPage(
            build: (_) => [
                  pw.Header(
                      level: 0,
                      child: pw.Text('Rekap Kehadiran MA Sabilul Hasanah')),
                  pw.Text(
                      'Periode: ${_range(DateTime.now()).start.toIso8601String().substring(0, 10)} s/d ${_range(DateTime.now()).end.subtract(const Duration(days: 1)).toIso8601String().substring(0, 10)}'),
                  pw.SizedBox(height: 14),
                  pw.TableHelper.fromTextArray(headers: const [
                    'No',
                    'No. Urut',
                    'Nama',
                    'Tanggal',
                    'Jam Masuk',
                    'Status',
                    'Alasan'
                  ], data: [
                    for (var i = 0; i < rows.length; i++)
                      [
                        '${i + 1}',
                        '${rows[i]['nomor_urut'] ?? rows[i]['nip'] ?? ''}',
                        '${rows[i]['nama'] ?? ''}',
                        '${rows[i]['tanggal'] ?? ''}',
                        _time(rows[i]),
                        '${rows[i]['status'] ?? ''}',
                        '${rows[i]['alasan'] ?? ''}'
                      ]
                  ]),
                ]));
        final bytes = await doc.save();
        final file = File(
            '${directory.path}${Platform.pathSeparator}rekap_$dateLabel.pdf');
        await file.writeAsBytes(bytes, flush: true);
        await Printing.sharePdf(
            bytes: bytes, filename: file.uri.pathSegments.last);
      } else {
        final data = <List<dynamic>>[
          [
            'No',
            'Nomor Urut',
            'Nama Guru',
            'Tanggal',
            'Jam Masuk',
            'Status',
            'Alasan',
            'Keterangan'
          ],
          for (var i = 0; i < rows.length; i++)
            [
              i + 1,
              rows[i]['nomor_urut'] ?? rows[i]['nip'] ?? '',
              rows[i]['nama'] ?? '',
              rows[i]['tanggal'] ?? '',
              _time(rows[i]),
              rows[i]['status'] ?? '',
              rows[i]['alasan'] ?? '',
              rows[i]['keterangan'] ?? ''
            ],
        ];
        final file = File(
            '${directory.path}${Platform.pathSeparator}rekap_$dateLabel.csv');
        await file.writeAsString(const ListToCsvConverter().convert(data),
            flush: true);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Berhasil menyimpan: ${file.path}'),
            action: SnackBarAction(
                label: 'Buka', onPressed: () => OpenFilex.open(file.path))));
      }
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Ekspor gagal: $error')));
    }
  }

  String _time(Map<String, dynamic> row) {
    final raw = row['waktuMasuk'] ?? row['jam_masuk'];
    if (raw is Timestamp) return DateFormat('HH:mm').format(raw.toDate());
    return (raw ?? '—').toString();
  }

  void _showRecords(String title, List<Map<String, dynamic>> records) {
    showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (context) => SafeArea(
            child: SizedBox(
                height: MediaQuery.sizeOf(context).height * .72,
                child: Column(children: [
                  Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(title,
                          style: const TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 18))),
                  Expanded(
                      child: records.isEmpty
                          ? const Center(child: Text('Belum ada data.'))
                          : ListView.builder(
                              itemCount: records.length,
                              itemBuilder: (_, i) {
                                final d = records[i];
                                return ListTile(
                                    leading: CircleAvatar(
                                        child: Text(
                                            '${d['nomor_urut'] ?? d['nip'] ?? '•'}')),
                                    title: Text('${d['nama'] ?? 'Tanpa nama'}'),
                                    subtitle: Text(
                                        '${d['tanggal'] ?? ''} • ${_time(d)}\n${d['alasan'] ?? ''}'),
                                    isThreeLine: true,
                                    trailing: Text('${d['status'] ?? ''}',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold)));
                              })),
                ]))));
  }

  @override
  Widget build(BuildContext context) {
    final range = _range(DateTime.now());
    final usersStream =
        FirebaseFirestore.instance.collection('users').snapshots();
    final absencesStream = FirebaseFirestore.instance
        .collection('absensi')
        .where('tanggal', isGreaterThanOrEqualTo: _date(range.start))
        .where('tanggal', isLessThan: _date(range.end))
        .snapshots();
    return Scaffold(
      backgroundColor: const Color(0xFFF6FAF7),
      appBar: AppBar(title: const Text('Rekap Dashboard'), actions: [
        IconButton(
            tooltip: 'Ekspor CSV',
            onPressed: () {},
            icon: const Icon(Icons.download))
      ]),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: usersStream,
          builder: (context, userSnapshot) {
            if (userSnapshot.hasError)
              return Center(
                  child:
                      Text('Daftar guru gagal dimuat: ${userSnapshot.error}'));
            if (!userSnapshot.hasData)
              return const Center(child: CircularProgressIndicator());
            final teachers = userSnapshot.data!.docs
                .where((doc) {
                  final d = doc.data();
                  return (d['role'] ?? 'guru').toString().toLowerCase() ==
                          'guru' &&
                      d['isActive'] != false;
                })
                .map((doc) => {...doc.data(), '_id': doc.id})
                .toList();
            final query = _search.text.trim().toLowerCase();
            final visibleTeachers = teachers
                .where((t) =>
                    query.isEmpty ||
                    (t['nama'] ?? '').toString().toLowerCase().contains(query))
                .toList();
            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: absencesStream,
                builder: (context, attendanceSnapshot) {
                  if (attendanceSnapshot.hasError)
                    return Center(
                        child: Text(
                            'Rekap gagal dimuat: ${attendanceSnapshot.error}'));
                  if (!attendanceSnapshot.hasData)
                    return const Center(child: CircularProgressIndicator());
                  final records = attendanceSnapshot.data!.docs
                      .map((d) => d.data())
                      .toList();
                  final today = records
                      .where((d) => d['tanggal'] == _date(DateTime.now()))
                      .toList();
                  final hadir = today.where(_present).toList();
                  final terlambat = today.where(_late).toList();
                  final izin = today.where(_leave).toList();
                  final alpha = today
                      .where((d) => (d['status'] ?? '')
                          .toString()
                          .toLowerCase()
                          .contains('alpa'))
                      .toList();
                  final absentCount = (teachers.length -
                          hadir.length -
                          terlambat.length -
                          izin.length -
                          alpha.length)
                      .clamp(0, teachers.length);
                  final filtered = teachers
                      .where((t) =>
                          query.isEmpty ||
                          (t['nama'] ?? '')
                              .toString()
                              .toLowerCase()
                              .contains(query))
                      .toList();
                  return ListView(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
                      children: [
                        TextField(
                            controller: _search,
                            onChanged: (_) => setState(() {}),
                            decoration: InputDecoration(
                                prefixIcon: const Icon(Icons.search),
                                hintText: 'Cari nama guru',
                                filled: true,
                                fillColor: Colors.white,
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: BorderSide.none))),
                        const SizedBox(height: 12),
                        SegmentedButton<int>(
                            segments: const [
                              ButtonSegment(value: 0, label: Text('Harian')),
                              ButtonSegment(value: 1, label: Text('Mingguan')),
                              ButtonSegment(value: 2, label: Text('Bulanan'))
                            ],
                            selected: {
                              _tab
                            },
                            onSelectionChanged: (s) =>
                                setState(() => _tab = s.first)),
                        if (_tab == 2)
                          Padding(
                              padding: const EdgeInsets.only(top: 10),
                              child: Row(children: [
                                Expanded(
                                    child: DropdownButtonFormField<int>(
                                        value: _month,
                                        decoration: const InputDecoration(
                                            labelText: 'Bulan'),
                                        items: List.generate(12, (i) => i + 1)
                                            .map((m) => DropdownMenuItem(
                                                value: m,
                                                child: Text(_monthName(m))))
                                            .toList(),
                                        onChanged: (v) {
                                          if (v != null)
                                            setState(() => _month = v);
                                        })),
                                const SizedBox(width: 10),
                                Expanded(
                                    child: DropdownButtonFormField<int>(
                                        value: _year,
                                        decoration: const InputDecoration(
                                            labelText: 'Tahun'),
                                        items: List.generate(
                                                5,
                                                (i) =>
                                                    DateTime.now().year - 2 + i)
                                            .map((y) => DropdownMenuItem(
                                                value: y, child: Text('$y')))
                                            .toList(),
                                        onChanged: (v) {
                                          if (v != null)
                                            setState(() => _year = v);
                                        }))
                              ])),
                        const SizedBox(height: 12),
                        Row(children: [
                          Expanded(
                              child: _stat(
                                  'Total Guru',
                                  teachers.length,
                                  Icons.groups_2_outlined,
                                  () => _showRecords('Daftar Guru', filtered))),
                          const SizedBox(width: 8),
                          Expanded(
                              child: _stat(
                                  'Hadir',
                                  hadir.length,
                                  Icons.check_circle_outline,
                                  () => _showRecords('Guru Hadir', hadir))),
                          const SizedBox(width: 8),
                          Expanded(
                              child: _stat(
                                  'Terlambat',
                                  terlambat.length,
                                  Icons.schedule,
                                  () => _showRecords(
                                      'Guru Terlambat', terlambat))),
                          const SizedBox(width: 8),
                          Expanded(
                              child: _stat(
                                  'Izin/Alpa',
                                  izin.length + alpha.length,
                                  Icons.event_busy,
                                  () => _showRecords('Izin, Sakit, dan Alpa',
                                      [...izin, ...alpha])))
                        ]),
                        const SizedBox(height: 16),
                        Row(children: [
                          Expanded(
                              child: _chartCard('Tren Kehadiran 14 Hari',
                                  _trend(records, teachers.length))),
                          const SizedBox(width: 10),
                          Expanded(
                              child: _pieCard(hadir.length, terlambat.length,
                                  izin.length, absentCount))
                        ]),
                        const SizedBox(height: 12),
                        _weeklyCard(records),
                        const SizedBox(height: 12),
                        Row(children: [
                          Expanded(
                              child: FilledButton.icon(
                                  onPressed: () => _export(records, false),
                                  icon: const Icon(Icons.download),
                                  label: const Text('Export CSV'))),
                          const SizedBox(width: 10),
                          Expanded(
                              child: OutlinedButton.icon(
                                  onPressed: () => _export(records, true),
                                  icon: const Icon(Icons.picture_as_pdf),
                                  label: const Text('Export PDF'))),
                        ]),
                        const SizedBox(height: 18),
                        Text('Daftar Guru (${visibleTeachers.length})',
                            style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0D4B2E))),
                        ...visibleTeachers.take(30).map((t) => Card(
                            color: Colors.white,
                            child: ListTile(
                                leading: CircleAvatar(
                                    child: Text(
                                        '${t['nomor_urut'] ?? t['nip'] ?? '•'}')),
                                title: Text('${t['nama'] ?? 'Tanpa nama'}'),
                                subtitle: Text(
                                    'Status akun: ${t['isActive'] == false ? 'Nonaktif' : 'Aktif'}')))),
                      ]);
                });
          }),
    );
  }

  Widget _stat(String label, int value, IconData icon, VoidCallback tap) =>
      InkWell(
          onTap: tap,
          borderRadius: BorderRadius.circular(16),
          child: Card(
              color: Colors.white,
              child: Padding(
                  padding:
                      const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
                  child: Column(children: [
                    Icon(icon, color: const Color(0xFF0D4B2E), size: 21),
                    const SizedBox(height: 5),
                    Text('$value',
                        style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 19,
                            color: Color(0xFF0D4B2E))),
                    Text(label,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 10))
                  ]))));

  Widget _chartCard(String title, List<FlSpot> values) => Card(
      color: Colors.white,
      child: Padding(
          padding: const EdgeInsets.all(12),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 14),
            SizedBox(
                height: 130,
                child: LineChart(LineChartData(
                    minY: 0,
                    maxY: 100,
                    gridData:
                        const FlGridData(show: true, drawVerticalLine: false),
                    titlesData: const FlTitlesData(show: false),
                    borderData: FlBorderData(show: false),
                    lineBarsData: [
                      LineChartBarData(
                          spots: values,
                          isCurved: true,
                          color: const Color(0xFF16A34A),
                          barWidth: 3,
                          belowBarData: BarAreaData(
                              show: true, color: const Color(0x3316A34A)),
                          dotData: const FlDotData(show: false))
                    ])))
          ])));

  List<FlSpot> _trend(List<Map<String, dynamic>> records, int total) =>
      List.generate(14, (i) {
        final day = DateTime.now().subtract(Duration(days: 13 - i));
        final rows = records
            .where(
                (r) => r['tanggal'] == _date(day) && (_present(r) || _late(r)))
            .length;
        return FlSpot(i.toDouble(), total == 0 ? 0 : rows * 100 / total);
      });

  Widget _pieCard(int hadir, int late, int leave, int absent) => Card(
      color: Colors.white,
      child: Padding(
          padding: const EdgeInsets.all(10),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Distribusi Hari Ini',
                style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            SizedBox(
                height: 130,
                child: PieChart(PieChartData(centerSpaceRadius: 28, sections: [
                  PieChartSectionData(
                      value: hadir.toDouble(),
                      color: const Color(0xFF16A34A),
                      radius: 30,
                      title: '$hadir'),
                  PieChartSectionData(
                      value: late.toDouble(),
                      color: Colors.orange,
                      radius: 30,
                      title: '$late'),
                  PieChartSectionData(
                      value: leave.toDouble(),
                      color: Colors.teal,
                      radius: 30,
                      title: '$leave'),
                  PieChartSectionData(
                      value: absent.toDouble(),
                      color: Colors.redAccent,
                      radius: 30,
                      title: '$absent')
                ]))),
            const Text('Hadir • Telat • Izin • Alpa',
                style: TextStyle(fontSize: 9))
          ])));

  Widget _weeklyCard(List<Map<String, dynamic>> records) => Card(
      color: Colors.white,
      child: Padding(
          padding: const EdgeInsets.all(14),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Perbandingan Mingguan (Sabtu–Kamis)',
                style: TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 16),
            SizedBox(
                height: 180,
                child: BarChart(BarChartData(
                    barGroups: List.generate(4, (i) {
                      final week =
                          DateTime.now().subtract(Duration(days: 7 * (3 - i)));
                      final from =
                          week.subtract(Duration(days: (week.weekday + 1) % 7));
                      final until = from.add(const Duration(days: 6));
                      final rows = records.where((r) {
                        final d =
                            DateTime.tryParse((r['tanggal'] ?? '').toString());
                        return d != null &&
                            !d.isBefore(from) &&
                            d.isBefore(until);
                      }).toList();
                      return BarChartGroupData(x: i, barsSpace: 3, barRods: [
                        BarChartRodData(
                            toY: rows.where(_present).length.toDouble(),
                            color: const Color(0xFF16A34A),
                            width: 8),
                        BarChartRodData(
                            toY: rows.where(_late).length.toDouble(),
                            color: Colors.orange,
                            width: 8),
                        BarChartRodData(
                            toY: rows.where(_leave).length.toDouble(),
                            color: Colors.teal,
                            width: 8)
                      ]);
                    }),
                    titlesData: const FlTitlesData(show: false),
                    borderData: FlBorderData(show: false),
                    gridData:
                        const FlGridData(show: true, drawVerticalLine: false))))
          ])));
}
