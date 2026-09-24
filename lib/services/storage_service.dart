import 'dart:io';
import 'dart:convert';

import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:firebase_storage/firebase_storage.dart';

class StorageService {
  // Upload Foto Absen (Masuk / Pulang)
  Future<String> uploadFotoAbsen(
    File foto,
    String uid,
    String tanggal,
    String tipe,
  ) async {
    try {
      return await _upload(foto, 'absensi/$uid/$tanggal/$tipe');
    } catch (e) {
      throw Exception('Gagal memproses foto absensi: $e');
    }
  }

  // Upload Bukti Izin / Sakit
  Future<String> uploadBuktiIzin(
    File foto,
    String uid,
    String requestId,
  ) async {
    try {
      return await _upload(foto, 'perizinan/$uid/$requestId');
    } catch (e) {
      throw Exception('Gagal memproses bukti izin: $e');
    }
  }

  // Upload Berkas Apapun (PDF, Excel, Word, Gambar, dll)
  Future<Map<String, String>> uploadGeneralFile(
    File file,
    String folder,
    String docId,
  ) async {
    try {
      if (!file.existsSync()) {
        throw Exception(
            'Berkas tidak ditemukan di perangkat. Pilih ulang berkasnya.');
      }
      String originalName = file.path.split(RegExp(r'[/\\]')).last;
      final url = await _upload(file, '$folder/$docId');

      return {
        'url': url,
        'name': originalName,
        'ext': originalName.split('.').last.toLowerCase(),
      };
    } catch (e) {
      throw Exception('Gagal memproses berkas: $e');
    }
  }

  Future<String> _upload(File file, String path) async {
    if (!file.existsSync()) {
      throw Exception(
          'Berkas tidak ditemukan di perangkat. Pilih ulang berkasnya.');
    }
    final name = file.path.split(RegExp(r'[/\\]')).last;
    final ref = FirebaseStorage.instance.ref().child('$path/$name');
    final result = await ref.putFile(file);
    return await result.ref.getDownloadURL();
  }

  /// Opens an attachment that is stored either as a URL or as base64 text.
  /// Base64 attachments are written to the temporary directory, not app storage.
  Future<void> downloadAndOpen(String content, String originalName) async {
    final name = originalName
        .split(RegExp(r'[/\\]'))
        .last
        .replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    if (name.isEmpty || name == '.' || name == '..') {
      throw Exception('Nama berkas tidak valid.');
    }

    final uri = Uri.tryParse(content);
    late final List<int> bytes;
    if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
      final client = HttpClient();
      try {
        final request = await client.getUrl(uri);
        final response = await request.close();
        if (response.statusCode < 200 || response.statusCode >= 300) {
          throw Exception('Unduhan gagal (HTTP ${response.statusCode}).');
        }
        bytes = await response.fold<List<int>>(<int>[], (all, chunk) {
          all.addAll(chunk);
          return all;
        });
      } finally {
        client.close(force: true);
      }
    } else {
      var encoded = content.trim();
      final comma = encoded.indexOf(',');
      if (encoded.startsWith('data:') && comma >= 0) {
        encoded = encoded.substring(comma + 1);
      }
      try {
        bytes = base64Decode(encoded);
      } on FormatException {
        throw Exception('Lampiran bukan URL atau base64 yang valid.');
      }
    }

    final directory = await getTemporaryDirectory();
    final file = File(
      '${directory.path}${Platform.pathSeparator}${DateTime.now().millisecondsSinceEpoch}_$name',
    );
    await file.writeAsBytes(bytes, flush: true);
    final result = await OpenFilex.open(file.path);
    if (result.type != ResultType.done) {
      throw Exception(
        result.message.isEmpty
            ? 'Tidak ada aplikasi untuk membuka jenis berkas ini.'
            : result.message,
      );
    }
  }
}
