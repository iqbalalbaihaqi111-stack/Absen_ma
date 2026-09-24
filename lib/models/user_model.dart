class UserModel {
  final String uid;
  final String nama;
  final String nip;
  final String role; // 'admin' atau 'guru'
  final bool isActive;

  UserModel({
    required this.uid,
    required this.nama,
    required this.nip,
    required this.role,
    required this.isActive,
  });

  factory UserModel.fromMap(Map<String, dynamic> data, String documentId) {
    return UserModel(
      uid: documentId,
      nama: data['nama'] ?? 'Tanpa Nama',
      nip: data['nip'] ?? '',
      role: data['role'] ?? 'guru',
      isActive: data['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'nama': nama,
      'nip': nip,
      'role': role,
      'isActive': isActive,
    };
  }

  bool get isAdmin => role == 'admin';
}