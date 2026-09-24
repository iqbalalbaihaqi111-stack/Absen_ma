import 'package:cloud_firestore/cloud_firestore.dart';

Map<String, dynamic> sanitizeFirestoreData(Map<String, dynamic> data) {
  final result = <String, dynamic>{};
  for (final entry in data.entries) {
    final key = entry.key.trim();
    if (key.isEmpty ||
        key.contains('/') ||
        key.contains('.') ||
        key.contains('__')) {
      continue;
    }
    final value = _sanitizeFirestoreValue(entry.value);
    if (value != null) result[key] = value;
  }
  return result;
}

dynamic _sanitizeFirestoreValue(dynamic value) {
  if (value == null) return null;
  if (value is String)
    return value.trim().isEmpty ? 'Belum diisi' : value.trim();
  if (value is bool ||
      value is num ||
      value is Timestamp ||
      value is GeoPoint ||
      value is DocumentReference) {
    return value;
  }
  if (value is List) {
    return value
        .map(_sanitizeFirestoreValue)
        .where((item) => item != null)
        .toList();
  }
  if (value is Map) {
    final nested = <String, dynamic>{};
    value.forEach((key, item) {
      if (key is! String) return;
      final cleanKey = key.trim();
      if (cleanKey.isEmpty ||
          cleanKey.contains('/') ||
          cleanKey.contains('.') ||
          cleanKey.contains('__')) return;
      final cleanValue = _sanitizeFirestoreValue(item);
      if (cleanValue != null) nested[cleanKey] = cleanValue;
    });
    return nested;
  }
  return null;
}
