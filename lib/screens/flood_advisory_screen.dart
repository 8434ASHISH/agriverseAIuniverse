import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/flood_service.dart';
import '../services/location_service.dart';
import 'chat_screen.dart';
import 'emergency_screen.dart';

class FloodAdvisoryScreen extends StatefulWidget {
  const FloodAdvisoryScreen({super.key});

  @override
  State<FloodAdvisoryScreen> createState() => _FloodAdvisoryScreenState();
}

class _FloodAdvisoryScreenState extends State<FloodAdvisoryScreen>
    with SingleTickerProviderStateMixin {
  bool _loading = true;
  FloodDroughtData? _data;
  String _location = 'Detecting...';
  late AnimationController _waveCtrl;
  late Animation<double> _waveAnim;

  @override
  void initState() {
    super.initState();
    _waveCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _waveAnim = Tween<double>(begin: 0.0, end: 1.0).animate(_waveCtrl);
    _load();
  }

  @override
  void dispose() {
    _waveCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final locData = await LocationService.getLocationData();
      if (mounted) setState(() => _location = locData['location'] ?? 'Your Location');
      final data = await FloodService.fetchFloodDroughtData();
      if (mounted) {
        setState(() {
          _data = data;
          _location = data.locationName.isNotEmpty ? data.locationName : _location;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Color _floodColor(String level) {
    switch (level.toLowerCase()) {
      case 'extreme':
        return const Color(0xFF7C3AED);
      case 'high':
        return const Color(0xFFEF4444);
      case 'moderate':
        return const Color(0xFFF59E0B);
      default:
        return const Color(0xFF22C55E);
    }
  }

  double _floodMeterValue(String level) {
    switch (level.toLowerCase()) {
      case 'extreme':
        return 0.95;
      case 'high':
        return 0.75;
      case 'moderate':
        return 0.50;
      default:
        return 0.18;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF080F1C),
      appBar: AppBar(
        backgroundColor: const Color(0xFF080F1C),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Flood Advisory',
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
          : _buildContent(),
    );
  }

  Widget _buildLoading() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedBuilder(
            animation: _waveAnim,
            builder: (_, __) => Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFF3B82F6)
                    .withValues(alpha: 0.1 + _waveAnim.value * 0.1),
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFF3B82F6)
                      .withValues(alpha: 0.3 + _waveAnim.value * 0.2),
                  width: 2,
                ),
              ),
              child: const Icon(Icons.water_rounded,
                  color: Color(0xFF3B82F6), size: 44),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Analyzing Flood Conditions',
            style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Colors.white70),
          ),
          const SizedBox(height: 6),
          Text(
            'AccuWeather • Open-Meteo • Gemini AI',
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

  Widget _buildContent() {
    final d = _data!;
    final floodColor = _floodColor(d.floodLevel);

    return SingleChildScrollView(
      child: Column(
        children: [
          // ── Hero flood level card ────────────────────────────────────
          _buildFloodHeroCard(d, floodColor),

          // ── Live metrics ─────────────────────────────────────────────
          _buildFloodMetrics(d, floodColor),

          // ── Water level gauge ────────────────────────────────────────
          _buildWaterGauge(d, floodColor),

          // ── AI Advisory ──────────────────────────────────────────────
          _buildAIAdvisory(d, floodColor),

          // ── Immediate Actions ────────────────────────────────────────
          _buildActionsList(d.floodActions, floodColor, 'Immediate Actions'),

          // ── Ask AI + Emergency ───────────────────────────────────────
          _buildButtons(d),

          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildFloodHeroCard(FloodDroughtData d, Color color) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withValues(alpha: 0.25),
            const Color(0xFF0F1A2E),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 2),
      ),
      child: Column(
        children: [
          // Location
          Row(
            children: [
              const Icon(Icons.location_on_rounded,
                  color: Colors.white54, size: 14),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  _location,
                  style: GoogleFonts.inter(
                      fontSize: 12, color: Colors.white54),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (d.floodLevel == 'High' || d.floodLevel == 'Extreme')
                AnimatedBuilder(
                  animation: _waveAnim,
                  builder: (_, __) => Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: color.withValues(
                          alpha: 0.15 + _waveAnim.value * 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color:
                              color.withValues(alpha: 0.5)),
                    ),
                    child: Text(
                      '⚠ ALERT',
                      style: GoogleFonts.inter(
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          color: color,
                          letterSpacing: 1),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),

          // Flood icon + level
          AnimatedBuilder(
            animation: _waveAnim,
            builder: (_, __) => Transform.translate(
              offset: Offset(0, -3 * _waveAnim.value),
              child: Icon(Icons.water_rounded, color: color, size: 64),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '${d.floodLevel} Flood Risk',
            style: GoogleFonts.inter(
              fontSize: 32,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'River Discharge: ${d.riverDischarge.toStringAsFixed(1)} m³/s',
            style: GoogleFonts.inter(fontSize: 13, color: Colors.white54),
          ),
          const SizedBox(height: 4),
          Text(
            'Expected Precip (24h): ${d.precipNext24h.toStringAsFixed(1)} mm',
            style: GoogleFonts.inter(fontSize: 12, color: Colors.white38),
          ),
        ],
      ),
    );
  }

  Widget _buildFloodMetrics(FloodDroughtData d, Color color) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
          Expanded(
            child: _metricTile(
              Icons.thermostat_rounded,
              '${d.tempC.toStringAsFixed(0)}°C',
              'Temperature',
              const Color(0xFFF59E0B),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _metricTile(
              Icons.water_drop_rounded,
              '${d.humidity}%',
              'Humidity',
              const Color(0xFF3B82F6),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _metricTile(
              Icons.grain_rounded,
              '${d.rain7d.toStringAsFixed(1)}mm',
              'Rain 7d',
              color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _metricTile(
      IconData icon, String value, String label, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1A2E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 6),
          Text(value,
              style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: Colors.white)),
          Text(label,
              style: GoogleFonts.inter(fontSize: 9, color: Colors.white38),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildWaterGauge(FloodDroughtData d, Color color) {
    final gaugeValue = _floodMeterValue(d.floodLevel);
    final dischargeMax = 150.0;
    final dischargeRatio = (d.riverDischarge / dischargeMax).clamp(0.0, 1.0);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1A2E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'WATER LEVEL INDICATORS',
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF3B82F6),
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 16),

          // River discharge bar
          Text('River Discharge',
              style: GoogleFonts.inter(
                  fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white70)),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: dischargeRatio,
                    minHeight: 14,
                    backgroundColor: Colors.white10,
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text('${d.riverDischarge.toStringAsFixed(1)} m³/s',
                  style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: color)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('0 (Safe)', style: GoogleFonts.inter(fontSize: 9, color: const Color(0xFF22C55E))),
              Text('50 (Watch)', style: GoogleFonts.inter(fontSize: 9, color: const Color(0xFFF59E0B))),
              Text('80+ (Danger)', style: GoogleFonts.inter(fontSize: 9, color: const Color(0xFFEF4444))),
            ],
          ),
          const SizedBox(height: 14),

          // Flood risk gauge
          Text('Flood Risk Level',
              style: GoogleFonts.inter(
                  fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white70)),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: gaugeValue,
                    minHeight: 14,
                    backgroundColor: Colors.white10,
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(d.floodLevel,
                  style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: color)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Low', style: GoogleFonts.inter(fontSize: 9, color: const Color(0xFF22C55E))),
              Text('Moderate', style: GoogleFonts.inter(fontSize: 9, color: const Color(0xFFF59E0B))),
              Text('Extreme', style: GoogleFonts.inter(fontSize: 9, color: const Color(0xFF7C3AED))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAIAdvisory(FloodDroughtData d, Color color) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.psychology_rounded, color: color, size: 18),
              ),
              const SizedBox(width: 8),
              Text(
                'Gemini AI Flood Advisory',
                style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            d.floodAdvisory,
            style: GoogleFonts.inter(
                fontSize: 13, color: Colors.white70, height: 1.6),
          ),
        ],
      ),
    );
  }

  Widget _buildActionsList(
      List<String> actions, Color color, String title) {
    if (actions.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1A2E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: color,
                letterSpacing: 1.5),
          ),
          const SizedBox(height: 12),
          ...actions.asMap().entries.map((entry) {
            final i = entry.key;
            final action = entry.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '${i + 1}',
                        style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            color: color),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      action,
                      style: GoogleFonts.inter(
                          fontSize: 13, color: Colors.white70, height: 1.5),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildButtons(FloodDroughtData d) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Column(
        children: [
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
                        'Flood risk is ${d.floodLevel}. River discharge: ${d.riverDischarge.toStringAsFixed(1)} m³/s. Expected rain next 24h: ${d.precipNext24h.toStringAsFixed(1)} mm. What specific steps should I take to protect my farm?',
                  ),
                ),
              ),
              icon: const Icon(Icons.chat_bubble_rounded, color: Colors.white, size: 18),
              label: Text(
                'Ask AI About Flood Risk',
                style: GoogleFonts.inter(
                    fontWeight: FontWeight.w800, fontSize: 14, color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1D4ED8),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
            ),
          ),
          if (d.floodLevel == 'High' || d.floodLevel == 'Extreme') ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const EmergencyScreen())),
                icon: const Icon(Icons.warning_amber_rounded, color: Colors.black, size: 18),
                label: Text(
                  'REPORT FLOOD EMERGENCY',
                  style: GoogleFonts.inter(
                      fontWeight: FontWeight.w900, fontSize: 14, color: Colors.black),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEF4444),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
