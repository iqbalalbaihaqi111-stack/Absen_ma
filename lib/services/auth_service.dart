import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<UserCredential> login(String nip, String password) async {
    try {
      if (nip == '1') {
        if (password != 'ADMINMA2026') throw Exception('Gagal: Kata sandi Admin salah!');
      } else {
        if (password != 'MA2026') throw Exception('Gagal: Kata sandi Guru salah!');
      }

      String email = '$nip@sabilulhasanah.com';
      return await _auth.signInWithEmailAndPassword(email: email, password: password);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found' || e.code == 'invalid-credential') {
        throw Exception('Nomor Urut belum didaftarkan di database!');
      }
      throw Exception('Gagal terhubung ke sistem: ${e.message}');
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<void> logout() async {
    await _auth.signOut();
  }
}