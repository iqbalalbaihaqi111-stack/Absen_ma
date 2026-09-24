import 'package:geolocator/geolocator.dart';

class LocationService {
  final double _madrasahLat = -2.912324;
  final double _madrasahLon = 104.577556;
  final double _radiusMaksimal = 2000; // 2 KM

  Future<Map<String, dynamic>> cekLokasiAbsen() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return {'valid': false, 'pesan': 'GPS tidak aktif!'};

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return {'valid': false, 'pesan': 'Izin akses lokasi ditolak.'};
      }

      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      
      if (position.isMocked) return {'valid': false, 'pesan': 'Terdeteksi Aplikasi Fake GPS! Absen ditolak.'};

      double jarakInMeters = Geolocator.distanceBetween(
        position.latitude, position.longitude, _madrasahLat, _madrasahLon,
      );

      if (jarakInMeters <= _radiusMaksimal) {
        return {
          'valid': true, 
          'pesan': 'Anda dalam radius madrasah',
          'latitude': position.latitude,
          'longitude': position.longitude,
          'accuracy': position.accuracy,
          'jarak': jarakInMeters,
        };
      } else {
        return {'valid': false, 'pesan': 'Anda di luar radius 2 KM!'};
      }
    } catch (e) {
      return {'valid': false, 'pesan': 'Gagal membaca GPS: $e'};
    }
  }
}