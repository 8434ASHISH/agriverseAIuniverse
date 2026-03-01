import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';

/// Rich flood + drought data model
class FloodDroughtData {
  // Flood
  final String floodLevel; // Low | Moderate | High | Extreme
  final double riverDischarge; // m³/s from Open-Meteo flood API
  final double precipNext24h; // mm expected in next 24h
  final double soilMoisture; // percentage (0-100)
  final String floodAdvisory; // Gemini AI advisory text
  final List<String> floodActions; // Immediate actions

  // Drought
  final String droughtLevel; // None | Watch | Warning | Emergency
  final int droughtIndex; // 0-100 (higher = more drought)
  final double rain7d; // Total rainfall last 7 days
  final double rain14d; // Total rainfall last 14 days
  final String droughtAdvisory; // Gemini AI advisory text
  final List<String> droughtActions; // Immediate actions

  // Shared
  final String locationName;
  final double lat;
  final double lon;
  final double tempC;
  final int humidity;

  FloodDroughtData({
    required this.floodLevel,
    required this.riverDischarge,
    required this.precipNext24h,
    required this.soilMoisture,
    required this.floodAdvisory,
    required this.floodActions,
    required this.droughtLevel,
    required this.droughtIndex,
    required this.rain7d,
    required this.rain14d,
    required this.droughtAdvisory,
    required this.droughtActions,
    required this.locationName,
    required this.lat,
    required this.lon,
    required this.tempC,
    required this.humidity,
  });
}

class FloodService {
  static String get _awKey => dotenv.env['ACCUWEATHER_API_KEY'] ?? '';
  static String get _geminiKey => dotenv.env['GEMINI_API_KEY'] ?? '';
  static const String _awBase = 'https://dataservice.accuweather.com';
  static const String _geminiBase =
      'https://generativelanguage.googleapis.com/v1beta/models';

