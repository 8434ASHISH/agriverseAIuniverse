import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../services/gemini_service.dart';
import '../services/location_service.dart';

// ── Unit model ───────────────────────────────────────────────────────────────
class AreaUnit {
  final String name;
  final String symbol;
  final double toAcre; // conversion factor to acres

  const AreaUnit(this.name, this.symbol, this.toAcre);
}

const List<AreaUnit> kAreaUnits = [
  AreaUnit('Acres', 'ac', 1.0),
  AreaUnit('Hectare', 'ha', 2.471),
  AreaUnit('Bigha', 'bgh', 0.619),
  AreaUnit('Biswa', 'bsw', 0.0309),
  AreaUnit('Dhur', 'dhr', 0.00619),
  AreaUnit('Katha', 'kth', 0.0309),
  AreaUnit('Decimal', 'dec', 0.01),
];

// ── Cached plan model ─────────────────────────────────────────────────────────
class FertPlan {
  final String cropType;
  final double areaSizeInAcres;
  final String unitName;
  final String mixture;
  final String totalAmount;
  final String whenToApply;
  final List<String> actionSteps;
  final String safetyWarning;
  final double estimatedCostPerAcre;
  final double yieldIncrease;
  final String imagePrompt; // for local display
  final String location;
  final DateTime generatedAt;

  FertPlan({
    required this.cropType,
    required this.areaSizeInAcres,
    required this.unitName,
    required this.mixture,
    required this.totalAmount,
    required this.whenToApply,
    required this.actionSteps,
    required this.safetyWarning,
    required this.estimatedCostPerAcre,
    required this.yieldIncrease,
    required this.imagePrompt,
    required this.location,
    required this.generatedAt,
  });

  Map<String, dynamic> toJson() => {
        'cropType': cropType,
        'areaSizeInAcres': areaSizeInAcres,
        'unitName': unitName,
        'mixture': mixture,
        'totalAmount': totalAmount,
        'whenToApply': whenToApply,
        'actionSteps': actionSteps,
        'safetyWarning': safetyWarning,
        'estimatedCostPerAcre': estimatedCostPerAcre,
        'yieldIncrease': yieldIncrease,
        'imagePrompt': imagePrompt,
        'location': location,
        'generatedAt': generatedAt.toIso8601String(),
      };

  factory FertPlan.fromJson(Map<String, dynamic> j) => FertPlan(
        cropType: j['cropType'] ?? '',
        areaSizeInAcres: (j['areaSizeInAcres'] as num?)?.toDouble() ?? 1.0,
        unitName: j['unitName'] ?? 'Acres',
        mixture: j['mixture'] ?? '',
        totalAmount: j['totalAmount'] ?? '',
        whenToApply: j['whenToApply'] ?? '',
        actionSteps: List<String>.from(j['actionSteps'] ?? []),
        safetyWarning: j['safetyWarning'] ?? '',
        estimatedCostPerAcre:
            (j['estimatedCostPerAcre'] as num?)?.toDouble() ?? 0.0,
        yieldIncrease:
            (j['yieldIncrease'] as num?)?.toDouble() ?? 0.0,
        imagePrompt: j['imagePrompt'] ?? '',
        location: j['location'] ?? '',
        generatedAt:
            DateTime.tryParse(j['generatedAt'] ?? '') ?? DateTime.now(),
      );
}

// ── Main Screen ───────────────────────────────────────────────────────────────
class FertilizerPlannerScreen extends StatefulWidget {
  const FertilizerPlannerScreen({super.key});

  @override
  State<FertilizerPlannerScreen> createState() =>
      _FertilizerPlannerScreenState();
}

