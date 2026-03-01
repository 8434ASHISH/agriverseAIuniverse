import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/weather_service.dart';
import '../services/location_service.dart';
import 'chat_screen.dart';
import 'emergency_screen.dart';

class WeatherIntelScreen extends StatefulWidget {
  const WeatherIntelScreen({super.key});

  @override
  State<WeatherIntelScreen> createState() => _WeatherIntelScreenState();
}

class _WeatherIntelScreenState extends State<WeatherIntelScreen>
    with SingleTickerProviderStateMixin {
  bool _loading = true;
  WeatherData? _data;
  String? _error;
  String _location = 'Detecting...';
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.95, end: 1.0).animate(_pulseCtrl);
    _load();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final locData = await LocationService.getLocationData();
      if (mounted) setState(() => _location = locData['location'] ?? 'Your Location');

      final data = await WeatherService.fetchFullWeatherData();
      if (mounted) {
        setState(() {
          _data = data;
          _location = data.locationName.isNotEmpty ? data.locationName : _location;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  Color _riskColor(String risk) {
    switch (risk.toLowerCase()) {
      case 'high':
      case 'extreme':
        return const Color(0xFFEF4444);
      case 'moderate':
        return const Color(0xFFF59E0B);
      case 'low':
        return const Color(0xFF22C55E);
      default:
        return Colors.grey;
    }
  }

  IconData _conditionIcon(String condition) {
    final c = condition.toLowerCase();
    if (c.contains('thunder')) return Icons.flash_on_rounded;
    if (c.contains('rain') || c.contains('drizzle') || c.contains('shower'))
      return Icons.water_drop_rounded;
    if (c.contains('snow')) return Icons.ac_unit_rounded;
    if (c.contains('fog') || c.contains('mist')) return Icons.blur_on_rounded;
    if (c.contains('cloud')) return Icons.cloud_rounded;
    if (c.contains('clear') || c.contains('sunny'))
      return Icons.wb_sunny_rounded;
    return Icons.cloud_queue_rounded;
  }

  Color _conditionColor(String condition) {
    final c = condition.toLowerCase();
    if (c.contains('thunder')) return const Color(0xFF7C3AED);
    if (c.contains('rain') || c.contains('drizzle') || c.contains('shower'))
      return const Color(0xFF3B82F6);
    if (c.contains('snow')) return const Color(0xFF93C5FD);
    if (c.contains('cloud')) return const Color(0xFF94A3B8);
    if (c.contains('clear') || c.contains('sunny'))
      return const Color(0xFFF59E0B);
    return const Color(0xFF22C55E);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B1120),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B1120),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Weather Intelligence',
          style: GoogleFonts.inter(
              fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF3B82F6)),
            onPressed: _load,
          ),
        ],
      ),
      body: _loading
          ? _buildLoading()
          : _error != null
              ? _buildError()
              : _buildContent(),
    );
  }

  Widget _buildLoading() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedBuilder(
            animation: _pulseAnim,
            builder: (_, __) => Transform.scale(
              scale: _pulseAnim.value,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.cloud_sync_rounded,
                    color: Color(0xFF3B82F6), size: 44),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Fetching Weather Intelligence',
            style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Colors.white70),
          ),
          const SizedBox(height: 8),
          Text(
            'AccuWeather • Open-Meteo • AI Analysis',
            style: GoogleFonts.inter(fontSize: 11, color: Colors.white38),
          ),
          const SizedBox(height: 24),
          const SizedBox(
            width: 160,
            child: LinearProgressIndicator(
              color: Color(0xFF3B82F6),
              backgroundColor: Color(0xFF1E293B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off_rounded,
                color: Color(0xFF3B82F6), size: 64),
            const SizedBox(height: 16),
            Text('Could not load weather data',
                style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(_error ?? '',
                style:
                    GoogleFonts.inter(color: Colors.white54, fontSize: 12),
                textAlign: TextAlign.center),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3B82F6),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12))),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    final d = _data!;
    return SingleChildScrollView(
      child: Column(
        children: [
          // ── Hero Header with temp ──────────────────────────────────
          _buildHeroCard(d),

          // ── 5-day Forecast ──────────────────────────────────────────
          _buildForecastRow(d),

          // ── Current Metrics Grid ────────────────────────────────────
          _buildMetricsGrid(d),

          // ── Risk Assessment ─────────────────────────────────────────
          _buildRiskSection(d),

          // ── Farming Advisory ────────────────────────────────────────
          _buildFarmingAdvisory(d),

          // ── Ask AI + Emergency buttons ──────────────────────────────
          _buildActionButtons(d),

          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildHeroCard(WeatherData d) {
    final condColor = _conditionColor(d.condition);
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            condColor.withValues(alpha: 0.25),
            const Color(0xFF1E293B),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: condColor.withValues(alpha: 0.3), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Location row
          Row(
            children: [
              const Icon(Icons.location_on_rounded,
                  color: Colors.white60, size: 14),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  _location,
                  style: GoogleFonts.inter(
                      fontSize: 12, color: Colors.white60),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: const Color(0xFF3B82F6).withValues(alpha: 0.4)),
                ),
                child: Text(
                  'ACCUWEATHER',
                  style: GoogleFonts.inter(
                      fontSize: 8,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF3B82F6),
                      letterSpacing: 1),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Temp + condition icon
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${d.tempC.toStringAsFixed(0)}',
                        style: GoogleFonts.inter(
                          fontSize: 72,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          height: 1.0,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(
                          '°C',
                          style: GoogleFonts.inter(
                              fontSize: 28,
                              fontWeight: FontWeight.w400,
                              color: Colors.white60),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    d.condition,
                    style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white),
                  ),
                  Text(
                    'Feels like ${d.feelsLikeC.toStringAsFixed(0)}°C',
                    style: GoogleFonts.inter(
                        fontSize: 12, color: Colors.white54),
                  ),
                ],
              ),
              const Spacer(),
              Icon(
                _conditionIcon(d.condition),
                color: condColor,
                size: 80,
              ),
            ],
          ),

          const SizedBox(height: 16),
          const Divider(color: Colors.white12),
          const SizedBox(height: 12),

          // Quick stats row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _quickStat(Icons.water_drop_rounded, '${d.humidity}%', 'Humidity'),
              _quickStat(Icons.air_rounded, '${d.windKph.toStringAsFixed(0)} km/h', 'Wind'),
              _quickStat(Icons.wb_sunny_outlined, 'UV ${d.uvIndex}', 'UV Index'),
              _quickStat(Icons.grain_rounded, '${d.precipMm.toStringAsFixed(1)}mm', 'Precip'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _quickStat(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, color: Colors.white54, size: 18),
        const SizedBox(height: 4),
        Text(value,
            style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: Colors.white)),
        Text(label,
            style: GoogleFonts.inter(fontSize: 9, color: Colors.white38)),
      ],
    );
  }

  Widget _buildForecastRow(WeatherData d) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF131D2E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF1E3A5F)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '5-DAY FORECAST',
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF3B82F6),
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 14),
          d.forecast.isEmpty
              ? Text('No forecast data',
                  style: GoogleFonts.inter(color: Colors.white38))
              : Row(
                  children: d.forecast
                      .map((f) => Expanded(child: _forecastItem(f)))
                      .toList(),
                ),
        ],
      ),
    );
  }

  Widget _forecastItem(DayForecast f) {
    final hasRain = f.precipMm > 0.5 || f.precipProb > 30;
    return Column(
      children: [
        Text(
          f.dayName,
          style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: Colors.white54),
        ),
        const SizedBox(height: 6),
        Icon(
          _conditionIcon(f.condition),
          color: _conditionColor(f.condition),
          size: 22,
        ),
        const SizedBox(height: 6),
        Text(
          '${f.maxTempC.toStringAsFixed(0)}°',
          style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: Colors.white),
        ),
        Text(
          '${f.minTempC.toStringAsFixed(0)}°',
          style: GoogleFonts.inter(fontSize: 11, color: Colors.white38),
        ),
        if (hasRain) ...[
          const SizedBox(height: 4),
          Text(
            '${f.precipMm.toStringAsFixed(1)}mm',
            style: GoogleFonts.inter(
                fontSize: 9,
                color: const Color(0xFF3B82F6),
                fontWeight: FontWeight.w700),
          ),
        ],
      ],
    );
  }

  Widget _buildMetricsGrid(WeatherData d) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.6,
        children: [
          _metricCard(Icons.opacity_rounded, 'Dew Point',
              '${d.dewPoint.toStringAsFixed(1)}°C', const Color(0xFF06B6D4)),
          _metricCard(Icons.visibility_rounded, 'Visibility',
              '${d.visibility.toStringAsFixed(0)} km', const Color(0xFF8B5CF6)),
          _metricCard(
              Icons.thermostat_rounded,
              'Avg Temp (3d)',
              '${d.avgTemp3d.toStringAsFixed(1)}°C',
              const Color(0xFFF59E0B)),
          _metricCard(Icons.water_rounded, 'Rain (7d)',
              '${d.totalRain7d.toStringAsFixed(1)} mm', const Color(0xFF3B82F6)),
        ],
      ),
    );
  }

  Widget _metricCard(
      IconData icon, String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF131D2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(label,
                    style: GoogleFonts.inter(
                        fontSize: 9,
                        color: Colors.white38,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5)),
                const SizedBox(height: 3),
                Text(value,
                    style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: Colors.white)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRiskSection(WeatherData d) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF131D2E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF1E3A5F)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'RISK ASSESSMENT',
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF3B82F6),
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 14),
          _riskBar('Heat Risk', d.heatRisk,
              'Avg: ${d.avgTemp3d.toStringAsFixed(1)}°C',
              Icons.thermostat_rounded),
          const SizedBox(height: 10),
          _riskBar('Drought Risk', d.droughtRisk,
              'Total rain: ${d.totalRain7d.toStringAsFixed(1)}mm (7d)',
              Icons.water_drop_outlined),
          const SizedBox(height: 10),
          _riskBar(
              'Flood Risk',
              d.floodRisk,
              'Max daily: ${d.maxDailyRain.toStringAsFixed(1)}mm',
              Icons.flood_rounded),
          const SizedBox(height: 16),
          // Overall score gauge
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Overall Farm Risk Score',
                        style: GoogleFonts.inter(
                            fontSize: 11,
                            color: Colors.white54,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: d.riskScore / 100,
                        minHeight: 10,
                        backgroundColor: Colors.white12,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          d.riskScore < 30
                              ? const Color(0xFF22C55E)
                              : d.riskScore < 60
                                  ? const Color(0xFFF59E0B)
                                  : const Color(0xFFEF4444),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Text(
                '${d.riskScore}',
                style: GoogleFonts.inter(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  color: d.riskScore < 30
                      ? const Color(0xFF22C55E)
                      : d.riskScore < 60
                          ? const Color(0xFFF59E0B)
                          : const Color(0xFFEF4444),
                ),
              ),
              Text(
                '/100',
                style: GoogleFonts.inter(
                    fontSize: 14, color: Colors.white38),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _riskBar(
      String label, String risk, String detail, IconData icon) {
    final color = _riskColor(risk);
    double barValue = risk == 'Low'
        ? 0.2
        : risk == 'Moderate'
            ? 0.55
            : 0.9;
    return Row(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(label,
                      style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.white)),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(risk,
                        style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: color)),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: barValue,
                  minHeight: 6,
                  backgroundColor: Colors.white10,
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
              ),
              const SizedBox(height: 3),
              Text(detail,
                  style: GoogleFonts.inter(
                      fontSize: 10, color: Colors.white38)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFarmingAdvisory(WeatherData d) {
    final List<String> tips = [];
    if (d.heatRisk == 'High')
      tips.add('Water crops in early morning or late evening to reduce heat stress.');
    if (d.heatRisk == 'Moderate')
      tips.add('Apply light mulching to conserve soil moisture in warm conditions.');
    if (d.droughtRisk == 'High')
      tips.add('Activate drip irrigation immediately. Prioritize drought-resistant varieties.');
    if (d.droughtRisk == 'Moderate')
      tips.add('Monitor soil moisture closely. Reduce irrigation frequency if rain expected.');
    if (d.floodRisk == 'High')
      tips.add('Move livestock and equipment to elevated areas. Open all drainage channels.');
    if (d.floodRisk == 'Moderate')
      tips.add('Check drainage systems. Avoid planting in flood-prone areas this week.');
    if (tips.isEmpty)
      tips.add('Conditions are favorable for farming. Maintain regular crop care routines.');

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1F0D),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: const Color(0xFF22C55E).withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.eco_rounded,
                  color: Color(0xFF22C55E), size: 20),
              const SizedBox(width: 8),
              Text(
                'Farming Advisory',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF22C55E),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...tips.map((tip) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.check_circle_rounded,
                        color: Color(0xFF22C55E), size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        tip,
                        style: GoogleFonts.inter(
                            fontSize: 13,
                            color: Colors.white70,
                            height: 1.5),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildActionButtons(WeatherData d) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Column(
        children: [
          // Ask AI About Weather
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ChatScreen(
                    location: _location,
                    temp: d.tempC,
                    initialMessage:
                        'Current weather: ${d.condition}, ${d.tempC.toStringAsFixed(0)}°C, humidity ${d.humidity}%, wind ${d.windKph.toStringAsFixed(0)} km/h. What farming advice do you have?',
                  ),
                ),
              ),
              icon: const Icon(Icons.chat_bubble_rounded,
                  color: Colors.black, size: 18),
              label: Text(
                'Ask AI About This Weather',
                style: GoogleFonts.inter(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: Colors.black),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3B82F6),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
            ),
          ),
          const SizedBox(height: 10),
          // Emergency if high risk
          if (d.riskScore >= 50)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const EmergencyScreen())),
                icon: const Icon(Icons.warning_amber_rounded,
                    color: Color(0xFFEAB308), size: 18),
                label: Text(
                  'Report Weather Emergency',
                  style: GoogleFonts.inter(
                      fontWeight: FontWeight.w800, fontSize: 14),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFEAB308),
                  side: const BorderSide(
                      color: Color(0xFFEAB308), width: 1.5),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