  // ─── Get GPS ────────────────────────────────────────────────────────────
  static Future<Position> _getPosition() async {
    return await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 15),
      ),
    );
  }

  // ─── AccuWeather location key ────────────────────────────────────────────
  static Future<Map<String, String>> _getLocationKey(
      double lat, double lon) async {
    try {
      final url = Uri.parse(
        '$_awBase/locations/v1/cities/geoposition/search'
        '?apikey=$_awKey&q=$lat,$lon&toplevel=true',
      );
      final res = await http.get(url).timeout(const Duration(seconds: 15));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        return {
          'key': data['Key'] ?? '',
          'name':
              '${data['LocalizedName'] ?? ''}, ${data['AdministrativeArea']?['LocalizedName'] ?? ''}',
        };
      }
    } catch (_) {}
    return {'key': '', 'name': 'Your Location'};
  }

  // ─── AccuWeather: 1-day hourly for next 24h precip ──────────────────────
  static Future<double> _getNext24hPrecip(String locationKey) async {
    try {
      if (locationKey.isEmpty) return 0.0;
      final url = Uri.parse(
        '$_awBase/forecasts/v1/hourly/12hour/$locationKey'
        '?apikey=$_awKey&metric=true&details=true',
      );
      final res = await http.get(url).timeout(const Duration(seconds: 15));
      if (res.statusCode == 200) {
        final list = jsonDecode(res.body) as List;
        double total = 0;
        for (final h in list) {
          total +=
              (h['TotalLiquid']?['Value'] as num?)?.toDouble() ?? 0.0;
        }
        return total;
      }
    } catch (_) {}
    return 0.0;
  }

  // ─── Open-Meteo: River discharge (flood) ────────────────────────────────
  static Future<double> _fetchRiverDischarge(double lat, double lon) async {
    try {
      final url = Uri.parse(
        'https://api.open-meteo.com/v1/flood'
        '?latitude=$lat&longitude=$lon'
        '&daily=river_discharge'
        '&forecast_days=7',
      );
      final res = await http.get(url).timeout(const Duration(seconds: 15));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final List<dynamic> discharges =
            data['daily']?['river_discharge'] ?? [];
        double maxD = 0;
        for (var d in discharges) {
          final v = (d as num?)?.toDouble() ?? 0.0;
          if (v > maxD) maxD = v;
        }
        return maxD;
      }
    } catch (_) {}
    return 0.0;
  }

  // ─── Open-Meteo: Extended rain totals (for drought index) ───────────────
  static Future<Map<String, double>> _fetchRainTotals(
      double lat, double lon) async {
    try {
      final url = Uri.parse(
        'https://api.open-meteo.com/v1/forecast'
        '?latitude=$lat&longitude=$lon'
        '&daily=precipitation_sum,et0_fao_evapotranspiration,'
        'soil_moisture_0_to_7cm'
        '&past_days=14'
        '&forecast_days=7'
        '&timezone=Asia%2FKolkata',
      );
      final res = await http.get(url).timeout(const Duration(seconds: 15));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final rains =
            (data['daily']?['precipitation_sum'] as List<dynamic>?) ?? [];
        final moistures =
            (data['daily']?['soil_moisture_0_to_7cm'] as List<dynamic>?) ??
                [];

        // Past 14 days = indices 0..13, past 7 = indices 7..13
        double rain14d = 0;
        double rain7d = 0;
        int total = rains.length;
        for (int i = 0; i < total && i < 14; i++) {
          final r = (rains[i] as num?)?.toDouble() ?? 0.0;
          if (i >= total - 14) rain14d += r;
          if (i >= total - 7) rain7d += r;
        }

        // Latest soil moisture reading
        double moisture = 0.3;
        for (var m in moistures.reversed) {
          if (m != null) {
            moisture = (m as num).toDouble();
            break;
          }
        }

        return {
          'rain7d': rain7d,
          'rain14d': rain14d,
          'soilMoisture': (moisture * 100).clamp(0, 100),
        };
      }
    } catch (_) {}
    return {'rain7d': 0, 'rain14d': 0, 'soilMoisture': 30.0};
  }

  // ─── Gemini: AI advisory for flood ──────────────────────────────────────
  static Future<Map<String, dynamic>> _getFloodAdvisory({
    required String location,
    required double riverDischarge,
    required double precipNext24h,
    required double rain7d,
    required double tempC,
    required int humidity,
    required String floodLevel,
  }) async {
    try {
      final url =
          '$_geminiBase/gemini-1.5-flash:generateContent?key=$_geminiKey';
      final body = jsonEncode({
        'contents': [
          {
            'parts': [
              {
                'text': '''You are AgriVerse Flood AI. Analyze this data and return JSON ONLY.

Location: $location
River Discharge: ${riverDischarge.toStringAsFixed(1)} m³/s
Expected Rain (next 24h): ${precipNext24h.toStringAsFixed(1)} mm
Total Rain (last 7 days): ${rain7d.toStringAsFixed(1)} mm
Temperature: ${tempC.toStringAsFixed(1)}°C
Humidity: $humidity%
Flood Level: $floodLevel

Return this exact JSON:
{
  "advisory": "2-3 sentence expert advisory for farmers about current flood conditions",
  "actions": ["Action 1 for farmer", "Action 2 for farmer", "Action 3 for farmer"]
}'''
              }
            ]
          }
        ],
        'generationConfig': {
          'temperature': 0.3,
          'maxOutputTokens': 400,
        }
      });
      final res = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: body,
      ).timeout(const Duration(seconds: 20));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        String text = data['candidates']?[0]?['content']?['parts']?[0]?['text'] as String? ?? '';
        text = text.trim().replaceAll(RegExp(r'```json\s*'), '').replaceAll(RegExp(r'```\s*'), '').trim();
        return jsonDecode(text) as Map<String, dynamic>;
      }
    } catch (_) {}
    return {
      'advisory': 'Monitor water levels closely. Stay updated with local authorities on flood alerts.',
      'actions': ['Check drainage channels', 'Move livestock to higher ground if level is High', 'Secure farm equipment'],
    };
  }

  // ─── Gemini: AI advisory for drought ────────────────────────────────────
  static Future<Map<String, dynamic>> _getDroughtAdvisory({
    required String location,
    required double rain7d,
    required double rain14d,
    required double soilMoisture,
    required double tempC,
    required int humidity,
    required String droughtLevel,
    required int droughtIndex,
  }) async {
    try {
      final url =
          '$_geminiBase/gemini-1.5-flash:generateContent?key=$_geminiKey';
      final body = jsonEncode({
        'contents': [
          {
            'parts': [
              {
                'text': '''You are AgriVerse Drought AI. Analyze this data and return JSON ONLY.

Location: $location
Drought Level: $droughtLevel (Index: $droughtIndex/100)
Rainfall last 7 days: ${rain7d.toStringAsFixed(1)} mm
Rainfall last 14 days: ${rain14d.toStringAsFixed(1)} mm
Soil Moisture: ${soilMoisture.toStringAsFixed(1)}%
Temperature: ${tempC.toStringAsFixed(1)}°C
Humidity: $humidity%

Return this exact JSON:
{
  "advisory": "2-3 sentence expert drought advisory for farmers with specific crops/irrigation guidance",
  "actions": ["Specific action 1 for farmer", "Specific action 2", "Specific action 3"]
}'''
              }
            ]
          }
        ],
        'generationConfig': {
          'temperature': 0.3,
          'maxOutputTokens': 400,
        }
      });
      final res = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: body,
      ).timeout(const Duration(seconds: 20));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        String text = data['candidates']?[0]?['content']?['parts']?[0]?['text'] as String? ?? '';
        text = text.trim().replaceAll(RegExp(r'```json\s*'), '').replaceAll(RegExp(r'```\s*'), '').trim();
        return jsonDecode(text) as Map<String, dynamic>;
      }
    } catch (_) {}
    return {
      'advisory': 'Water stress detected. Prioritize irrigation for standing crops and conserve soil moisture.',
      'actions': ['Start drip irrigation', 'Apply mulch to reduce evaporation', 'Shift to drought-resistant varieties'],
    };
  }

  // ─── MAIN: Full flood + drought data ────────────────────────────────────
  static Future<FloodDroughtData> fetchFloodDroughtData() async {
    final pos = await _getPosition();
    final lat = pos.latitude;
    final lon = pos.longitude;

    // Parallel: location key + rain totals + river discharge
    final results = await Future.wait([
      _getLocationKey(lat, lon),
      _fetchRainTotals(lat, lon),
      _fetchRiverDischarge(lat, lon),
    ]);

    final locInfo = results[0] as Map<String, String>;
    final rainData = results[1] as Map<String, double>;
    final riverDischarge = results[2] as double;
    final locationKey = locInfo['key'] ?? '';
    final locationName = locInfo['name'] ?? 'Your Location';

    // Next 24h precip from AccuWeather
    double precipNext24h = await _getNext24hPrecip(locationKey);

    final rain7d = rainData['rain7d'] ?? 0.0;
    final rain14d = rainData['rain14d'] ?? 0.0;
    final soilMoisture = rainData['soilMoisture'] ?? 30.0;

    // Get current temp/humidity from Open-Meteo (fast fallback)
    double tempC = 28.0;
    int humidity = 65;
    try {
      final omUrl = Uri.parse(
        'https://api.open-meteo.com/v1/forecast'
        '?latitude=$lat&longitude=$lon'
        '&current=temperature_2m,relative_humidity_2m'
        '&timezone=Asia%2FKolkata',
      );
      final omRes = await http.get(omUrl).timeout(const Duration(seconds: 10));
      if (omRes.statusCode == 200) {
        final d = jsonDecode(omRes.body);
        tempC = (d['current']?['temperature_2m'] as num?)?.toDouble() ?? 28.0;
        humidity = (d['current']?['relative_humidity_2m'] as num?)?.toInt() ?? 65;
      }
    } catch (_) {}

    // ── Flood Classification ────────────────────────────────────────────
    String floodLevel;
    if (riverDischarge > 120 || precipNext24h > 60) {
      floodLevel = 'Extreme';
    } else if (riverDischarge > 80 || precipNext24h > 35) {
      floodLevel = 'High';
    } else if (riverDischarge > 50 || precipNext24h > 15) {
      floodLevel = 'Moderate';
    } else {
      floodLevel = 'Low';
    }

    // ── Drought Classification ──────────────────────────────────────────
    // Drought index: 0 = no drought, 100 = extreme drought
    int droughtIndex = 0;
    if (rain7d < 2) droughtIndex += 40;
    else if (rain7d < 10) droughtIndex += 20;
    if (rain14d < 5) droughtIndex += 30;
    else if (rain14d < 20) droughtIndex += 15;
    if (soilMoisture < 15) droughtIndex += 20;
    else if (soilMoisture < 30) droughtIndex += 10;
    if (tempC > 38) droughtIndex += 10;
    droughtIndex = droughtIndex.clamp(0, 100);

    String droughtLevel;
    if (droughtIndex >= 70) {
      droughtLevel = 'Emergency';
    } else if (droughtIndex >= 45) {
      droughtLevel = 'Warning';
    } else if (droughtIndex >= 25) {
      droughtLevel = 'Watch';
    } else {
      droughtLevel = 'Normal';
    }

    // ── Gemini AI advisories (parallel) ────────────────────────────────
    final advisories = await Future.wait([
      _getFloodAdvisory(
        location: locationName,
        riverDischarge: riverDischarge,
        precipNext24h: precipNext24h,
        rain7d: rain7d,
        tempC: tempC,
        humidity: humidity,
        floodLevel: floodLevel,
      ),
      _getDroughtAdvisory(
        location: locationName,
        rain7d: rain7d,
        rain14d: rain14d,
        soilMoisture: soilMoisture,
        tempC: tempC,
        humidity: humidity,
        droughtLevel: droughtLevel,
        droughtIndex: droughtIndex,
      ),
    ]);

    final floodAdv = advisories[0];
    final droughtAdv = advisories[1];

    return FloodDroughtData(
      floodLevel: floodLevel,
      riverDischarge: riverDischarge,
      precipNext24h: precipNext24h,
      soilMoisture: soilMoisture,
      floodAdvisory: floodAdv['advisory'] as String? ??
          'Monitor flood levels closely.',
      floodActions: List<String>.from(
          (floodAdv['actions'] as List<dynamic>?) ?? []),
      droughtLevel: droughtLevel,
      droughtIndex: droughtIndex,
      rain7d: rain7d,
      rain14d: rain14d,
      droughtAdvisory: droughtAdv['advisory'] as String? ??
          'Monitor soil moisture levels.',
      droughtActions: List<String>.from(
          (droughtAdv['actions'] as List<dynamic>?) ?? []),
      locationName: locationName,
      lat: lat,
      lon: lon,
      tempC: tempC,
      humidity: humidity,
    );
  }

  // ─── Backward compat: plain FloodData for things that still need it ─────
  static Future<FloodData> fetchFloodData() async {
    try {
      final d = await fetchFloodDroughtData();
      String adv;
      if (d.floodLevel == 'Extreme' || d.floodLevel == 'High') {
        adv = '⚠️ ${d.floodLevel} flood risk. ${d.floodAdvisory}';
      } else if (d.floodLevel == 'Moderate') {
        adv = '⚡ Moderate flood risk. ${d.floodAdvisory}';
      } else {
        adv = '✅ ${d.floodAdvisory}';
      }
      return FloodData(
        floodLevel: d.floodLevel,
        dischargeValue: d.riverDischarge,
        advisory: adv,
      );
    } catch (e) {
      return FloodData(
        floodLevel: 'Unknown',
        dischargeValue: 0,
        advisory: 'Unable to fetch flood data. Please check your connection.',
      );
    }
  }
}

/// Old minimal model kept for backward compat
class FloodData {
  final String floodLevel;
  final double dischargeValue;
  final String advisory;

  FloodData({
    required this.floodLevel,
    required this.dischargeValue,
    required this.advisory,
  });
}
