import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../services/gemini_service.dart';
import '../services/location_service.dart';

// ── Data model ────────────────────────────────────────────────────────────────
class CropPlan {
  final String cropName;
  final String soilType;
  final String season;
  final int suitabilityScore; // 0-100
  final String tempRange;
  final String waterNeeds;
  final String harvestDays;
  final List<String> actionableAdvice;
  final String aiSummary;
  final String location;
  final DateTime generatedAt;

  CropPlan({
    required this.cropName,
    required this.soilType,
    required this.season,
    required this.suitabilityScore,
    required this.tempRange,
    required this.waterNeeds,
    required this.harvestDays,
    required this.actionableAdvice,
    required this.aiSummary,
    required this.location,
    required this.generatedAt,
  });

  Map<String, dynamic> toJson() => {
        'cropName': cropName,
        'soilType': soilType,
        'season': season,
        'suitabilityScore': suitabilityScore,
        'tempRange': tempRange,
        'waterNeeds': waterNeeds,
        'harvestDays': harvestDays,
        'actionableAdvice': actionableAdvice,
        'aiSummary': aiSummary,
        'location': location,
        'generatedAt': generatedAt.toIso8601String(),
      };

  factory CropPlan.fromJson(Map<String, dynamic> j) => CropPlan(
        cropName: j['cropName'] ?? '',
        soilType: j['soilType'] ?? '',
        season: j['season'] ?? '',
        suitabilityScore: (j['suitabilityScore'] as num?)?.toInt() ?? 70,
        tempRange: j['tempRange'] ?? '20-30°C',
        waterNeeds: j['waterNeeds'] ?? 'Medium',
        harvestDays: j['harvestDays'] ?? '90 Days',
        actionableAdvice: List<String>.from(j['actionableAdvice'] ?? []),
        aiSummary: j['aiSummary'] ?? '',
        location: j['location'] ?? '',
        generatedAt: DateTime.tryParse(j['generatedAt'] ?? '') ?? DateTime.now(),
      );
}

// ── Screen ────────────────────────────────────────────────────────────────────
class CropSelectionScreen extends StatefulWidget {
  const CropSelectionScreen({super.key});

  @override
  State<CropSelectionScreen> createState() => _CropSelectionScreenState();
}