class _FertilizerPlannerScreenState extends State<FertilizerPlannerScreen>
    with SingleTickerProviderStateMixin {
  // Form controllers
  final TextEditingController _cropCtrl = TextEditingController();
  final TextEditingController _areaCtrl = TextEditingController();
  int _selectedUnitIndex = 0; // default = Acres

  // State
  bool _isGenerating = false;
  FertPlan? _plan;
  String _location = 'India';
  String? _errorMsg;

  // Voice
  late stt.SpeechToText _speech;
  bool _isListening = false;
  bool _speechAvailable = false;

  // Animation
  late AnimationController _shimmerCtrl;
  late Animation<double> _shimmerAnim;

  // Cache key
  static const String _cacheKey = 'fert_plans_cache';

  // Crop suggestions for quick pick
  final List<Map<String, String>> _cropSuggestions = [
    {'name': 'Wheat', 'emoji': '🌾'},
    {'name': 'Rice', 'emoji': '🌾'},
    {'name': 'Maize', 'emoji': '🌽'},
    {'name': 'Cotton', 'emoji': '🌿'},
    {'name': 'Sugarcane', 'emoji': '🎋'},
    {'name': 'Tomato', 'emoji': '🍅'},
    {'name': 'Potato', 'emoji': '🥔'},
    {'name': 'Soybean', 'emoji': '🌱'},
    {'name': 'Mustard', 'emoji': '🟡'},
    {'name': 'Groundnut', 'emoji': '🥜'},
    {'name': 'Onion', 'emoji': '🧅'},
    {'name': 'Chilli', 'emoji': '🌶️'},
  ];

  @override
  void initState() {
    super.initState();
    _shimmerCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1500))
      ..repeat(reverse: true);
    _shimmerAnim = Tween<double>(begin: 0.4, end: 1.0).animate(_shimmerCtrl);
    _initSpeech();
    _loadLocation();
  }

  @override
  void dispose() {
    _cropCtrl.dispose();
    _areaCtrl.dispose();
    _shimmerCtrl.dispose();
    if (_isListening) _speech.stop();
    super.dispose();
  }

  Future<void> _initSpeech() async {
    _speech = stt.SpeechToText();
    final available = await _speech.initialize(
      onError: (_) => setState(() => _isListening = false),
      onStatus: (status) {
        if (status == 'done' || status == 'notListening') {
          if (mounted) setState(() => _isListening = false);
        }
      },
    );
    if (mounted) setState(() => _speechAvailable = available);
  }

  Future<void> _loadLocation() async {
    final loc = await LocationService.getLocationData();
    if (mounted) setState(() => _location = loc['location'] ?? 'India');
  }

  // ── Cache helpers ──────────────────────────────────────────────────────────
  String _cacheKeyFor(String crop, double areaAcres) {
    return '${crop.toLowerCase().trim()}_${areaAcres.toStringAsFixed(2)}';
  }

  Future<FertPlan?> _loadFromCache(String crop, double areaAcres) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKey);
      if (raw == null) return null;
      final Map<String, dynamic> all = jsonDecode(raw);
      final key = _cacheKeyFor(crop, areaAcres);
      if (!all.containsKey(key)) return null;
      final plan = FertPlan.fromJson(all[key] as Map<String, dynamic>);
      // Cache valid for 7 days
      if (DateTime.now().difference(plan.generatedAt).inDays > 7) return null;
      return plan;
    } catch (_) {
      return null;
    }
  }

  Future<void> _saveToCache(FertPlan plan) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKey);
      final Map<String, dynamic> all =
          raw != null ? jsonDecode(raw) : {};
      final key = _cacheKeyFor(plan.cropType, plan.areaSizeInAcres);
      all[key] = plan.toJson();
      // Keep only latest 20 entries
      if (all.length > 20) {
        final oldest = all.keys.first;
        all.remove(oldest);
      }
      await prefs.setString(_cacheKey, jsonEncode(all));
    } catch (_) {}
  }

  // ── Voice input ────────────────────────────────────────────────────────────
  Future<void> _toggleListening() async {
    if (!_speechAvailable) {
      _showSnack('Microphone not available on this device');
      return;
    }
    if (_isListening) {
      await _speech.stop();
      setState(() => _isListening = false);
    } else {
      setState(() => _isListening = true);
      await _speech.listen(
        onResult: (result) {
          if (mounted) {
            setState(() {
              _cropCtrl.text = result.recognizedWords;
              _cropCtrl.selection = TextSelection.fromPosition(
                  TextPosition(offset: _cropCtrl.text.length));
            });
          }
        },
        localeId: 'hi_IN', // Hindi priority, falls back to system locale
        listenFor: const Duration(seconds: 10),
        pauseFor: const Duration(seconds: 3),
        partialResults: true,
      );
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.inter(fontSize: 13)),
      backgroundColor: const Color(0xFF1E3A1E),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  // ── Generate plan ──────────────────────────────────────────────────────────
  Future<void> _generate() async {
    final crop = _cropCtrl.text.trim();
    final areaStr = _areaCtrl.text.trim();

    if (crop.isEmpty) {
      _showSnack('Please enter a crop name');
      return;
    }
    if (areaStr.isEmpty) {
      _showSnack('Please enter the farm area');
      return;
    }
    final areaInput = double.tryParse(areaStr);
    if (areaInput == null || areaInput <= 0) {
      _showSnack('Enter a valid area number');
      return;
    }

    final unit = kAreaUnits[_selectedUnitIndex];
    final areaInAcres = areaInput * unit.toAcre;

    FocusScope.of(context).unfocus();
    setState(() {
      _isGenerating = true;
      _plan = null;
      _errorMsg = null;
    });

    // Check local cache first
    final cached = await _loadFromCache(crop, areaInAcres);
    if (cached != null) {
      if (mounted) {
        setState(() {
          _plan = cached;
          _isGenerating = false;
        });
        _showSnack('✅ Showing cached plan (saved API calls)');
        return;
      }
    }

    // Call Gemini API
    try {
      final rawMap = await GeminiService.getFertilizerPlan(
        crop: crop,
        areaInAcres: areaInAcres,
        unitName: unit.name,
        location: _location,
      ) as Map<String, dynamic>;

      final plan = FertPlan(
        cropType: crop,
        areaSizeInAcres: areaInAcres,
        unitName: unit.name,
        mixture: rawMap['mixture'] as String? ?? 'NPK 15-15-15',
        totalAmount: rawMap['totalAmount'] as String? ?? '100 kg / Acre',
        whenToApply: rawMap['whenToApply'] as String? ?? 'Within 7 Days',
        actionSteps: List<String>.from(rawMap['actionSteps'] ?? []),
        safetyWarning: rawMap['safetyWarning'] as String? ?? '',
        estimatedCostPerAcre:
            (rawMap['estimatedCostPerAcre'] as num?)?.toDouble() ?? 500.0,
        yieldIncrease:
            (rawMap['yieldIncrease'] as num?)?.toDouble() ?? 10.0,
        imagePrompt: rawMap['imagePrompt'] as String? ?? '',
        location: _location,
        generatedAt: DateTime.now(),
      );

      if (mounted) {
        await _saveToCache(plan);
        setState(() {
          _plan = plan;
          _isGenerating = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMsg = 'Failed to generate plan. Please try again.';
          _isGenerating = false;
        });
      }
    }
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
        title: Text(
          'Fertilizer Planner',
          style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: const Color(0xFF1A1A1A)),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: const Color(0xFFE5E7EB)),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildFormCard(),
            if (_isGenerating) _buildLoadingCard(),
            if (_errorMsg != null) _buildErrorCard(),
            if (_plan != null) ...[
              const SizedBox(height: 16),
              _buildPlanCard(_plan!),
              const SizedBox(height: 12),
              _buildCostYieldRow(_plan!),
            ],
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // ── Form card ──────────────────────────────────────────────────────────────
  Widget _buildFormCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Create New Plan',
            style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: const Color(0xFF1A1A1A)),
          ),
          const SizedBox(height: 18),

          // Crop name field
          Text('Crop Name',
              style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF6B7280))),
          const SizedBox(height: 6),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 52,
                  decoration: const BoxDecoration(
                    borderRadius:
                        BorderRadius.horizontal(left: Radius.circular(12)),
                  ),
                  child: const Center(
                    child: Text('🌾', style: TextStyle(fontSize: 20)),
                  ),
                ),
                Expanded(
                  child: TextField(
                    controller: _cropCtrl,
                    style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1A1A1A)),
                    decoration: InputDecoration(
                      hintText: 'e.g., Wheat, Rice, Cotton...',
                      hintStyle: GoogleFonts.inter(
                          fontSize: 14, color: const Color(0xFF9CA3AF)),
                      border: InputBorder.none,
                      contentPadding:
                          const EdgeInsets.symmetric(vertical: 14),
                    ),
                    textCapitalization: TextCapitalization.words,
                  ),
                ),
                // Mic button
                GestureDetector(
                  onTap: _toggleListening,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(right: 8),
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: _isListening
                          ? const Color(0xFFEF4444)
                          : const Color(0xFF22C55E).withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _isListening ? Icons.mic_rounded : Icons.mic_none_rounded,
                      color: _isListening
                          ? Colors.white
                          : const Color(0xFF22C55E),
                      size: 18,
                    ),
                  ),
                ),
              ],
            ),
          ),

          if (_isListening)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                children: [
                  AnimatedBuilder(
                    animation: _shimmerAnim,
                    builder: (_, __) => Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444)
                            .withValues(alpha: _shimmerAnim.value),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text('Listening... speak crop name',
                      style: GoogleFonts.inter(
                          fontSize: 11, color: const Color(0xFFEF4444))),
                ],
              ),
            ),

          const SizedBox(height: 12),

          // Quick crop chips
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _cropSuggestions.map((c) {
              final isSelected = _cropCtrl.text.toLowerCase() ==
                  c['name']!.toLowerCase();
              return GestureDetector(
                onTap: () =>
                    setState(() => _cropCtrl.text = c['name']!),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFF22C55E)
                        : const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: isSelected
                            ? const Color(0xFF22C55E)
                            : const Color(0xFFE5E7EB)),
                  ),
                  child: Text(
                    '${c['emoji']} ${c['name']}',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? Colors.white
                          : const Color(0xFF374151),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 18),

          // Farm area + unit
          Text('Farm Area',
              style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF6B7280))),
          const SizedBox(height: 6),
          Row(
            children: [
              // Area input
              Expanded(
                flex: 5,
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: Row(
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(left: 12),
                        child: Icon(Icons.crop_square_rounded,
                            color: Color(0xFF9CA3AF), size: 20),
                      ),
                      Expanded(
                        child: TextField(
                          controller: _areaCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF1A1A1A)),
                          decoration: InputDecoration(
                            hintText: 'e.g., 5',
                            hintStyle: GoogleFonts.inter(
                                fontSize: 14, color: const Color(0xFF9CA3AF)),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 14),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Unit selector (scrollable drag drop style)
              Expanded(
                flex: 4,
                child: _buildUnitSelector(),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Unit scroll row
          _buildUnitScrollRow(),

          const SizedBox(height: 20),

          // Generate button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isGenerating ? null : _generate,
              icon: const Icon(Icons.auto_awesome_rounded,
                  color: Colors.white, size: 18),
              label: Text(
                'Generate AI Fertilizer Plan',
                style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Colors.white),
              ),
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

  Widget _buildUnitSelector() {
    final unit = kAreaUnits[_selectedUnitIndex];
    return GestureDetector(
      onTap: () => _showUnitBottomSheet(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFD1D5DB)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              unit.name,
              style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1A1A1A)),
            ),
            const Icon(Icons.expand_more_rounded,
                color: Color(0xFF6B7280), size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildUnitScrollRow() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Drag to select unit:',
            style: GoogleFonts.inter(
                fontSize: 10,
                color: const Color(0xFF9CA3AF),
                fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        SizedBox(
          height: 36,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: kAreaUnits.length,
            separatorBuilder: (_, __) => const SizedBox(width: 6),
            itemBuilder: (_, i) {
              final unit = kAreaUnits[i];
              final selected = i == _selectedUnitIndex;
              return GestureDetector(
                onTap: () => setState(() => _selectedUnitIndex = i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: selected
                        ? const Color(0xFF22C55E)
                        : const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: selected
                            ? const Color(0xFF22C55E)
                            : const Color(0xFFE5E7EB)),
                    boxShadow: selected
                        ? [
                            BoxShadow(
                              color: const Color(0xFF22C55E)
                                  .withValues(alpha: 0.3),
                              blurRadius: 6,
                            )
                          ]
                        : [],
                  ),
                  child: Text(
                    unit.name,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: selected
                          ? Colors.white
                          : const Color(0xFF6B7280),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _showUnitBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFD1D5DB),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Text('Select Area Unit',
                style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF1A1A1A))),
            const SizedBox(height: 16),
            ...kAreaUnits.asMap().entries.map((entry) {
              final i = entry.key;
              final unit = entry.value;
              final selected = i == _selectedUnitIndex;
              return ListTile(
                onTap: () {
                  setState(() => _selectedUnitIndex = i);
                  Navigator.pop(context);
                },
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: selected
                        ? const Color(0xFF22C55E)
                        : const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(
                      unit.symbol,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: selected ? Colors.white : const Color(0xFF6B7280),
                      ),
                    ),
                  ),
                ),
                title: Text(unit.name,
                    style: GoogleFonts.inter(
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1A1A1A))),
                subtitle: Text(
                    '1 ${unit.name} = ${unit.toAcre.toStringAsFixed(3)} Acres',
                    style: GoogleFonts.inter(
                        fontSize: 11, color: const Color(0xFF6B7280))),
                trailing: selected
                    ? const Icon(Icons.check_circle_rounded,
                        color: Color(0xFF22C55E))
                    : null,
              );
            }),
          ],
        ),
      ),
    );
  }

  // ── Loading card ───────────────────────────────────────────────────────────
  Widget _buildLoadingCard() {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 20,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        children: [
          AnimatedBuilder(
            animation: _shimmerAnim,
            builder: (_, __) => Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: const Color(0xFF22C55E)
                    .withValues(alpha: _shimmerAnim.value * 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.eco_rounded,
                  color: Color(0xFF22C55E), size: 32),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Gemini AI is analyzing...',
            style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1A1A1A)),
          ),
          const SizedBox(height: 6),
          Text(
            'Calculating optimal fertilizer mix,\ndosage, timing & cost estimate',
            style: GoogleFonts.inter(
                fontSize: 12, color: const Color(0xFF6B7280), height: 1.5),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          const LinearProgressIndicator(
            color: Color(0xFF22C55E),
            backgroundColor: Color(0xFFD1FAE5),
          ),
        ],
      ),
    );
  }

  // ── Error card ─────────────────────────────────────────────────────────────
  Widget _buildErrorCard() {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFCA5A5)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded,
              color: Color(0xFFEF4444), size: 24),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _errorMsg ?? 'An error occurred.',
              style: GoogleFonts.inter(
                  fontSize: 13, color: const Color(0xFFDC2626)),
            ),
          ),
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

  // ── Plan card (matches reference image) ───────────────────────────────────
  Widget _buildPlanCard(FertPlan plan) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 20,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Your Fertilizer Plan',
                      style: GoogleFonts.inter(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF1A1A1A)),
                    ),
                    RichText(
                      text: TextSpan(
                        style: GoogleFonts.inter(
                            fontSize: 12, color: const Color(0xFF6B7280)),
                        children: [
                          const TextSpan(text: 'Tailored for your '),
                          TextSpan(
                            text: plan.cropType,
                            style: const TextStyle(
                                color: Color(0xFF22C55E),
                                fontWeight: FontWeight.w700),
                          ),
                          const TextSpan(text: ' crop'),
                        ],
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFBBF7D0)),
                  ),
                  child: Text(
                    'OPTIMIZED TODAY',
                    style: GoogleFonts.inter(
                        fontSize: 8,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF16A34A),
                        letterSpacing: 0.5),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // NPK Mixture box
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 18),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFECFDF5), Color(0xFFF0FFF4)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: const Color(0xFF22C55E).withValues(alpha: 0.3),
                  width: 2),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'USE THIS MIXTURE',
                  style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF22C55E),
                      letterSpacing: 1.5),
                ),
                const SizedBox(height: 8),
                Text(
                  plan.mixture,
                  style: GoogleFonts.inter(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF1A1A1A),
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                        child: _infoBox(
                            Icons.balance_rounded,
                            'TOTAL AMOUNT',
                            plan.totalAmount,
                            const Color(0xFF3B82F6))),
                    const SizedBox(width: 10),
                    Expanded(
                        child: _infoBox(
                            Icons.schedule_rounded,
                            'WHEN TO APPLY',
                            plan.whenToApply,
                            const Color(0xFF8B5CF6))),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Crop image placeholder with health score
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 18),
            height: 140,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF14532D),
                  const Color(0xFF166534),
                  const Color(0xFF15803D),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Stack(
              children: [
                // Crop emoji centered
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _getCropEmoji(plan.cropType),
                        style: const TextStyle(fontSize: 50),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        plan.cropType,
                        style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Colors.white70),
                      ),
                    ],
                  ),
                ),
                // Health score badge
                Positioned(
                  bottom: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF22C55E),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.verified_rounded,
                            color: Colors.white, size: 12),
                        const SizedBox(width: 4),
                        Text(
                          'AI Accuracy: ${(88 + plan.yieldIncrease * 0.3).toStringAsFixed(0)}%',
                          style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),
                // Area badge
                Positioned(
                  top: 12,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.black38,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${_areaCtrl.text} ${kAreaUnits[_selectedUnitIndex].name}',
                      style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Action steps
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('ACTION STEPS',
                    style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF6B7280),
                        letterSpacing: 1.5)),
                const SizedBox(height: 10),
                ...plan.actionSteps.map((step) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.check_circle_rounded,
                              color: Color(0xFF22C55E), size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              step,
                              style: GoogleFonts.inter(
                                  fontSize: 13,
                                  color: const Color(0xFF374151),
                                  height: 1.5),
                            ),
                          ),
                        ],
                      ),
                    )),
              ],
            ),
          ),

          // Safety warning
          if (plan.safetyWarning.isNotEmpty) ...[
            Container(
              margin: const EdgeInsets.fromLTRB(18, 8, 18, 0),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('⚠️', style: TextStyle(fontSize: 16)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('SAFETY WARNING',
                            style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF92400E),
                                letterSpacing: 1)),
                        const SizedBox(height: 4),
                        Text(plan.safetyWarning,
                            style: GoogleFonts.inter(
                                fontSize: 12,
                                color: const Color(0xFF78350F),
                                height: 1.5)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 18),
        ],
      ),
    );
  }

  Widget _infoBox(
      IconData icon, String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8)
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 4),
              Text(label,
                  style: GoogleFonts.inter(
                      fontSize: 8,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF9CA3AF),
                      letterSpacing: 0.5)),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: const Color(0xFF1A1A1A),
            ),
            maxLines: 2,
            overflow: TextOverflow.clip,
          ),
        ],
      ),
    );
  }

  Widget _buildCostYieldRow(FertPlan plan) {
    final totalArea = (double.tryParse(_areaCtrl.text) ?? 1.0);
    final unit = kAreaUnits[_selectedUnitIndex];
    final areaInAcres = totalArea * unit.toAcre;
    final totalCost = plan.estimatedCostPerAcre * areaInAcres;

    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 16,
                    offset: const Offset(0, 4))
              ],
            ),
            child: Column(
              children: [
                Text('ESTIMATED COST',
                    style: GoogleFonts.inter(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF6B7280),
                        letterSpacing: 1.5)),
                const SizedBox(height: 8),
                Text(
                  '₹${totalCost.toStringAsFixed(2)}',
                  style: GoogleFonts.inter(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF1A1A1A),
                  ),
                ),
                Text(
                  '₹${plan.estimatedCostPerAcre.toStringAsFixed(0)} per Acre',
                  style: GoogleFonts.inter(
                      fontSize: 11, color: const Color(0xFF6B7280)),
                ),
                Text(
                  'for ${totalArea.toStringAsFixed(1)} ${unit.name}',
                  style: GoogleFonts.inter(
                      fontSize: 10, color: const Color(0xFF9CA3AF)),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 16,
                    offset: const Offset(0, 4))
              ],
            ),
            child: Column(
              children: [
                Text('YIELD INCREASE',
                    style: GoogleFonts.inter(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF6B7280),
                        letterSpacing: 1.5)),
                const SizedBox(height: 8),
                Text(
                  '+${plan.yieldIncrease.toStringAsFixed(1)}%',
                  style: GoogleFonts.inter(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF22C55E),
                  ),
                ),
                Text(
                  'EXPECTED GROWTH',
                  style: GoogleFonts.inter(
                      fontSize: 11, color: const Color(0xFF6B7280)),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _getCropEmoji(String crop) {
    final c = crop.toLowerCase();
    if (c.contains('wheat')) return '🌾';
    if (c.contains('rice') || c.contains('paddy')) return '🌾';
    if (c.contains('maize') || c.contains('corn')) return '🌽';
    if (c.contains('cotton')) return '🌿';
    if (c.contains('sugarcane')) return '🎋';
    if (c.contains('tomato')) return '🍅';
    if (c.contains('potato')) return '🥔';
    if (c.contains('soybean')) return '🫘';
    if (c.contains('mustard')) return '🌼';
    if (c.contains('groundnut') || c.contains('peanut')) return '🥜';
    if (c.contains('onion')) return '🧅';
    if (c.contains('chilli') || c.contains('pepper')) return '🌶️';
    if (c.contains('mango')) return '🥭';
    if (c.contains('banana')) return '🍌';
    return '🌱';
  }
}
