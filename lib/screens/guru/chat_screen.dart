import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../services/storage_service.dart';
import '../../utils/firestore_sanitizer.dart';
import '../../utils/theme.dart';

class ChatScreen extends StatefulWidget {
  final String namaPengguna;
  final bool isAdmin;

  const ChatScreen({
    super.key,
    required this.namaPengguna,
    required this.isAdmin,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _pesanController = TextEditingController();
  final StorageService _storageService = StorageService();
  final Map<String, Future<String>> _senderNameCache = {};
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _chatStream;

  File? _fileDipilih;
  String _namaFileDipilih = '';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Pertahankan satu stream sepanjang umur halaman agar pesan baru langsung
    // masuk tanpa harus keluar dan membuka chat lagi.
    _chatStream = FirebaseFirestore.instance
        .collection('chats')
        .orderBy('waktu', descending: true)
        .snapshots();
  }

  @override
  void dispose() {
    _pesanController.dispose();
    super.dispose();
  }

  Future<void> _lampirkanDanKirimFileBebas() async {
    try {
      final result = await FilePicker.pickFiles(type: FileType.any);
      if (!mounted || result.isEmpty || result.first.path == null) return;
      setState(() {
        _fileDipilih = File(result.first.path!);
        _namaFileDipilih = result.first.name;
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal memilih berkas: $error'),
          backgroundColor: AppTheme.error,
        ),
      );
    }
  }

  Future<void> _kirimPesan() async {
    if (_pesanController.text.trim().isEmpty && _fileDipilih == null) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Silakan login kembali untuk mengirim pesan.')),
      );
      return;
    }
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      var senderName = widget.namaPengguna;
      final profile = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (!mounted) return;
      final storedName = profile.data()?['nama'];
      if (storedName is String && storedName.trim().isNotEmpty) {
        senderName = storedName.trim();
      }
      if (senderName.trim().isEmpty || senderName.toLowerCase() == 'pengguna') {
        senderName = 'Pengirim';
      }

      final docId = DateTime.now().microsecondsSinceEpoch.toString();
      var fileUrl = '';
      var fileName = '';
      var fileExt = '';
      String? attachmentWarning;
      if (_fileDipilih != null) {
        if (!_fileDipilih!.existsSync()) {
          if (_pesanController.text.trim().isEmpty) {
            throw StateError('Berkas tidak ditemukan. Pilih ulang berkasnya.');
          }
          attachmentWarning =
              'Berkas tidak ditemukan; pesan teks tetap dikirim.';
        } else {
          try {
            final uploaded = await _storageService.uploadGeneralFile(
              _fileDipilih!,
              'chat_files',
              docId,
            );
            if (!mounted) return;
            fileUrl = uploaded['url'] ?? '';
            fileName = uploaded['name'] ?? _namaFileDipilih;
            fileExt = uploaded['ext'] ?? '';
            if (fileUrl.trim().isEmpty) {
              throw StateError('URL unduhan lampiran kosong.');
            }
          } catch (error) {
            if (_pesanController.text.trim().isEmpty) rethrow;
            fileUrl = '';
            fileName = '';
            fileExt = '';
            attachmentWarning =
                'Lampiran gagal diunggah; pesan teks tetap dikirim.';
          }
        }
      }

