import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../services/market_service.dart';
import '../services/location_service.dart';

class MarketDecisionScreen extends StatefulWidget {
  const MarketDecisionScreen({super.key});

  @override
  State<MarketDecisionScreen> createState() => _MarketDecisionScreenState();
}

class _MarketDecisionScreenState extends State<MarketDecisionScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchCtrl = TextEditingController();
  late stt.SpeechToText _speech;
  bool _isListening = false;
  bool _speechAvailable = false;

  bool _loadingMain = false;
  bool _loadingTrending = true;
  MarketCropData? _mainCrop;
  List<MarketCropData> _trending = [];
  String _location = 'India';
  String? _errorMsg;

  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  final List<Map<String, String>> _quickPicks = [
    {'name': 'Wheat', 'emoji': '🌾'},
    {'name': 'Rice', 'emoji': '🍚'},
    {'name': 'Tomato', 'emoji': '🍅'},
    {'name': 'Maize', 'emoji': '🌽'},
    {'name': 'Onion', 'emoji': '🧅'},
    {'name': 'Potato', 'emoji': '🥔'},
    {'name': 'Soybean', 'emoji': '🫘'},
    {'name': 'Mustard', 'emoji': '🌼'},
    {'name': 'Cotton', 'emoji': '🌿'},
    {'name': 'Groundnut', 'emoji': '🥜'},
  ];

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.85, end: 1.0).animate(_pulseCtrl);
    _initSpeech();
    _loadLocation();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _pulseCtrl.dispose();
    _speech.stop();
    super.dispose();
  }

  Future<void> _initSpeech() async {
    _speech = stt.SpeechToText();
    final ok = await _speech.initialize(
      onStatus: (s) {
        if (s == 'done' || s == 'notListening') {
          if (mounted) setState(() => _isListening = false);
        }
      },
    );
    if (mounted) setState(() => _speechAvailable = ok);
  }

  Future<void> _loadLocation() async {
    final l = await LocationService.getLocationData();
    if (mounted) {
      setState(() => _location = l['location'] ?? 'India');
    }
    _loadTrending();
  }

  Future<void> _loadTrending() async {
    setState(() => _loadingTrending = true);
    final t = await MarketService.fetchTrending(location: _location);
    if (mounted) setState(() { _trending = t; _loadingTrending = false; });
  }

  Future<void> _toggleVoice() async {
    if (!_speechAvailable) return;
    if (_isListening) {
      await _speech.stop();
      setState(() => _isListening = false);
    } else {
      setState(() => _isListening = true);
      await _speech.listen(
        onResult: (r) {
          if (mounted) {
            setState(() {
              _searchCtrl.text = r.recognizedWords;
              _searchCtrl.selection = TextSelection.fromPosition(
                  TextPosition(offset: _searchCtrl.text.length));
            });
          }
        },
        listenFor: const Duration(seconds: 8),
        pauseFor: const Duration(seconds: 3),
        partialResults: true,
      );
    }
  }

  Future<void> _search([String? quickCrop]) async {
    final crop = (quickCrop ?? _searchCtrl.text).trim();
    if (crop.isEmpty) return;
    _searchCtrl.text = crop;
    FocusScope.of(context).unfocus();
    setState(() { _loadingMain = true; _mainCrop = null; _errorMsg = null; });
    try {
      final data = await MarketService.fetchCropMarket(
          cropName: crop, location: _location);
      if (mounted) setState(() { _mainCrop = data; _loadingMain = false; });
    } catch (e) {
      if (mounted) setState(() { _errorMsg = 'Failed to fetch market data.'; _loadingMain = false; });
    }
  }

  Color _recColor(String rec) {
    switch (rec) {
      case 'SELL NOW': return const Color(0xFFEF4444);
      case 'HOLD':     return const Color(0xFF3B82F6);
      default:         return const Color(0xFFF59E0B);
    }
  }

  Color _trendColor(String trend) {
    if (trend == 'High') return const Color(0xFF22C55E);
    if (trend == 'Low')  return const Color(0xFFEF4444);
    return const Color(0xFFF59E0B);
  }

  IconData _trendIcon(String trend) {
    if (trend == 'High') return Icons.arrow_upward_rounded;
    if (trend == 'Low')  return Icons.arrow_downward_rounded;
    return Icons.remove_rounded;
  }

  String _cropEmoji(String cropName) {
    final lower = cropName.toLowerCase();
    final map = {
      'wheat': '🌾', 'rice': '🍚', 'tomato': '🍅',
      'maize': '🌽', 'onion': '🧅', 'potato': '🥔',
      'soybean': '🫘', 'mustard': '🌼', 'cotton': '🌿',
      'groundnut': '🥜', 'sugarcane': '🎋', 'chilli': '🌶️',
      'garlic': '🧄', 'banana': '🍌', 'mango': '🥭',
    };
    for (final k in map.keys) {
      if (lower.contains(k)) return map[k]!;
    }
    return '🌱';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded,
              color: Color(0xFF1A1A1A)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Market Decision Helper',
            style: GoogleFonts.inter(
                fontSize: 17,
                fontWeight: FontWeight.w900,
                color: const Color(0xFF1A1A1A))),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded,
                color: Color(0xFFE85A2B)),
            onPressed: _loadTrending,
          ),
        ],
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
            _buildSearchBar(),
            const SizedBox(height: 12),
            _buildQuickPicks(),
            const SizedBox(height: 16),
            if (_loadingMain) _buildLoadingCard(),
            if (_errorMsg != null) _buildErrorCard(),
            if (_mainCrop != null) _buildMainCropCard(_mainCrop!),
            const SizedBox(height: 20),
            _buildTrendingSection(),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 10,
              offset: const Offset(0, 2))
        ],
      ),
      child: Row(
        children: [
          const SizedBox(width: 14),
          const Icon(Icons.search_rounded, color: Color(0xFF9CA3AF), size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _searchCtrl,
              style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1A1A1A)),
              decoration: InputDecoration(
                hintText: 'Search crop e.g., Wheat',
                hintStyle: GoogleFonts.inter(
                    fontSize: 14, color: const Color(0xFF9CA3AF)),
                border: InputBorder.none,
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 14),
              ),
              textCapitalization: TextCapitalization.words,
              onSubmitted: (_) => _search(),
            ),
          ),
          GestureDetector(
            onTap: _toggleVoice,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 8),
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _isListening
                    ? const Color(0xFFEF4444)
                    : const Color(0xFFFFF3EE),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _isListening ? Icons.mic_rounded : Icons.mic_none_rounded,
                color: _isListening ? Colors.white : const Color(0xFFE85A2B),
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickPicks() {
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _quickPicks.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (_, i) {
          final c = _quickPicks[i];
          final sel = _searchCtrl.text.toLowerCase() ==
              c['name']!.toLowerCase();
          return GestureDetector(
            onTap: () => _search(c['name']),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: sel
                    ? const Color(0xFFE85A2B)
                    : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: sel
                        ? const Color(0xFFE85A2B)
                        : const Color(0xFFE5E7EB)),
              ),
              child: Text(
                '${c['emoji']} ${c['name']}',
                style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: sel ? Colors.white : const Color(0xFF374151)),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLoadingCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 12)
        ],
      ),
      child: Column(
        children: [
          AnimatedBuilder(
            animation: _pulseAnim,
            builder: (_, __) => Transform.scale(
              scale: _pulseAnim.value,
              child: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color:
                      const Color(0xFFE85A2B).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.trending_up_rounded,
                    color: Color(0xFFE85A2B), size: 30),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text('Fetching Market Data...',
              style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1A1A1A))),
          Text('DirectMandi + Gemini AI Analysis',
              style: GoogleFonts.inter(
                  fontSize: 11, color: const Color(0xFF6B7280))),
          const SizedBox(height: 14),
          const LinearProgressIndicator(
            color: Color(0xFFE85A2B),
            backgroundColor: Color(0xFFFFF3EE),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
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
            onPressed: () => _search(),
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

  Widget _buildMainCropCard(MarketCropData d) {
    final recColor = _recColor(d.recommendation);
    final trendColor = _trendColor(d.demandTrend);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.07),
              blurRadius: 16,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        children: [
          // ── Crop hero image ───────────────────────────────────────────────
          ClipRRect(
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(20)),
            child: Stack(
              children: [
                Container(
                  height: 180,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF1A3A1A),
                        const Color(0xFF2D6A2D),
                        const Color(0xFF3D8B3D),
                      ],
                      begin: Alignment.bottomLeft,
                      end: Alignment.topRight,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      d.emoji,
                      style: const TextStyle(fontSize: 80),
                    ),
                  ),
                ),
                // VISION AI ANALYSIS badge
                Positioned(
                  top: 14,
                  left: 14,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE85A2B),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text('VISION AI ANALYSIS',
                        style: GoogleFonts.inter(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: 0.5)),
                  ),
                ),
                // Crop name
                Positioned(
                  bottom: 16,
                  left: 16,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(d.cropName,
                          style: GoogleFonts.inter(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            shadows: const [
                              Shadow(
                                  color: Colors.black54, blurRadius: 6)
                            ],
                          )),
                      Text('📍 ${d.mandi}',
                          style: GoogleFonts.inter(
                              fontSize: 11,
                              color: Colors.white70)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Price + Demand ────────────────────────────────────────────────
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('CURRENT MARKET PRICE',
                          style: GoogleFonts.inter(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF9CA3AF),
                              letterSpacing: 1)),
                      const SizedBox(height: 4),
                      Text(
                        '₹${d.pricePerQuintal.toStringAsFixed(0)}',
                        style: GoogleFonts.inter(
                          fontSize: 30,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF1A1A1A),
                        ),
                      ),
                      Text('/quintal',
                          style: GoogleFonts.inter(
                              fontSize: 12, color: const Color(0xFF6B7280))),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('DEMAND TREND',
                        style: GoogleFonts.inter(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF9CA3AF),
                            letterSpacing: 1)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(d.demandTrend,
                            style: GoogleFonts.inter(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                color: trendColor)),
                        const SizedBox(width: 4),
                        Icon(_trendIcon(d.demandTrend),
                            color: trendColor, size: 22),
                      ],
                    ),
                    if (d.changePercent != 0)
                      Text(
                        '${d.changePercent >= 0 ? '+' : ''}${d.changePercent.toStringAsFixed(1)}%',
                        style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: trendColor),
                      ),
                  ],
                ),
              ],
            ),
          ),

          // ── AI Recommendation ─────────────────────────────────────────────
          Container(
            margin: const EdgeInsets.fromLTRB(18, 0, 18, 16),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: recColor.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: recColor.withValues(alpha: 0.25)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.psychology_rounded, color: recColor, size: 18),
                    const SizedBox(width: 6),
                    Text('AI Recommendation: ',
                        style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF374151))),
                    Text(d.recommendation,
                        style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            color: recColor)),
                  ],
                ),
                if (d.aiAnalysis.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(d.aiAnalysis,
                      style: GoogleFonts.inter(
                          fontSize: 12,
                          color: const Color(0xFF6B7280),
                          height: 1.5)),
                ],
              ],
            ),
          ),

          // ── View Full Analysis ────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _showFullAnalysisSheet(d),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE85A2B),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('View Full Analysis',
                        style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: Colors.white)),
                    const SizedBox(width: 8),
                    const Icon(Icons.arrow_forward_rounded,
                        color: Colors.white, size: 16),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrendingSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.trending_up_rounded,
                color: Color(0xFFE85A2B), size: 20),
            const SizedBox(width: 6),
            Text('Other Trending Crops',
                style: GoogleFonts.inter(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF1A1A1A))),
          ],
        ),
        const SizedBox(height: 12),
        if (_loadingTrending)
          const Center(
              child: CircularProgressIndicator(color: Color(0xFFE85A2B)))
        else
          ..._trending
              .where((t) =>
                  _mainCrop == null ||
                  t.cropName.toLowerCase() !=
                      _mainCrop!.cropName.toLowerCase())
              .map((t) => _trendingTile(t)),
      ],
    );
  }

  Widget _trendingTile(MarketCropData d) {
    final tColor = _trendColor(d.demandTrend);
    final sign = d.changePercent >= 0 ? '+' : '';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Row(
        children: [
          // Crop image circle
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF1A3A1A),
                  const Color(0xFF2D6A2D),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Center(
              child: Text(d.emoji,
                  style: const TextStyle(fontSize: 28)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(d.cropName,
                    style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF1A1A1A))),
                Text('₹${d.pricePerQuintal.toStringAsFixed(0)} /quintal',
                    style: GoogleFonts.inter(
                        fontSize: 12, color: const Color(0xFF6B7280))),
              ],
            ),
          ),
          // Change badge
          GestureDetector(
            onTap: () => _search(d.cropName),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: tColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
                border:
                    Border.all(color: tColor.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(_trendIcon(d.demandTrend),
                      color: tColor, size: 12),
                  const SizedBox(width: 3),
                  Text(
                    '$sign${d.changePercent.toStringAsFixed(1)}%',
                    style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: tColor),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showFullAnalysisSheet(MarketCropData d) {
    final recColor = _recColor(d.recommendation);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        builder: (_, ctrl) => SingleChildScrollView(
          controller: ctrl,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD1D5DB),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text('${d.emoji} ${d.cropName} — Full Analysis',
                  style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF1A1A1A))),
              const SizedBox(height: 16),
              _sheetRow('Current Price',
                  '₹${d.pricePerQuintal.toStringAsFixed(0)}/quintal'),
              _sheetRow('Market Demand', d.demandTrend),
              _sheetRow('Mandi', d.mandi),
              _sheetRow('AI Recommendation', d.recommendation,
                  valueColor: recColor),
              const SizedBox(height: 12),
              Text('AI Market Analysis',
                  style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF374151))),
              const SizedBox(height: 6),
              Text(d.aiAnalysis.isNotEmpty
                  ? d.aiAnalysis
                  : 'Detailed AI analysis not available for this crop.',
                  style: GoogleFonts.inter(
                      fontSize: 13,
                      color: const Color(0xFF6B7280),
                      height: 1.6)),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3EE),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: const Color(0xFFE85A2B)
                          .withValues(alpha: 0.3)),
                ),
                child: Text(
                  '🕐 Data source: DirectMandi.com + Gemini AI\nLast updated: ${_timeAgo(d.fetchedAt)}',
                  style: GoogleFonts.inter(
                      fontSize: 11, color: const Color(0xFF6B7280)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sheetRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: GoogleFonts.inter(
                  fontSize: 13, color: const Color(0xFF6B7280))),
          Text(value,
              style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: valueColor ?? const Color(0xFF1A1A1A))),
        ],
      ),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    return '${diff.inHours}h ago';
  }
}
