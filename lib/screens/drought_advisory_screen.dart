import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/flood_service.dart';
import '../services/location_service.dart';
import 'chat_screen.dart';
import 'emergency_screen.dart';

class DroughtAdvisoryScreen extends StatefulWidget {
  const DroughtAdvisoryScreen({super.key});

  @override
  State<DroughtAdvisoryScreen> createState() => _DroughtAdvisoryScreenState();
}

class _DroughtAdvisoryScreenState extends State<DroughtAdvisoryScreen>
    with SingleTickerProviderStateMixin {
  bool _loading = true;
  FloodDroughtData? _data;
  String _location = 'Detecting...';
  late AnimationController _crackCtrl;
  late Animation<double> _crackAnim;

  @override
  void initState() {
    super.initState();
    _crackCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
    _crackAnim = Tween<double>(begin: 0.0, end: 1.0).animate(_crackCtrl);
    _load();
  }

  @override
  void dispose() {
    _crackCtrl.dispose();
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

  Color _droughtColor(String level) {
    switch (level.toLowerCase()) {
      case 'emergency':
        return const Color(0xFFEF4444);
      case 'warning':
        return const Color(0xFFF59E0B);
      case 'watch':
        return const Color(0xFFFBBF24);
      default:
        return const Color(0xFF22C55E);
    }
  }

  double _droughtMeterValue(String level) {
    switch (level.toLowerCase()) {
      case 'emergency':
        return 0.95;
      case 'warning':
        return 0.70;
      case 'watch':
        return 0.45;
      default:
        return 0.15;
    }
  }

  String _droughtDescription(String level) {
    switch (level.toLowerCase()) {
      case 'emergency':
        return 'Critical water shortage. Immediate action required to save crops.';
      case 'warning':
        return 'Significant drought stress. Water conservation is essential.';
      case 'watch':
        return 'Dry conditions developing. Monitor and prepare for drought.';
      default:
        return 'Adequate soil moisture. Current conditions are good for farming.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A0E00),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A0E00),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Drought Advisory',
          style: GoogleFonts.inter(
              fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFFF59E0B)),
            onPressed: _load,
          ),
        ],
      ),
      body: _loading ? _buildLoading() : _buildContent(),
    );
  }

  Widget _buildLoading() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedBuilder(
            animation: _crackAnim,
            builder: (_, __) => Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B)
                    .withValues(alpha: 0.1 + _crackAnim.value * 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.wb_sunny_rounded,
                  color: Color(0xFFF59E0B), size: 44),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Analyzing Drought Conditions',
            style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Colors.white70),
          ),
          const SizedBox(height: 6),
          Text(
            'Open-Meteo • Soil Data • Gemini AI',
            style: GoogleFonts.inter(fontSize: 11, color: Colors.white38),
          ),
          const SizedBox(height: 24),
          const SizedBox(
            width: 160,
            child: LinearProgressIndicator(
              color: Color(0xFFF59E0B),
              backgroundColor: Color(0xFF2D1A00),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    final d = _data!;
    final color = _droughtColor(d.droughtLevel);

    return SingleChildScrollView(
      child: Column(
        children: [
          // ── Hero drought level card ──────────────────────────────────
          _buildDroughtHero(d, color),

          // ── Quick stats ──────────────────────────────────────────────
          _buildDroughtMetrics(d, color),

          // ── Drought Index Gauge ──────────────────────────────────────
          _buildDroughtGauge(d, color),

          // ── Soil & Rainfall Analysis ─────────────────────────────────
          _buildRainfallAnalysis(d, color),

          // ── AI Advisory ──────────────────────────────────────────────
          _buildAIAdvisory(d, color),

          // ── Recommended Actions ──────────────────────────────────────
          _buildActionsList(d.droughtActions, color),

          // ── Buttons ──────────────────────────────────────────────────
          _buildButtons(d, color),

          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildDroughtHero(FloodDroughtData d, Color color) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withValues(alpha: 0.22),
            const Color(0xFF2D1A00),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 2),
      ),
      child: Column(
        children: [
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
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: color.withValues(alpha: 0.4)),
                ),
                child: Text(
                  'DROUGHT MONITOR',
                  style: GoogleFonts.inter(
                      fontSize: 8,
                      fontWeight: FontWeight.w800,
                      color: color,
                      letterSpacing: 1),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          AnimatedBuilder(
            animation: _crackAnim,
            builder: (_, __) => Transform.scale(
              scale: 0.95 + _crackAnim.value * 0.05,
              child: Icon(Icons.wb_sunny_rounded, color: color, size: 64),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '${d.droughtLevel} Drought',
            style: GoogleFonts.inter(
              fontSize: 32,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black26,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _droughtDescription(d.droughtLevel),
              style: GoogleFonts.inter(
                  fontSize: 12, color: Colors.white70, height: 1.5),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDroughtMetrics(FloodDroughtData d, Color color) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
          Expanded(
              child: _statCard(
                  Icons.thermostat_rounded,
                  '${d.tempC.toStringAsFixed(0)}°C',
                  'Temperature',
                  const Color(0xFFEF4444))),
          const SizedBox(width: 10),
          Expanded(
              child: _statCard(Icons.water_drop_rounded, '${d.humidity}%',
                  'Humidity', const Color(0xFF3B82F6))),
          const SizedBox(width: 10),
          Expanded(
              child: _statCard(Icons.grain_rounded,
                  '${d.soilMoisture.toStringAsFixed(0)}%', 'Soil Moist.', color)),
        ],
      ),
    );
  }

  Widget _statCard(
      IconData icon, String value, String label, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF2D1A00),
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

  Widget _buildDroughtGauge(FloodDroughtData d, Color color) {
    final gaugeValue = _droughtMeterValue(d.droughtLevel);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF2D1A00),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'DROUGHT INDEX',
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: const Color(0xFFF59E0B),
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 16),

          // Index score visual
          Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: gaugeValue,
                        minHeight: 18,
                        backgroundColor: Colors.white10,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(color),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Normal',
                            style: GoogleFonts.inter(
                                fontSize: 9,
                                color: const Color(0xFF22C55E))),
                        Text('Watch',
                            style: GoogleFonts.inter(
                                fontSize: 9,
                                color: const Color(0xFFFBBF24))),
                        Text('Warning',
                            style: GoogleFonts.inter(
                                fontSize: 9,
                                color: const Color(0xFFF59E0B))),
                        Text('Emergency',
                            style: GoogleFonts.inter(
                                fontSize: 9,
                                color: const Color(0xFFEF4444))),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Column(
                children: [
                  Text(
                    '${d.droughtIndex}',
                    style: GoogleFonts.inter(
                      fontSize: 40,
                      fontWeight: FontWeight.w900,
                      color: color,
                    ),
                  ),
                  Text('/100',
                      style:
                          GoogleFonts.inter(fontSize: 12, color: Colors.white38)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRainfallAnalysis(FloodDroughtData d, Color color) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF2D1A00),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'RAINFALL & SOIL ANALYSIS',
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: const Color(0xFFF59E0B),
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 14),
          _rainRow('Rain Last 7 Days', d.rain7d, 30.0, const Color(0xFF3B82F6)),
          const SizedBox(height: 10),
          _rainRow('Rain Last 14 Days', d.rain14d, 60.0, const Color(0xFF60A5FA)),
          const SizedBox(height: 10),
          _rainRow(
              'Soil Moisture', d.soilMoisture, 100.0, const Color(0xFF22C55E),
              unit: '%', maxGood: 40.0),
        ],
      ),
    );
  }

  Widget _rainRow(String label, double value, double max, Color color,
      {String unit = 'mm', double? maxGood}) {
    final ratio = (value / max).clamp(0.0, 1.0);
    final isLow = value < (maxGood ?? max * 0.3);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white70)),
            Text(
              '${value.toStringAsFixed(1)} $unit ${isLow ? '⬇' : ''}',
              style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: isLow ? const Color(0xFFEF4444) : color),
            ),
          ],
        ),
        const SizedBox(height: 5),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: 8,
            backgroundColor: Colors.white10,
            valueColor: AlwaysStoppedAnimation<Color>(
                isLow ? const Color(0xFFEF4444) : color),
          ),
        ),
      ],
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
                child:
                    Icon(Icons.psychology_rounded, color: color, size: 18),
              ),
              const SizedBox(width: 8),
              Text(
                'Gemini AI Drought Advisory',
                style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            d.droughtAdvisory,
            style: GoogleFonts.inter(
                fontSize: 13, color: Colors.white70, height: 1.6),
          ),
        ],
      ),
    );
  }

  Widget _buildActionsList(List<String> actions, Color color) {
    if (actions.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF2D1A00),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'RECOMMENDED ACTIONS',
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
                          fontSize: 13,
                          color: Colors.white70,
                          height: 1.5),
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

  Widget _buildButtons(FloodDroughtData d, Color color) {
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
                        'Drought level is ${d.droughtLevel} (index: ${d.droughtIndex}/100). Rain last 7 days: ${d.rain7d.toStringAsFixed(1)}mm, last 14 days: ${d.rain14d.toStringAsFixed(1)}mm. Soil moisture: ${d.soilMoisture.toStringAsFixed(0)}%. What specific irrigation and crop protection strategies should I use?',
                  ),
                ),
              ),
              icon: const Icon(Icons.chat_bubble_rounded, size: 18),
              label: Text(
                'Ask AI About Drought',
                style: GoogleFonts.inter(
                    fontWeight: FontWeight.w800, fontSize: 14),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF59E0B),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
            ),
          ),
          if (d.droughtLevel == 'Emergency' || d.droughtLevel == 'Warning') ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const EmergencyScreen())),
                icon: const Icon(Icons.warning_amber_rounded, size: 18),
                label: Text(
                  'Report Drought Emergency',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w800),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFEF4444),
                  side: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