      final message = <String, dynamic>{
        'senderId': user.uid,
        'senderName': senderName,
        'waktu': Timestamp.now(),
      };
      if (_pesanController.text.trim().isNotEmpty) {
        message['pesan'] = _pesanController.text.trim();
      }
      if (fileUrl.trim().isNotEmpty) {
        message.addAll({
          'fileUrl': fileUrl.trim(),
          'fileName':
              fileName.trim().isEmpty ? _namaFileDipilih : fileName.trim(),
          'fileExt': fileExt.trim(),
        });
      }
      await FirebaseFirestore.instance
          .collection('chats')
          .doc(docId)
          .set(sanitizeFirestoreData(message));
      if (!mounted) return;
      _pesanController.clear();
      setState(() {
        _fileDipilih = null;
        _namaFileDipilih = '';
      });
      if (attachmentWarning != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(attachmentWarning)),
        );
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal mengirim pesan: $error'),
          backgroundColor: AppTheme.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _bukaFile(String content, String name) async {
    try {
      await _storageService.downloadAndOpen(content, name);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Tidak dapat membuka lampiran: $error'),
          backgroundColor: AppTheme.error,
        ),
      );
    }
  }

  Future<String> _resolveSenderName(String senderId) =>
      _senderNameCache.putIfAbsent(senderId, () async {
        try {
          final profile = await FirebaseFirestore.instance
              .collection('users')
              .doc(senderId)
              .get();
          final name = profile.data()?['nama'];
          if (name is String && name.trim().isNotEmpty) return name.trim();
        } catch (_) {}
        return 'Pengirim';
      });

  Widget _senderName(Map<String, dynamic> data) {
    final stored = (data['senderName'] ?? '').toString().trim();
    final isGeneric = stored.isEmpty ||
        stored.toLowerCase() == 'pengguna' ||
        stored.toLowerCase() == 'bapak / ibu guru';
    if (!isGeneric) {
      return Text(
        stored,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 12,
          color: AppTheme.primary,
        ),
      );
    }
    final senderId = (data['senderId'] ?? '').toString();
    if (senderId.isEmpty) return const Text('Pengirim');
    return FutureBuilder<String>(
      future: _resolveSenderName(senderId),
      builder: (context, snapshot) => Text(
        snapshot.data ?? 'Memuat nama…',
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 12,
          color: AppTheme.primary,
        ),
      ),
    );
  }

  bool _isImage(Map<String, dynamic> data) {
    final name = (data['fileName'] ?? '').toString().toLowerCase();
    final ext = (data['fileExt'] ?? '').toString().toLowerCase().replaceFirst(
          '.',
          '',
        );
    return const {'jpg', 'jpeg', 'png'}.contains(ext) ||
        const ['.jpg', '.jpeg', '.png'].any(name.endsWith);
  }

  Widget _imageAttachment(String content, String name) {
    final trimmed = content.trim();
    if (trimmed.isEmpty || trimmed == 'Belum diisi') {
      return const SizedBox.shrink();
    }
    final uri = Uri.tryParse(trimmed);
    if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
      return InkWell(
        onTap: () => _bukaFile(content, name),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.network(
            trimmed,
            width: 240,
            height: 190,
            fit: BoxFit.cover,
            loadingBuilder: (context, child, progress) => progress == null
                ? child
                : const SizedBox(
                    width: 240,
                    height: 150,
                    child: Center(child: CircularProgressIndicator()),
                  ),
            errorBuilder: (context, error, stackTrace) => _imageError(name),
          ),
        ),
      );
    }

    try {
      var encoded = trimmed;
      final comma = encoded.indexOf(',');
      if (encoded.startsWith('data:') && comma >= 0) {
        encoded = encoded.substring(comma + 1);
      }
      final bytes = base64Decode(encoded);
      return InkWell(
        onTap: () => _bukaFile(trimmed, name),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.memory(
            bytes,
            width: 240,
            height: 190,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => _imageError(name),
          ),
        ),
      );
    } on FormatException {
      return _imageError(name);
    }
  }

  Widget _imageError(String name) => Container(
        constraints: const BoxConstraints(maxWidth: 240),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.image_not_supported_outlined, color: Colors.grey),
            const SizedBox(width: 8),
            Flexible(child: Text('$name tidak dapat dimuat')),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('GRUP MA SABILUL HASANAH')),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _chatStream,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text('Chat gagal dimuat: ${snapshot.error}'),
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = snapshot.data!.docs;
                if (docs.isEmpty) {
                  return const Center(
                    child: Text(
                      'Belum ada percakapan. Mulai diskusi sekarang!',
                    ),
                  );
                }
                final currentUser = FirebaseAuth.instance.currentUser;
                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data();
                    final isMe = currentUser != null &&
                        data['senderId'] == currentUser.uid;
                    final rawFileUrl =
                        (data['fileUrl'] ?? '').toString().trim();
                    final fileUrl =
                        rawFileUrl == 'Belum diisi' ? '' : rawFileUrl;
                    final fileName =
                        (data['fileName'] ?? 'lampiran').toString();
                    return Align(
                      alignment:
                          isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.all(12),
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * .75,
                        ),
                        decoration: BoxDecoration(
                          color: isMe
                              ? AppTheme.primary.withOpacity(.15)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _senderName(data),
                            const SizedBox(height: 4),
                            if ((data['pesan'] ?? '').toString().isNotEmpty)
                              Text(
                                data['pesan'].toString(),
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                            if (fileUrl.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              if (_isImage(data))
                                _imageAttachment(fileUrl, fileName)
                              else
                                InkWell(
                                  onTap: () => _bukaFile(fileUrl, fileName),
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.insert_drive_file,
                                          color: AppTheme.primary,
                                        ),
                                        const SizedBox(width: 8),
                                        Flexible(
                                          child: Text(
                                            fileName,
                                            style: const TextStyle(
                                              color: AppTheme.primary,
                                              fontSize: 12,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          if (_fileDipilih != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.grey.shade200,
              child: Row(
                children: [
                  const Icon(Icons.attach_file, color: AppTheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _namaFileDipilih,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.red, size: 18),
                    onPressed: () => setState(() {
                      _fileDipilih = null;
                      _namaFileDipilih = '';
                    }),
                  ),
                ],
              ),
            ),
          Container(
            padding: const EdgeInsets.all(8),
            color: Colors.white,
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(
                    Icons.attach_file_rounded,
                    color: AppTheme.primary,
                  ),
                  onPressed: _isLoading ? null : _lampirkanDanKirimFileBebas,
                ),
                Expanded(
                  child: TextField(
                    controller: _pesanController,
                    decoration: const InputDecoration(
                      hintText: 'Tulis pesan atau diskusi...',
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 8),
                    ),
                  ),
                ),
                IconButton(
                  icon: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send_rounded, color: AppTheme.primary),
                  onPressed: _isLoading ? null : _kirimPesan,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
