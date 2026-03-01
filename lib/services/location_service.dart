import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class LocationService {
  static Future<Map<String, dynamic>> getLocationData() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return _fallbackLocation();
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return _fallbackLocation();
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return _fallbackLocation();
      }

      Position pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );

      String locationStr = await _reverseGeocode(pos.latitude, pos.longitude);

      return {
        'location': locationStr,
        'lat': pos.latitude,
        'lon': pos.longitude,
        'granted': true,
      };
    } catch (e) {
      return _fallbackLocation();
    }
  }

  static Future<String> _reverseGeocode(double lat, double lon) async {
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse'
        '?format=json&lat=$lat&lon=$lon&zoom=12',
      );
      final response = await http.get(
        url,
        headers: {'Accept-Language': 'en', 'User-Agent': 'AgriVerseAI/3.0'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final address = data['address'];
        if (address != null) {
          final city = address['city'] ??
              address['town'] ??
              address['village'] ??
              address['county'] ??
              address['state'];
          final country = address['country'];
          if (city != null && country != null) return '$city, $country';
          if (country != null) return country;
        }
      }
    } catch (_) {}
    return 'GPS Sector ($lat, $lon)';
  }

  static Map<String, dynamic> _fallbackLocation() {
    return {
      'location': 'Location Unavailable',
      'lat': 0.0,
      'lon': 0.0,
      'granted': false,
    };
  }

  static Future<bool> requestPermission() async {
    LocationPermission permission = await Geolocator.requestPermission();
    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }
}
