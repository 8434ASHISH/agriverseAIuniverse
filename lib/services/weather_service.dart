import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';

/// Full weather data model powering Weather Intelligence + Drought screens
class WeatherData {
  final double tempC;
  final double feelsLikeC;
  final int humidity;
  final double windKph;
  final double precipMm;
  final String condition;
  final String conditionIcon;
  final int uvIndex;
  final double visibility;
  final double dewPoint;
  final String phrase; // AccuWeather phrase
  final bool hasPrecipitation;

  // 5-day forecast
  final List<DayForecast> forecast;

  // Derived risk values
  final String heatRisk;
  final String droughtRisk;
  final String floodRisk;
  final int riskScore; // 0-100
  final double totalRain7d;
  final double maxDailyRain;
  final double avgTemp3d;

  // Location key for AccuWeather
  final String locationKey;
  final String locationName;

  WeatherData({
    required this.tempC,
    required this.feelsLikeC,
    required this.humidity,
    required this.windKph,
    required this.precipMm,
    required this.condition,
    required this.conditionIcon,
    required this.uvIndex,
    required this.visibility,
    required this.dewPoint,
    required this.phrase,
    required this.hasPrecipitation,
    required this.forecast,
    required this.heatRisk,
    required this.droughtRisk,
    required this.floodRisk,
    required this.riskScore,
    required this.totalRain7d,
    required this.maxDailyRain,
    required this.avgTemp3d,
    required this.locationKey,
    required this.locationName,
  });
}

class DayForecast {
  final String date;
  final String dayName;
  final double maxTempC;
  final double minTempC;
  final double precipMm;
  final String condition;
  final int precipProb;
  final String icon;

  DayForecast({
    required this.date,
    required this.dayName,
    required this.maxTempC,
    required this.minTempC,
    required this.precipMm,
    required this.condition,
    required this.precipProb,
    required this.icon,
  });
}

/// Old minimal model kept for backward compat (HomeScreen uses this)
class WeatherRisk {
  final String heatRisk;
  final String droughtRisk;
  final String floodRisk;
  final int overallScore;
  final double avgTemp;
  final double totalRainfall;
  final String? maxDailyRain;

  WeatherRisk({
    required this.heatRisk,
    required this.droughtRisk,
    required this.floodRisk,
    required this.overallScore,
    required this.avgTemp,
    required this.totalRainfall,
    this.maxDailyRain,
  });
}

class WeatherService {
  static String get _awKey => dotenv.env['ACCUWEATHER_API_KEY'] ?? '';
  static const String _awBase = 'https://dataservice.accuweather.com';

