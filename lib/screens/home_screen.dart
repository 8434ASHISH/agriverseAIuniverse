import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/location_service.dart';
import '../services/weather_service.dart';
import 'vision_scanner_screen.dart';
import 'weather_intel_screen.dart';
import 'flood_advisory_screen.dart';
import 'drought_advisory_screen.dart';
import 'fertilizer_planner_screen.dart';
import 'crop_selection_screen.dart';
import 'market_decision_screen.dart';
import 'chat_screen.dart';
import 'feature_screen.dart';
import 'emergency_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  String _location = 'Detecting...';
  double _temp = 28.0;
  int _rainPct = 20;
  bool _loading = true;
  String _condition = 'Partly Cloudy';

  // Ticker
  late ScrollController _tickerScrollCtrl;
  late AnimationController _tickerCtrl;

  // Language
  String _selectedLang = 'English';
  final List<Map<String, String>> _languages = [
    {'code': 'en', 'name': 'English', 'native': 'English'},
    {'code': 'hi', 'name': 'Hindi', 'native': 'हिंदी'},
    {'code': 'mr', 'name': 'Marathi', 'native': 'मराठी'},
    {'code': 'te', 'name': 'Telugu', 'native': 'తెలుగు'},
    {'code': 'ta', 'name': 'Tamil', 'native': 'தமிழ்'},
    {'code': 'bn', 'name': 'Bengali', 'native': 'বাংলা'},
    {'code': 'pa', 'name': 'Punjabi', 'native': 'ਪੰਜਾਬੀ'},
    {'code': 'gu', 'name': 'Gujarati', 'native': 'ગુજરાતી'},
    {'code': 'kn', 'name': 'Kannada', 'native': 'ಕನ್ನಡ'},
  ];

  List<String> get _tickerMessages => [
    '🌡️ ${_location}: ${_temp.toStringAsFixed(0)}°C — $_condition',
    '💧 Humidity: $_rainPct% — Good irrigation window',
    '📈 Wheat prices up 5% this week — Good time to sell',
    '🌾 Demand rising for Avocado in northern markets',
    '🌱 Soybean market steady — Hold for 7 more days',
    '🍅 Tomato shortage in North India — Prices expected to rise',
    '🌿 Cotton export demand high — Consider selling now',
    '⛅ Weather forecast: Expect light rain in next 48 hours',
    '💡 Tip: Apply fertilizer before rain for better absorption',
    '🐛 Alert: Fall Armyworm spotted in Kharif crops in Vidarbha',
    '🌻 Mustard MSP set at ₹5,650/quintal this season',
    '📊 Onion prices at ₹2800/quintal — Stable demand',
  ];

  @override
  void initState() {
    super.initState();
    _tickerScrollCtrl = ScrollController();
    _tickerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 120), // slow comfortable scroll
    )..addListener(() {
      if (_tickerScrollCtrl.hasClients &&
          _tickerScrollCtrl.position.maxScrollExtent > 0) {
        _tickerScrollCtrl.jumpTo(
          _tickerCtrl.value *
              _tickerScrollCtrl.position.maxScrollExtent,
        );
      }
    });
    _tickerCtrl.repeat();
    _loadData();
  }

  @override
  void dispose() {
    _tickerScrollCtrl.dispose();
    _tickerCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final locData = await LocationService.getLocationData();
      final weather = await WeatherService.fetchCurrentWeather();
      if (mounted) {
        setState(() {
          _location = locData['location'] ?? 'Unknown';
          _temp = weather['temp'] ?? 28.0;
          _rainPct = weather['humidity'] ?? 20;
          _condition = weather['condition'] ?? 'Partly Cloudy';
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _navigateToFeature(String feature) {
    switch (feature) {
      case 'pest':
        Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => const VisionScannerScreen()));
        break;
      case 'weather':
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => const WeatherIntelScreen()));
        break;
      case 'flood':
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => const FloodAdvisoryScreen()));
        break;
      case 'emergency':
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => const EmergencyScreen()));
        break;
      case 'crop':
        Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => const CropSelectionScreen()));
        break;
      case 'market':
        Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => const MarketDecisionScreen()));
        break;
      case 'drought':
        Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => const DroughtAdvisoryScreen()));
        break;
      case 'fertilizer':
        Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => const FertilizerPlannerScreen()));
        break;
    }
  }

  String get location => _location;

  void _showLanguageSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF111A11),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                    color: const Color(0xFF22C55E).withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            Text('🌐 Select Language',
                style: GoogleFonts.inter(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: Colors.white)),
            const SizedBox(height: 4),
            Text('App interface will switch to selected language',
                style: GoogleFonts.inter(
                    fontSize: 11, color: Colors.white38)),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _languages.map((lang) {
                final isSelected = _selectedLang == lang['name'];
                return GestureDetector(
                  onTap: () {
                    setState(() => _selectedLang = lang['name']!);
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(
                          '✅ Language set to ${lang['name']} (${lang['native']})',
                          style: GoogleFonts.inter(fontSize: 13)),
                      backgroundColor: const Color(0xFF16A34A),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ));
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFF22C55E)
                          : const Color(0xFF1A2A1A),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: isSelected
                              ? const Color(0xFF22C55E)
                              : const Color(0xFF2A3A2A)),
                    ),
                    child: Column(
                      children: [
                        Text(lang['native']!,
                            style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: isSelected
                                    ? Colors.black
                                    : Colors.white)),
                        Text(lang['name']!,
                            style: GoogleFonts.inter(
                                fontSize: 10,
                                color: isSelected
                                    ? Colors.black54
                                    : Colors.white38)),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0F0A),
      body: SafeArea(
        child: RefreshIndicator(
          color: const Color(0xFF22C55E),
          backgroundColor: const Color(0xFF1A2A1A),
          onRefresh: _loadData,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildAppBar(),
                _buildLocationHeader(),
                _buildMarketAlertTicker(),
                _buildHeroBanner(),
                _buildToolkitSection(),
                _buildFeatureCards(),
                _buildFooter(),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: _buildEmergencyButton(),
    );
  }

  Widget _buildAppBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFF22C55E),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.eco_rounded, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 10),
          Text(
            'AgriVerse AI',
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: -0.5,
            ),
          ),
          const Spacer(),
          // Language selector button
          GestureDetector(
            onTap: _showLanguageSheet,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF1A2A1A),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF22C55E).withValues(alpha: 0.4)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.translate_rounded,
                      color: Color(0xFF22C55E), size: 14),
                  const SizedBox(width: 4),
                  Text(
                    _selectedLang == 'English'
                        ? 'EN'
                        : _languages.firstWhere(
                            (l) => l['name'] == _selectedLang,
                            orElse: () => {'native': 'EN'},
                          )['native']!,
                    style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF22C55E)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFF1A2A1A),
              borderRadius: BorderRadius.circular(19),
              border: Border.all(color: const Color(0xFF2A3A2A)),
            ),
            child: const Icon(Icons.person_outline_rounded,
                color: Color(0xFF22C55E), size: 20),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      child: Row(
        children: [
          Icon(Icons.location_on_rounded,
              color: const Color(0xFF22C55E), size: 18),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'CURRENT LOCATION',
                  style: GoogleFonts.inter(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF22C55E),
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 2),
                _loading
                    ? SizedBox(
                        height: 14,
                        width: 160,
                        child: LinearProgressIndicator(
                          color: const Color(0xFF22C55E),
                          backgroundColor:
                              const Color(0xFF22C55E).withOpacity(0.2),
                        ),
                      )
                    : Text(
                        '$_location: ${_temp.toStringAsFixed(0)}°C - $_rainPct% Rain',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
              ],
            ),
          ),
          GestureDetector(
            onTap: _loadData,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFF1A2A1A),
                borderRadius: BorderRadius.circular(18),
              ),
              child: _loading
                  ? const Padding(
                      padding: EdgeInsets.all(8),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFF22C55E),
                      ),
                    )
                  : const Icon(Icons.refresh_rounded,
                      color: Color(0xFF22C55E), size: 18),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMarketAlertTicker() {
    final msgs = _tickerMessages;
    final fullText = msgs.join('   •   ');
    return Container(
      height: 34,
      color: const Color(0xFF0D150D),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            color: const Color(0xFF22C55E).withValues(alpha: 0.15),
            child: Text(
              '● MARKET ALERTS',
              style: GoogleFonts.inter(
                fontSize: 9,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF22C55E),
                letterSpacing: 1.5,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SingleChildScrollView(
              controller: _tickerScrollCtrl,
              scrollDirection: Axis.horizontal,
              physics: const NeverScrollableScrollPhysics(),
              child: Row(
                children: [
                  Text(
                    fullText + '   •   ' + fullText, // duplicate for seamless scroll
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withValues(alpha: 0.75),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroBanner() {
    return Container(
      margin: const EdgeInsets.all(14),
      height: 240,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        image: const DecorationImage(
          image: NetworkImage(
              'https://images.unsplash.com/photo-1574943320219-553eb213f72d?w=800&auto=format&fit=crop&q=80'),
          fit: BoxFit.cover,
          colorFilter:
              ColorFilter.mode(Color(0x88000000), BlendMode.darken),
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0x660A0F0A),
              Color(0xCC0A0F0A),
            ],
          ),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF22C55E),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'GEMINI 3 INTELLIGENCE',
                style: GoogleFonts.inter(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  color: Colors.black,
                  letterSpacing: 1.5,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Explain My\nProblem',
              style: GoogleFonts.inter(
                fontSize: 32,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                height: 1.0,
                letterSpacing: -1,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Diagnose pests, diseases, or\nnutrient issues instantly.',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: Colors.white.withOpacity(0.7),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => _navigateToFeature('pest'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF22C55E),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.camera_alt_rounded,
                              color: Colors.black, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            'Upload Photo',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: Colors.black,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => ChatScreen(
                                location: _location, temp: _temp))),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A2A1A),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: const Color(0xFF2A3A2A), width: 1.5),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.chat_bubble_outline_rounded,
                              color: Colors.white, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            'Start Chat',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToolkitSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            'Intelligent Toolkit',
            style: GoogleFonts.inter(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: -0.5,
            ),
          ),
          Text(
            '7 SERVICES ACTIVE',
            style: GoogleFonts.inter(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF22C55E),
              letterSpacing: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureCards() {
    final features = [
      {
        'id': 'pest',
        'title': 'Pest & Disease\nDetection',
        'desc': 'AI scanning for 500+\ncommon crop issues',
        'icon': Icons.biotech_rounded,
        'color': const Color(0xFF22C55E),
        'bg': const Color(0xFF0D1A0D),
      },
      {
        'id': 'weather',
        'title': 'Weather\nIntelligence',
        'desc': 'Hyper-local hourly farm\natmosphere alerts',
        'icon': Icons.thermostat_rounded,
        'color': const Color(0xFF3B82F6),
        'bg': const Color(0xFF0D1220),
      },
      {
        'id': 'crop',
        'title': 'Smart Crop\nSelection',
        'desc': 'Optimal yields based on\nsoil and climate',
        'icon': Icons.grass_rounded,
        'color': const Color(0xFFF59E0B),
        'bg': const Color(0xFF1A1500),
      },
      {
        'id': 'market',
        'title': 'Market Decision\nHelper',
        'desc': 'Price trends and real-\ntime sell timing',
        'icon': Icons.trending_up_rounded,
        'color': const Color(0xFF22C55E),
        'bg': const Color(0xFF0D1A0D),
      },
      {
        'id': 'drought',
        'title': 'Drought\nAdvisory',
        'desc': 'Irrigation schedules\nand moisture plans',
        'icon': Icons.water_drop_rounded,
        'color': const Color(0xFFF59E0B),
        'bg': const Color(0xFF1A1500),
      },
      {
        'id': 'flood',
        'title': 'Flood\nAdvisory',
        'desc': 'Runoff management\nand storm alerts',
        'icon': Icons.flood_rounded,
        'color': const Color(0xFF3B82F6),
        'bg': const Color(0xFF0D1220),
      },
    ];

    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.05,
            ),
            itemCount: features.length,
            itemBuilder: (context, index) {
              final f = features[index];
              return _buildCard(
                onTap: () => _navigateToFeature(f['id'] as String),
                icon: f['icon'] as IconData,
                iconColor: f['color'] as Color,
                iconBg: f['bg'] as Color,
                title: f['title'] as String,
                desc: f['desc'] as String,
              );
            },
          ),
          const SizedBox(height: 12),

          // Full-width Fertilizer card
          GestureDetector(
            onTap: () => _navigateToFeature('fertilizer'),
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFF111811),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF1E2E1E), width: 1.5),
              ),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D1A0D),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.compost_rounded,
                        color: Color(0xFF22C55E), size: 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Fertilizer Planner',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Precision nutrient calculation and\napplication schedule',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w400,
                            color: Colors.white.withOpacity(0.5),
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios_rounded,
                      color: Color(0xFF22C55E), size: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard({
    required VoidCallback onTap,
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String title,
    required String desc,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF111811),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF1E2E1E), width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const Spacer(),
            Text(
              title,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              desc,
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w400,
                color: Colors.white.withOpacity(0.45),
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Center(
        child: Text(
          'AGRIVERSE AI V3.0 • FOCUSED FARMING',
          style: GoogleFonts.inter(
            fontSize: 9,
            fontWeight: FontWeight.w600,
            color: Colors.white.withOpacity(0.25),
            letterSpacing: 2,
          ),
        ),
      ),
    );
  }

  Widget _buildEmergencyButton() {
    return GestureDetector(
      onTap: () => _navigateToFeature('emergency'),
      child: Container(
        margin: const EdgeInsets.fromLTRB(14, 0, 14, 12),
        height: 52,
        decoration: BoxDecoration(
          color: const Color(0xFFEAB308),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.warning_amber_rounded,
                color: Colors.black, size: 20),
            const SizedBox(width: 10),
            Text(
              'EMERGENCY MODE',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: Colors.black,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
