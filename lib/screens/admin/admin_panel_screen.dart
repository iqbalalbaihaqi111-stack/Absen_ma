import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import '../../utils/theme.dart';
import '../../services/storage_service.dart';
import '../../utils/firestore_sanitizer.dart';
import '../../services/jadwal_cleanup_service.dart';
import 'admin_perizinan_screen.dart';

class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({super.key});

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen> {
  final StorageService _storageService = StorageService();

  // Pengumuman
  final TextEditingController _pengumumanController = TextEditingController();
  File? _filePengumuman;
  String _namaFilePengumuman = '';

  // Agenda
  final TextEditingController _agendaJudulController = TextEditingController();
  final TextEditingController _agendaTglController = TextEditingController();
  final TextEditingController _agendaDescController = TextEditingController();
  File? _fileAgenda;
  String _namaFileAgenda = '';

  bool _isLoading = false;
  bool _isGenerating = false;
  int _generationProgress = 0;

  Future<void> _bersihkanJadwalDobel() async {
    setState(() => _isLoading = true);
    try {
      final removed = await JadwalCleanupService().bersihkanJadwalDobel();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$removed jadwal dobel dihapus')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal membersihkan jadwal: $error')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _importScheduleData() async {
    try {
      final raw =
          await rootBundle.loadString('assets/images/jadwal_26_27.json');
      final parsed = jsonDecode(raw) as Map<String, dynamic>;
      final teachers =
          (parsed['teachers'] as List).cast<Map<String, dynamic>>();
      final lessons = (parsed['jadwal'] as List).cast<Map<String, dynamic>>();
      if (!mounted) return;
      final accepted = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Impor Data Guru dan Jadwal'),
          content: Text(
              '${teachers.length} data guru (nomor 1 admin) dan ${lessons.length} jadwal akan disimpan ke Firestore. Data lain tidak dihapus.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Batal')),
            FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Impor')),
          ],
        ),
      );
      if (accepted != true || !mounted) return;
      setState(() => _isLoading = true);
      final db = FirebaseFirestore.instance;
      final writes =
          <({String collection, String id, Map<String, dynamic> data})>[];
      for (final teacher in teachers) {
        final number = (teacher['nomor_urut'] as num).toInt();
        writes.add((
          collection: 'users',
          id: 'roster_${number.toString().padLeft(2, '0')}',
          data: {
            ...teacher,
            'nomor_urut': number,
            'nip': '$number',
            'role': number == 1 ? 'admin' : 'guru',
            'catalogOnly': true,
            'importVersion': '26_27',
            'isActive': true,
            'updatedAt': Timestamp.now(),
          }
        ));
      }
      final scheduleSlots = <String, Map<String, dynamic>>{};
      for (final lesson in lessons) {
        final number = (lesson['nomor_urut'] as num).toInt();
        const year = '2026/2027';
        final slot =
            '${lesson['hari']}_${lesson['jam_ke']}_${lesson['kelas']}_${number}_$year'
                .replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
        scheduleSlots['bt2627_$slot'] = {
          ...lesson,
          'nomor_urut': number,
          'guruId': number.toString(),
          'jam_ke': (lesson['jam_ke'] as num).toInt(),
          'tahunAjaran': year,
          'source': 'bt_mash_26_27',
          'updatedAt': Timestamp.now(),
        };
      }
      for (final entry in scheduleSlots.entries) {
        writes.add((
          collection: 'jadwal',
          id: entry.key,
          data: entry.value,
        ));
      }
      for (var start = 0; start < writes.length; start += 400) {
        final batch = db.batch();
        for (final write in writes.skip(start).take(400)) {
          batch.set(db.collection(write.collection).doc(write.id),
              sanitizeFirestoreData(write.data), SetOptions(merge: true));
        }
        await batch.commit();
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              'Impor selesai: ${teachers.length} guru dan ${lessons.length} jadwal.')));
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Impor gagal: $error')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // =========================================================================
  // GENERATE AKUN PENGGUNA DARI NOMOR URUT 1–46
  // =========================================================================
  Future<void> _generate45AkunOtomatis() async {
    setState(() => _isGenerating = true);
    int sukses = 0;
    int sudahAda = 0;
    int gagal = 0;
    setState(() => _generationProgress = 0);

    try {
      // Kita buat 'Secondary App' agar sesi Admin Anda saat ini tidak ter-logout
      // ketika Firebase membuat akun baru.
      FirebaseApp app;
      try {
        app = Firebase.app('SecondaryApp');
      } catch (e) {
        app = await Firebase.initializeApp(
          name: 'SecondaryApp',
          options: Firebase.app().options,
        );
      }

      FirebaseAuth authSecondary = FirebaseAuth.instanceFor(app: app);
      FirebaseFirestore firestore = FirebaseFirestore.instance;
      final roster = await firestore
          .collection('users')
          .where('catalogOnly', isEqualTo: true)
          .get();
      final names = <int, String>{};
      for (final doc in roster.docs) {
        final data = doc.data();
        final number = int.tryParse('${data['nomor_urut'] ?? ''}');
        if (number != null) names[number] = (data['nama'] ?? '').toString();
      }

      for (int i = 1; i <= 46; i++) {
        if (mounted) setState(() => _generationProgress = i);
        String nip = i.toString();
        String email = '$nip@sabilulhasanah.com';
        String password = (i == 1) ? 'ADMINMA2026' : 'MA2026';
        String role = (i == 1) ? 'admin' : 'guru';
        String nama = names[i] ?? 'Guru $nip';

        try {
          // 1. Buat akun di Firebase Auth
          UserCredential userCred =
              await authSecondary.createUserWithEmailAndPassword(
            email: email,
            password: password,
          );

          // 2. Simpan data profil ke Firestore Database
          if (userCred.user != null) {
            await firestore
                .collection('users')
                .doc(userCred.user!.uid)
                .set(sanitizeFirestoreData({
                  'nama': nama,
                  'nip': nip,
                  'nomor_urut': i,
                  'role': role,
                  'isActive': true,
                  'createdAt': Timestamp.now(),
                }));
            sukses++;
          }
        } on FirebaseAuthException catch (e) {
          if (e.code == 'email-already-in-use') {
            sudahAda++;
          } else {
            gagal++;
            debugPrint('Akun $nip gagal dibuat: ${e.code} ${e.message}');
          }
        } catch (e) {
          gagal++;
          debugPrint('Akun $nip gagal dibuat: $e');
        }
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Selesai: $sukses akun baru, $sudahAda sudah ada, $gagal gagal.'),
          backgroundColor: AppTheme.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Terjadi kesalahan: $e'),
            backgroundColor: AppTheme.error),
      );
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }
  // =========================================================================

  Future<void> _pilihFileBebas(bool isPengumuman) async {
    final List<PlatformFile> result =
        await FilePicker.pickFiles(type: FileType.any);

    if (result.isNotEmpty && result.first.path != null) {
      setState(() {
        if (isPengumuman) {
          _filePengumuman = File(result.first.path!);
          _namaFilePengumuman = result.first.name;
        } else {
          _fileAgenda = File(result.first.path!);
          _namaFileAgenda = result.first.name;
        }
      });
    }
  }

  void _kirimPengumuman() async {
    if (_pengumumanController.text.trim().isEmpty && _filePengumuman == null)
      return;
    setState(() => _isLoading = true);

    try {
      String docId = DateTime.now().millisecondsSinceEpoch.toString();
      String fileUrl = '';
      String fileName = '';

      if (_filePengumuman != null) {
        Map<String, String> uploadRes = await _storageService.uploadGeneralFile(
            _filePengumuman!, 'pengumuman', docId);
        fileUrl = uploadRes['url']!;
        fileName = uploadRes['name']!;
      }

      await FirebaseFirestore.instance.collection('pengumuman').doc(docId).set({
        'isi': _pengumumanController.text.trim(),
        'fileUrl': fileUrl,
        'fileName': fileName,
        'waktu': FieldValue.serverTimestamp(),
      });

      _pengumumanController.clear();
      setState(() {
        _filePengumuman = null;
        _namaFilePengumuman = '';
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Pengumuman berhasil disiarkan!'),
          backgroundColor: AppTheme.success));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Gagal: $e'), backgroundColor: AppTheme.error));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _kirimAgenda() async {
    if (_agendaJudulController.text.trim().isEmpty ||
        _agendaTglController.text.trim().isEmpty) return;
    setState(() => _isLoading = true);

    try {
      String docId = DateTime.now().millisecondsSinceEpoch.toString();
      String fileUrl = '';
      String fileName = '';

      if (_fileAgenda != null) {
        Map<String, String> uploadRes = await _storageService.uploadGeneralFile(
            _fileAgenda!, 'agenda', docId);
        fileUrl = uploadRes['url']!;
        fileName = uploadRes['name']!;
      }

      await FirebaseFirestore.instance.collection('agenda').doc(docId).set({
        'judul': _agendaJudulController.text.trim(),
        'tanggal': _agendaTglController.text.trim(),
        'deskripsi': _agendaDescController.text.trim(),
        'fileUrl': fileUrl,
        'fileName': fileName,
        'waktu': FieldValue.serverTimestamp(),
      });

      _agendaJudulController.clear();
      _agendaTglController.clear();
      _agendaDescController.clear();
      setState(() {
        _fileAgenda = null;
        _namaFileAgenda = '';
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Agenda berhasil ditambahkan!'),
          backgroundColor: AppTheme.success));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Gagal: $e'), backgroundColor: AppTheme.error));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Kelola Madrasah')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF9800),
                foregroundColor: Colors.white,
              ),
              onPressed:
                  _isLoading || _isGenerating ? null : _bersihkanJadwalDobel,
              icon: _isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.cleaning_services_outlined),
              label: const Text('BERSIHKAN JADWAL DOBEL SEKARANG'),
            ),
          ),
          const SizedBox(height: 10),
          Card(
            child: ListTile(
              leading: const Icon(Icons.cloud_upload_outlined,
                  color: AppTheme.primary),
              title: const Text('Impor Guru dan Jadwal 2026/2027'),
              subtitle:
                  const Text('Muat daftar nomor 1–46 dan jadwal ke Firestore'),
              trailing: const Icon(Icons.chevron_right),
              onTap: _isLoading || _isGenerating ? null : _importScheduleData,
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.fact_check_outlined,
                  color: AppTheme.primary),
              title: const Text('Persetujuan Izin dan Keterlambatan'),
              subtitle: const Text('Tinjau alasan guru dan keputusan admin'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const AdminPerizinanScreen())),
            ),
          ),
          const SizedBox(height: 12),
          // ===============================================================
          // TAMPILAN KOTAK MERAH (TOMBOL AJAIB)
          // ===============================================================
          Container(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.only(bottom: 24),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              border: Border.all(color: Colors.red.shade300, width: 2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                const Row(
                  children: [
                    Icon(Icons.warning_amber_rounded,
                        color: Colors.red, size: 30),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'KLIK 1 KALI UNTUK MEMBUAT 46 AKUN: 1 ADMIN DAN 45 GURU',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, color: Colors.red),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade700),
                    onPressed: _isGenerating || _isLoading
                        ? null
                        : _generate45AkunOtomatis,
                    icon: _isGenerating
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.flash_on, color: Colors.white),
                    label: Text(
                      _isGenerating
                          ? 'MEMBUAT AKUN $_generationProgress/46...'
                          : 'GENERATE 46 AKUN SEKARANG',
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // ===============================================================

          const Text('📢 Siarkan Papan Pengumuman',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primary)),
          const SizedBox(height: 12),
          TextField(
              controller: _pengumumanController,
              maxLines: 3,
              decoration: const InputDecoration(
                  labelText: 'Tulis isi pengumuman...',
                  alignLabelWithHint: true)),
          const SizedBox(height: 12),
          if (_namaFilePengumuman.isNotEmpty)
            Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text('Lampiran: $_namaFilePengumuman',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, color: AppTheme.primary))),
          OutlinedButton.icon(
            onPressed: () => _pilihFileBebas(true),
            icon: const Icon(Icons.attach_file_rounded),
            label: const Text('Lampirkan Berkas (PDF, Word, Excel, Foto)'),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: _isLoading ? null : _kirimPengumuman,
            icon: const Icon(Icons.campaign_rounded, color: Colors.white),
            label: const Text('Kirim Pengumuman'),
          ),

          const Divider(height: 48, thickness: 1.5),

          const Text('📅 Tambah Agenda / Kalender Pondok',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primary)),
          const SizedBox(height: 12),
          TextField(
              controller: _agendaJudulController,
              decoration: const InputDecoration(
                  labelText: 'Judul Agenda (Cth: Ujian Semester)')),
          const SizedBox(height: 12),
          TextField(
              controller: _agendaTglController,
              decoration: const InputDecoration(
                  labelText: 'Tanggal (Cth: 20-25 November 2026)')),
          const SizedBox(height: 12),
          TextField(
              controller: _agendaDescController,
              maxLines: 2,
              decoration: const InputDecoration(
                  labelText: 'Keterangan tambahan...',
                  alignLabelWithHint: true)),
          const SizedBox(height: 12),
          if (_namaFileAgenda.isNotEmpty)
            Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text('Lampiran: $_namaFileAgenda',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, color: AppTheme.primary))),
          OutlinedButton.icon(
            onPressed: () => _pilihFileBebas(false),
            icon: const Icon(Icons.attach_file_rounded),
            label: const Text('Lampirkan Berkas Agenda'),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.warning),
            onPressed: _isLoading ? null : _kirimAgenda,
            icon:
                const Icon(Icons.event_available_rounded, color: Colors.white),
            label: const Text('Simpan Agenda Pondok'),
          ),
        ],
      ),
    );
  }
}