  // ─── Get GPS Position ──────────────────────────────────────────────────────
  static Future<Position> _getPosition() async {
    return await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 15),
      ),
    );
  }

  // ─── AccuWeather: Get Location Key from lat/lon ────────────────────────────
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

  // ─── AccuWeather: Current Conditions ──────────────────────────────────────
  static Future<Map<String, dynamic>> _getCurrentConditions(
      String locationKey) async {
    final url = Uri.parse(
      '$_awBase/currentconditions/v1/$locationKey'
      '?apikey=$_awKey&details=true&metric=true',
    );
    final res = await http.get(url).timeout(const Duration(seconds: 15));
    if (res.statusCode == 200) {
      final list = jsonDecode(res.body) as List;
      return list.isNotEmpty ? list[0] as Map<String, dynamic> : {};
    }
    return {};
  }

  // ─── AccuWeather: 5-day daily forecast ────────────────────────────────────
  static Future<List<dynamic>> _get5DayForecast(String locationKey) async {
    final url = Uri.parse(
      '$_awBase/forecasts/v1/daily/5day/$locationKey'
      '?apikey=$_awKey&metric=true&details=true',
    );
    final res = await http.get(url).timeout(const Duration(seconds: 15));
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      return (data['DailyForecasts'] as List?) ?? [];
    }
    return [];
  }

  // ─── Open-Meteo: 7-day fallback for rain data ────────────────────────────
  static Future<Map<String, dynamic>> _getOpenMeteoRain(
      double lat, double lon) async {
    try {
      final url = Uri.parse(
        'https://api.open-meteo.com/v1/forecast'
        '?latitude=$lat&longitude=$lon'
        '&daily=temperature_2m_max,precipitation_sum'
        '&current=temperature_2m,relative_humidity_2m,precipitation,'
        'wind_speed_10m,weather_code'
        '&timezone=Asia%2FKolkata'
        '&forecast_days=7',
      );
      final res = await http.get(url).timeout(const Duration(seconds: 15));
      if (res.statusCode == 200) return jsonDecode(res.body);
    } catch (_) {}
    return {};
  }

  // ─── MAIN: Full weather data for WeatherIntelScreen ───────────────────────
  static Future<WeatherData> fetchFullWeatherData() async {
    final pos = await _getPosition();
    final lat = pos.latitude;
    final lon = pos.longitude;

    // Parallel: AccuWeather location key + Open-Meteo rain backup
    final results = await Future.wait([
      _getLocationKey(lat, lon),
      _getOpenMeteoRain(lat, lon),
    ]);

    final locInfo = results[0] as Map<String, String>;
    final omData = results[1] as Map<String, dynamic>;
    final locationKey = locInfo['key'] ?? '';
    final locationName = locInfo['name'] ?? 'Your Location';

    // AccuWeather current + forecast (parallel)
    Map<String, dynamic> current = {};
    List<dynamic> dailyForecasts = [];

    if (locationKey.isNotEmpty) {
      final awResults = await Future.wait([
        _getCurrentConditions(locationKey),
        _get5DayForecast(locationKey),
      ]);
      current = awResults[0] as Map<String, dynamic>;
      dailyForecasts = awResults[1] as List<dynamic>;
    }

    // ── Parse current conditions ──────────────────────────────────────────
    double tempC = (current['Temperature']?['Metric']?['Value'] as num?)
            ?.toDouble() ??
        (omData['current']?['temperature_2m'] as num?)?.toDouble() ??
        28.0;
    double feelsLike =
        (current['RealFeelTemperature']?['Metric']?['Value'] as num?)
                ?.toDouble() ??
            tempC;
    int humidity = (current['RelativeHumidity'] as num?)?.toInt() ??
        (omData['current']?['relative_humidity_2m'] as num?)?.toInt() ??
        65;
    double windKph = (current['Wind']?['Speed']?['Metric']?['Value'] as num?)
            ?.toDouble() ??
        (omData['current']?['wind_speed_10m'] as num?)?.toDouble() ??
        12.0;
    double precipMm =
        (current['Precip1hr']?['Metric']?['Value'] as num?)?.toDouble() ??
            (omData['current']?['precipitation'] as num?)?.toDouble() ??
            0.0;
    String phrase =
        current['WeatherText'] as String? ?? 'Partly Cloudy';
    bool hasPrecip = current['HasPrecipitation'] as bool? ?? false;
    int uvIndex = (current['UVIndex'] as num?)?.toInt() ?? 3;
    double visibility =
        (current['Visibility']?['Metric']?['Value'] as num?)?.toDouble() ??
            10.0;
    double dewPoint =
        (current['DewPoint']?['Metric']?['Value'] as num?)?.toDouble() ??
            18.0;
    int conditionIcon = (current['WeatherIcon'] as num?)?.toInt() ?? 6;
    String conditionIconStr = conditionIcon.toString().padLeft(2, '0');

    // ── Parse 5-day forecast ──────────────────────────────────────────────
    final List<DayForecast> forecastList = [];
    final omTemps =
        (omData['daily']?['temperature_2m_max'] as List<dynamic>?) ?? [];
    final omRains =
        (omData['daily']?['precipitation_sum'] as List<dynamic>?) ?? [];

    if (dailyForecasts.isNotEmpty) {
      for (int i = 0;
          i < dailyForecasts.length && i < 5;
          i++) {
        final day = dailyForecasts[i] as Map<String, dynamic>;
        final dateStr = day['Date'] as String? ?? '';
        final dt = DateTime.tryParse(dateStr) ?? DateTime.now().add(Duration(days: i));
        final dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
        final dayName = i == 0 ? 'Today' : dayNames[dt.weekday - 1];

        final maxT =
            (day['Temperature']?['Maximum']?['Value'] as num?)?.toDouble() ??
                28.0;
        final minT =
            (day['Temperature']?['Minimum']?['Value'] as num?)?.toDouble() ??
                20.0;
        final rain =
            (day['Day']?['TotalLiquid']?['Value'] as num?)?.toDouble() ??
                (omRains.length > i
                    ? (omRains[i] as num?)?.toDouble() ?? 0.0
                    : 0.0);
        final precipProb =
            (day['Day']?['PrecipitationProbability'] as num?)?.toInt() ?? 0;
        final cond = day['Day']?['IconPhrase'] as String? ?? 'Partly Cloudy';
        final icon = '${(day['Day']?['Icon'] as num?)?.toInt().toString().padLeft(2, '0') ?? '06'}';

        forecastList.add(DayForecast(
          date: '${dt.day}/${dt.month}',
          dayName: dayName,
          maxTempC: maxT,
          minTempC: minT,
          precipMm: rain,
          condition: cond,
          precipProb: precipProb,
          icon: icon,
        ));
      }
    } else {
      // Open-Meteo fallback
      for (int i = 0; i < 5 && i < omTemps.length; i++) {
        final dt = DateTime.now().add(Duration(days: i));
        final dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
        final dayName = i == 0 ? 'Today' : dayNames[dt.weekday - 1];
        forecastList.add(DayForecast(
          date: '${dt.day}/${dt.month}',
          dayName: dayName,
          maxTempC: (omTemps[i] as num?)?.toDouble() ?? 28.0,
          minTempC: ((omTemps[i] as num?)?.toDouble() ?? 28.0) - 6,
          precipMm:
              omRains.length > i ? (omRains[i] as num?)?.toDouble() ?? 0.0 : 0.0,
          condition: 'Partly Cloudy',
          precipProb: 0,
          icon: '06',
        ));
      }
    }

    // ── Compute risk metrics ──────────────────────────────────────────────
    double totalRain7d = 0;
    double maxDailyRain = 0;
    double avgTemp3d = 0;
    int tempCount = 0;

    for (int i = 0; i < forecastList.length; i++) {
      final rain = forecastList[i].precipMm;
      totalRain7d += rain;
      if (rain > maxDailyRain) maxDailyRain = rain;
      if (i < 3) {
        avgTemp3d += forecastList[i].maxTempC;
        tempCount++;
      }
    }
    avgTemp3d = tempCount > 0 ? avgTemp3d / tempCount : tempC;

    // Also use Open-Meteo daily rains if available and more days
    for (int i = forecastList.length; i < omRains.length && i < 7; i++) {
      final rain = (omRains[i] as num?)?.toDouble() ?? 0.0;
      totalRain7d += rain;
      if (rain > maxDailyRain) maxDailyRain = rain;
    }

    String heatRisk = avgTemp3d >= 38
        ? 'High'
        : avgTemp3d >= 33
            ? 'Moderate'
            : 'Low';
    String droughtRisk =
        totalRain7d < 5 ? 'High' : totalRain7d < 20 ? 'Moderate' : 'Low';
    String floodRisk = maxDailyRain > 70
        ? 'High'
        : maxDailyRain > 40
            ? 'Moderate'
            : 'Low';

    int score = 0;
    if (heatRisk == 'High') score += 35;
    else if (heatRisk == 'Moderate') score += 18;
    if (droughtRisk == 'High') score += 30;
    else if (droughtRisk == 'Moderate') score += 15;
    if (floodRisk == 'High') score += 35;
    else if (floodRisk == 'Moderate') score += 18;

    return WeatherData(
      tempC: tempC,
      feelsLikeC: feelsLike,
      humidity: humidity,
      windKph: windKph,
      precipMm: precipMm,
      condition: phrase,
      conditionIcon: conditionIconStr,
      uvIndex: uvIndex,
      visibility: visibility,
      dewPoint: dewPoint,
      phrase: phrase,
      hasPrecipitation: hasPrecip,
      forecast: forecastList,
      heatRisk: heatRisk,
      droughtRisk: droughtRisk,
      floodRisk: floodRisk,
      riskScore: score,
      totalRain7d: totalRain7d,
      maxDailyRain: maxDailyRain,
      avgTemp3d: avgTemp3d,
      locationKey: locationKey,
      locationName: locationName,
    );
  }

  // ─── Backward compat entry point (used by HomeScreen) ─────────────────────
  static Future<WeatherRisk> fetchWeatherRisk() async {
    try {
      final d = await fetchFullWeatherData();
      return WeatherRisk(
        heatRisk: d.heatRisk,
        droughtRisk: d.droughtRisk,
        floodRisk: d.floodRisk,
        overallScore: d.riskScore,
        avgTemp: d.avgTemp3d,
        totalRainfall: d.totalRain7d,
        maxDailyRain: d.maxDailyRain.toStringAsFixed(1),
      );
    } catch (e) {
      return WeatherRisk(
        heatRisk: 'Unknown',
        droughtRisk: 'Unknown',
        floodRisk: 'Unknown',
        overallScore: 0,
        avgTemp: 0,
        totalRainfall: 0,
        maxDailyRain: null,
      );
    }
  }

  // ─── Backward compat (used by HomeScreen) ─────────────────────────────────
  static Future<Map<String, dynamic>> fetchCurrentWeather() async {
    try {
      final pos = await _getPosition();
      final lat = pos.latitude;
      final lon = pos.longitude;
      final url = Uri.parse(
        'https://api.open-meteo.com/v1/forecast'
        '?latitude=$lat&longitude=$lon'
        '&current=temperature_2m,relative_humidity_2m,precipitation,'
        'wind_speed_10m,weather_code'
        '&timezone=Asia%2FKolkata',
      );
      final res = await http.get(url).timeout(const Duration(seconds: 15));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final current = data['current'] ?? {};
        int code = (current['weather_code'] as num?)?.toInt() ?? 0;
        return {
          'temp': (current['temperature_2m'] as num?)?.toDouble() ?? 28.0,
          'humidity': (current['relative_humidity_2m'] as num?)?.toInt() ?? 65,
          'precipitation': (current['precipitation'] as num?)?.toDouble() ?? 0.0,
          'windSpeed': (current['wind_speed_10m'] as num?)?.toDouble() ?? 12.0,
          'condition': _codeToCondition(code),
          'lat': lat,
          'lon': lon,
        };
      }
    } catch (_) {}
    return {
      'temp': 28.0,
      'humidity': 65,
      'precipitation': 0.0,
      'windSpeed': 12.0,
      'condition': 'Partly Cloudy',
      'lat': 0.0,
      'lon': 0.0,
    };
  }

  static String _codeToCondition(int code) {
    if (code == 0) return 'Clear Skies';
    if (code <= 3) return 'Partly Cloudy';
    if (code <= 48) return 'Foggy';
    if (code <= 57) return 'Light Drizzle';
    if (code <= 67) return 'Rainy';
    if (code <= 77) return 'Snowy';
    if (code <= 82) return 'Rain Showers';
    if (code <= 99) return 'Thunderstorm';
    return 'Unknown';
  }
}