class _CropSelectionScreenState extends State<CropSelectionScreen>
    with TickerProviderStateMixin {
  final TextEditingController _cropCtrl = TextEditingController();
  final TextEditingController _soilCtrl = TextEditingController();
  String _selectedSeason = 'Select Season';

  bool _isGenerating = false;
  CropPlan? _plan;
  String _location = 'India';
  String? _errorMsg;

  late stt.SpeechToText _speech;
  bool _speechAvailable = false;
  String _activeVoiceField = ''; // 'crop' | 'soil' | ''

  late AnimationController _gaugeCtrl;
  late Animation<double> _gaugeAnim;
  late AnimationController _shimmerCtrl;
  late Animation<double> _shimmerAnim;

  static const String _cacheKey = 'crop_plans_cache';

  final List<String> _seasons = [
    'Select Season', 'Kharif (Jun–Oct)', 'Rabi (Oct–Mar)',
    'Zaid (Mar–Jun)', 'Year Round',
  ];

  final List<Map<String, String>> _soilTypes = [
    {'name': 'Sandy Loam', 'emoji': '🌰'},
    {'name': 'Clay', 'emoji': '🏺'},
    {'name': 'Loam', 'emoji': '🌍'},
    {'name': 'Black Soil', 'emoji': '⚫'},
    {'name': 'Red Laterite', 'emoji': '🟫'},
    {'name': 'Alluvial', 'emoji': '🏞️'},
  ];

  final List<Map<String, String>> _popularCrops = [
    {'name': 'Tomato', 'emoji': '🍅'},
    {'name': 'Wheat', 'emoji': '🌾'},
    {'name': 'Rice', 'emoji': '🍚'},
    {'name': 'Maize', 'emoji': '🌽'},
    {'name': 'Cotton', 'emoji': '🌿'},
    {'name': 'Sugarcane', 'emoji': '🎋'},
    {'name': 'Soybean', 'emoji': '🫘'},
    {'name': 'Potato', 'emoji': '🥔'},
  ];

  @override
  void initState() {
    super.initState();
    _gaugeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1500));
    _gaugeAnim =
        CurvedAnimation(parent: _gaugeCtrl, curve: Curves.easeOutCubic);
    _shimmerCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1000))
      ..repeat(reverse: true);
    _shimmerAnim = Tween<double>(begin: 0.4, end: 1.0).animate(_shimmerCtrl);
    _initSpeech();
    _loadLocation();
  }

  @override
  void dispose() {
    _cropCtrl.dispose();
    _soilCtrl.dispose();
    _gaugeCtrl.dispose();
    _shimmerCtrl.dispose();
    _speech.stop();
    super.dispose();
  }

  Future<void> _initSpeech() async {
    _speech = stt.SpeechToText();
    final ok = await _speech.initialize(
      onStatus: (s) {
        if (s == 'done' || s == 'notListening') {
          if (mounted) setState(() => _activeVoiceField = '');
        }
      },
    );
    if (mounted) setState(() => _speechAvailable = ok);
  }

  Future<void> _loadLocation() async {
    final l = await LocationService.getLocationData();
    if (mounted) setState(() => _location = l['location'] ?? 'India');
  }

  Future<void> _toggleVoice(String field) async {
    if (!_speechAvailable) return;
    if (_activeVoiceField == field) {
      await _speech.stop();
      setState(() => _activeVoiceField = '');
      return;
    }
    setState(() => _activeVoiceField = field);
    await _speech.listen(
      onResult: (r) {
        if (mounted) {
          setState(() {
            final ctrl = field == 'crop' ? _cropCtrl : _soilCtrl;
            ctrl.text = r.recognizedWords;
            ctrl.selection = TextSelection.fromPosition(
                TextPosition(offset: ctrl.text.length));
          });
        }
      },
      listenFor: const Duration(seconds: 10),
      pauseFor: const Duration(seconds: 3),
      partialResults: true,
    );
  }

  // ── Cache ─────────────────────────────────────────────────────────────────
  String _cacheId(String crop, String soil, String season) =>
      '${crop.toLowerCase().trim()}_${soil.toLowerCase().trim()}_${season.toLowerCase()}';

  Future<CropPlan?> _fromCache(String crop, String soil, String season) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKey);
      if (raw == null) return null;
      final Map<String, dynamic> all = jsonDecode(raw);
      final key = _cacheId(crop, soil, season);
      if (!all.containsKey(key)) return null;
      final plan = CropPlan.fromJson(all[key] as Map<String, dynamic>);
      if (DateTime.now().difference(plan.generatedAt).inDays > 7) return null;
      return plan;
    } catch (_) {
      return null;
    }
  }

  Future<void> _saveCache(CropPlan plan) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKey);
      final Map<String, dynamic> all =
          raw != null ? jsonDecode(raw) : {};
      final key = _cacheId(plan.cropName, plan.soilType, plan.season);
      all[key] = plan.toJson();
      if (all.length > 30) all.remove(all.keys.first);
      await prefs.setString(_cacheKey, jsonEncode(all));
    } catch (_) {}
  }

  // ── Generate plan ─────────────────────────────────────────────────────────
  Future<void> _generate() async {
    final crop = _cropCtrl.text.trim();
    final soil = _soilCtrl.text.trim();
    if (crop.isEmpty) {
      _showSnack('Please enter crop name');
      return;
    }
    if (soil.isEmpty) {
      _showSnack('Please enter soil type');
      return;
    }
    if (_selectedSeason == 'Select Season') {
      _showSnack('Please select a season');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _isGenerating = true;
      _plan = null;
      _errorMsg = null;
    });
    _gaugeCtrl.reset();

    final cached = await _fromCache(crop, soil, _selectedSeason);
    if (cached != null) {
      if (mounted) {
        setState(() {
          _plan = cached;
          _isGenerating = false;
        });
        _gaugeCtrl.forward();
        _showSnack('✅ Cached plan loaded (saving API calls)');
        return;
      }
    }

    try {
      final raw = await GeminiService.getCropGrowthPlan(
        crop: crop,
        soilType: soil,
        season: _selectedSeason,
        location: _location,
      );
      final plan = CropPlan(
        cropName: crop,
        soilType: soil,
        season: _selectedSeason,
        suitabilityScore:
            (raw['suitabilityScore'] as num?)?.toInt() ?? 75,
        tempRange: raw['tempRange'] as String? ?? '20-30°C',
        waterNeeds: raw['waterNeeds'] as String? ?? 'Medium',
        harvestDays: raw['harvestDays'] as String? ?? '90 Days',
        actionableAdvice:
            List<String>.from(raw['actionableAdvice'] ?? []),
        aiSummary: raw['aiSummary'] as String? ?? '',
        location: _location,
        generatedAt: DateTime.now(),
      );
      if (mounted) {
        await _saveCache(plan);
        setState(() {
          _plan = plan;
          _isGenerating = false;
        });
        _gaugeCtrl.forward();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMsg = 'Failed to generate plan. Please retry.';
          _isGenerating = false;
        });
      }
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.inter(fontSize: 13)),
      backgroundColor: const Color(0xFF16A34A),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  Color _gaugeColor(int score) {
    if (score >= 80) return const Color(0xFF22C55E);
    if (score >= 55) return const Color(0xFFF59E0B);
    return const Color(0xFFEF4444);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAF8),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded,
              color: Color(0xFF1A1A1A)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Smart Crop Selection',
                style: GoogleFonts.inter(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF1A1A1A))),
            Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: Color(0xFF22C55E),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 4),
                Text('Powered by Vision AI Engine',
                    style: GoogleFonts.inter(
                        fontSize: 10, color: const Color(0xFF22C55E))),
              ],
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildInputCard(),
            if (_isGenerating) _buildLoadingCard(),
            if (_errorMsg != null) _buildErrorCard(),
            if (_plan != null) _buildAnalysisCard(_plan!),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildInputCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 16,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Crop Name
          Text('Crop Name',
              style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF6B7280))),
          const SizedBox(height: 6),
          _voiceTextField(
            controller: _cropCtrl,
            hint: 'e.g., Tomato',
            field: 'crop',
          ),
          const SizedBox(height: 10),
          // Quick crop chips
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _popularCrops.map((c) {
              final sel = _cropCtrl.text.toLowerCase() ==
                  c['name']!.toLowerCase();
              return GestureDetector(
                onTap: () => setState(() => _cropCtrl.text = c['name']!),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: sel
                        ? const Color(0xFF22C55E)
                        : const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: sel
                            ? const Color(0xFF22C55E)
                            : const Color(0xFFE5E7EB)),
                  ),
                  child: Text('${c['emoji']} ${c['name']}',
                      style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: sel
                              ? Colors.white
                              : const Color(0xFF374151))),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 16),

          // Soil Type
          Text('Soil Type',
              style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF6B7280))),
          const SizedBox(height: 6),
          _voiceTextField(
            controller: _soilCtrl,
            hint: 'e.g., Sandy Loam',
            field: 'soil',
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _soilTypes.map((s) {
              final sel = _soilCtrl.text.toLowerCase() ==
                  s['name']!.toLowerCase();
              return GestureDetector(
                onTap: () => setState(() => _soilCtrl.text = s['name']!),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: sel
                        ? const Color(0xFF16A34A)
                        : const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('${s['emoji']} ${s['name']}',
                      style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: sel
                              ? Colors.white
                              : const Color(0xFF374151))),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 16),

          // Season dropdown
          Text('Current Season',
              style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF6B7280))),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: DropdownButton<String>(
              value: _selectedSeason,
              isExpanded: true,
              underline: const SizedBox(),
              dropdownColor: Colors.white,
              style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1A1A1A)),
              icon: const Icon(Icons.expand_more_rounded,
                  color: Color(0xFF6B7280)),
              items: _seasons
                  .map((s) => DropdownMenuItem(
                        value: s,
                        child: Text(
                          s,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF1A1A1A),
                          ),
                        ),
                      ))
                  .toList(),
              onChanged: (v) =>
                  setState(() => _selectedSeason = v ?? _selectedSeason),
            ),
          ),

          const SizedBox(height: 20),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isGenerating ? null : _generate,
              icon: const Icon(Icons.auto_awesome_rounded,
                  color: Colors.white, size: 18),
              label: Text('Generate Vision AI Growth Plan',
                  style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF22C55E),
                disabledBackgroundColor: const Color(0xFFD1FAE5),
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _voiceTextField({
    required TextEditingController controller,
    required String hint,
    required String field,
  }) {
    final listening = _activeVoiceField == field;
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: listening
                ? const Color(0xFF22C55E)
                : const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1A1A1A)),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: GoogleFonts.inter(
                    fontSize: 13, color: const Color(0xFF9CA3AF)),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 13),
              ),
              textCapitalization: TextCapitalization.words,
            ),
          ),
          GestureDetector(
            onTap: () => _toggleVoice(field),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 8),
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: listening
                    ? const Color(0xFFEF4444)
                    : const Color(0xFF22C55E).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                listening
                    ? Icons.mic_rounded
                    : Icons.mic_none_rounded,
                color: listening
                    ? Colors.white
                    : const Color(0xFF22C55E),
                size: 17,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingCard() {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 16,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        children: [
          AnimatedBuilder(
            animation: _shimmerAnim,
            builder: (_, __) => Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                color: const Color(0xFF22C55E)
                    .withValues(alpha: _shimmerAnim.value * 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.grass_rounded,
                  color: Color(0xFF22C55E), size: 36),
            ),
          ),
          const SizedBox(height: 14),
          Text('Vision AI Engine Analyzing...',
              style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF1A1A1A))),
          const SizedBox(height: 5),
          Text('Calculating suitability, yield & action plan',
              style: GoogleFonts.inter(
                  fontSize: 11, color: const Color(0xFF6B7280))),
          const SizedBox(height: 16),
          const LinearProgressIndicator(
            color: Color(0xFF22C55E),
            backgroundColor: Color(0xFFD1FAE5),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorCard() {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFCA5A5)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded,
              color: Color(0xFFEF4444), size: 22),
          const SizedBox(width: 10),
          Expanded(
              child: Text(_errorMsg!,
                  style: GoogleFonts.inter(
                      fontSize: 13, color: const Color(0xFFDC2626)))),
          TextButton(
            onPressed: _generate,
            child: Text('Retry',
                style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFFDC2626))),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalysisCard(CropPlan plan) {
    final score = plan.suitabilityScore;
    final color = _gaugeColor(score);

    return Container(
      margin: const EdgeInsets.only(top: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: const Color(0xFF22C55E).withValues(alpha: 0.3),
            width: 2),
        boxShadow: [
          BoxShadow(
              color: const Color(0xFF22C55E).withValues(alpha: 0.08),
              blurRadius: 20,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: const BoxDecoration(
              border: Border(
                  bottom: BorderSide(color: Color(0xFFF3F4F6))),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF22C55E).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: const Color(0xFF22C55E)
                            .withValues(alpha: 0.3)),
                  ),
                  child: Text('VISION AI ENGINE',
                      style: GoogleFonts.inter(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF22C55E),
                          letterSpacing: 1)),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.verified_rounded, color: color, size: 12),
                      const SizedBox(width: 4),
                      Text('VERIFIED',
                          style: GoogleFonts.inter(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: color,
                              letterSpacing: 1)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Text(
                  'Growth Analysis',
                  style: GoogleFonts.inter(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF1A1A1A)),
                ),
                const SizedBox(height: 24),

                // Circular score gauge
                AnimatedBuilder(
                  animation: _gaugeAnim,
                  builder: (_, __) {
                    final animatedScore =
                        (score * _gaugeAnim.value).round();
                    return SizedBox(
                      width: 160,
                      height: 160,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          CustomPaint(
                            size: const Size(160, 160),
                            painter: _GaugePainter(
                              progress: _gaugeAnim.value * score / 100,
                              color: color,
                            ),
                          ),
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '$animatedScore%',
                                style: GoogleFonts.inter(
                                  fontSize: 36,
                                  fontWeight: FontWeight.w900,
                                  color: const Color(0xFF1A1A1A),
                                ),
                              ),
                              Text(
                                'SCORE',
                                style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF9CA3AF),
                                    letterSpacing: 1.5),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),

                const SizedBox(height: 6),
                Text('Suitability Rating',
                    style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF6B7280))),

                const SizedBox(height: 20),

                // Metrics
                _metricRow(
                  Icons.thermostat_rounded,
                  const Color(0xFFEF4444),
                  'TEMPERATURE',
                  plan.tempRange,
                  'IDEAL',
                ),
                const SizedBox(height: 10),
                _metricRow(
                  Icons.water_drop_rounded,
                  const Color(0xFF3B82F6),
                  'WATER',
                  plan.waterNeeds,
                  'PRIORITY',
                ),
                const SizedBox(height: 10),
                _metricRow(
                  Icons.calendar_today_rounded,
                  const Color(0xFF22C55E),
                  'HARVEST',
                  plan.harvestDays,
                  'CYCLE',
                ),

                if (plan.aiSummary.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FFF4),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: const Color(0xFFBBF7D0)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.psychology_rounded,
                            color: Color(0xFF16A34A), size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            plan.aiSummary,
                            style: GoogleFonts.inter(
                                fontSize: 12,
                                color: const Color(0xFF166534),
                                height: 1.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 20),

                // Actionable Advice
                Row(
                  children: [
                    const Icon(Icons.tips_and_updates_rounded,
                        color: Color(0xFF22C55E), size: 18),
                    const SizedBox(width: 6),
                    Text('Actionable Advice',
                        style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF1A1A1A))),
                  ],
                ),
                const SizedBox(height: 12),
                ...plan.actionableAdvice.map((a) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.check_circle_rounded,
                              color: Color(0xFF22C55E), size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(a,
                                style: GoogleFonts.inter(
                                    fontSize: 13,
                                    color: const Color(0xFF374151),
                                    height: 1.5)),
                          ),
                        ],
                      ),
                    )),

                const SizedBox(height: 16),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.picture_as_pdf_rounded,
                        size: 18, color: Colors.white),
                    label: Text('Download Full AI Report (PDF)',
                        style: GoogleFonts.inter(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                            color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1A1A1A),
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _metricRow(IconData icon, Color iconColor, String label,
      String value, String tag) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: GoogleFonts.inter(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF9CA3AF),
                        letterSpacing: 1)),
                Text(value,
                    style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF1A1A1A))),
              ],
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFE5E7EB),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(tag,
                style: GoogleFonts.inter(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF6B7280),
                    letterSpacing: 0.5)),
          ),
        ],
      ),
    );
  }
}

// ── Circular gauge painter ────────────────────────────────────────────────────
class _GaugePainter extends CustomPainter {
  final double progress;
  final Color color;
  _GaugePainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - 14;
    const strokeW = 14.0;

    // Background arc
    final bgPaint = Paint()
      ..color = const Color(0xFFE5E7EB)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeW
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi * 0.75,
      pi * 1.5,
      false,
      bgPaint,
    );

    // Foreground arc
    final fgPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeW
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi * 0.75,
      pi * 1.5 * progress,
      false,
      fgPaint,
    );
  }

  @override
  bool shouldRepaint(_GaugePainter old) =>
      old.progress != progress || old.color != color;
}
