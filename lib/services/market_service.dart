import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'gemini_service.dart';

class MarketCropData {
  final String cropName;
  final String emoji;
  final double pricePerQuintal;
  final String demandTrend; // 'High' | 'Medium' | 'Low'
  final double changePercent; // +/- percent
  final String recommendation; // 'SELL NOW' | 'HOLD' | 'WAIT'
  final String aiAnalysis;
  final String mandi;
  final DateTime fetchedAt;

  MarketCropData({
    required this.cropName,
    required this.emoji,
    required this.pricePerQuintal,
    required this.demandTrend,
    required this.changePercent,
    required this.recommendation,
    required this.aiAnalysis,
    required this.mandi,
    required this.fetchedAt,
  });

  Map<String, dynamic> toJson() => {
        'cropName': cropName,
        'emoji': emoji,
        'pricePerQuintal': pricePerQuintal,
        'demandTrend': demandTrend,
        'changePercent': changePercent,
        'recommendation': recommendation,
        'aiAnalysis': aiAnalysis,
        'mandi': mandi,
        'fetchedAt': fetchedAt.toIso8601String(),
      };

  factory MarketCropData.fromJson(Map<String, dynamic> j) => MarketCropData(
        cropName: j['cropName'] ?? '',
        emoji: j['emoji'] ?? '🌱',
        pricePerQuintal:
            (j['pricePerQuintal'] as num?)?.toDouble() ?? 0.0,
        demandTrend: j['demandTrend'] ?? 'Medium',
        changePercent:
            (j['changePercent'] as num?)?.toDouble() ?? 0.0,
        recommendation: j['recommendation'] ?? 'HOLD',
        aiAnalysis: j['aiAnalysis'] ?? '',
        mandi: j['mandi'] ?? '',
        fetchedAt:
            DateTime.tryParse(j['fetchedAt'] ?? '') ?? DateTime.now(),
      );
}

// ── Baseline MSP / realistic price data for Indian crops ─────────────────────
final Map<String, Map<String, dynamic>> _baselineData = {
  'wheat':    {'price': 2425.0, 'emoji': '🌾', 'mandi': 'Hapur, UP'},
  'rice':     {'price': 3100.0, 'emoji': '🍚', 'mandi': 'Cuttack, OD'},
  'tomato':   {'price': 1200.0, 'emoji': '🍅', 'mandi': 'Kolar, KA'},
  'maize':    {'price': 1850.0, 'emoji': '🌽', 'mandi': 'Davangere, KA'},
  'onion':    {'price': 2800.0, 'emoji': '🧅', 'mandi': 'Lasalgaon, MH'},
  'potato':   {'price': 1100.0, 'emoji': '🥔', 'mandi': 'Agra, UP'},
  'soybean':  {'price': 4300.0, 'emoji': '🫘', 'mandi': 'Indore, MP'},
  'cotton':   {'price': 6500.0, 'emoji': '🌿', 'mandi': 'Rajkot, GJ'},
  'sugarcane':{'price':  350.0, 'emoji': '🎋', 'mandi': 'Muzaffarnagar, UP'},
  'mustard':  {'price': 5400.0, 'emoji': '🌼', 'mandi': 'Alwar, RJ'},
  'groundnut':{'price': 5600.0, 'emoji': '🥜', 'mandi': 'Junagadh, GJ'},
  'chilli':   {'price': 8000.0, 'emoji': '🌶️', 'mandi': 'Guntur, AP'},
  'garlic':   {'price': 4500.0, 'emoji': '🧄', 'mandi': 'Mandsaur, MP'},
  'banana':   {'price':  900.0, 'emoji': '🍌', 'mandi': 'Jalgaon, MH'},
  'mango':    {'price': 5000.0, 'emoji': '🥭', 'mandi': 'Ratnagiri, MH'},
};

class MarketService {
  static const String _cacheKey = 'market_data_cache';
  static const int _cacheTTLHours = 3;

  // Popular crops to show in trending section
  static final List<String> trendingCrops = [
    'wheat', 'rice', 'tomato', 'maize', 'onion',
    'potato', 'soybean', 'mustard',
  ];

  // ── Fetch from directmandi.com ────────────────────────────────────────────
  static Future<double?> _scrapeDirectMandi(String crop) async {
    try {
      final slug = crop.toLowerCase().replaceAll(' ', '-');
      final url = 'https://www.directmandi.com/commodities/$slug';
      final res = await http
          .get(Uri.parse(url),
              headers: {'User-Agent': 'Mozilla/5.0 (compatible; AgriVerseBot)'})
          .timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return null;
      final body = res.body;
      // Try to extract price from common patterns like ₹2,450 per quintal
      final patterns = [
        RegExp(r'₹\s*([\d,]+(?:\.\d{1,2})?)\s*/\s*quintal', caseSensitive: false),
        RegExp(r'price[^₹]*₹\s*([\d,]+)', caseSensitive: false),
        RegExp(r'([\d,]+(?:\.\d{1,2})?)\s*per\s*quintal', caseSensitive: false),
        RegExp(r'modal[^>]*?>([\d,]+(?:\.\d{1,2})?)', caseSensitive: false),
      ];
      for (final p in patterns) {
        final match = p.firstMatch(body);
        if (match != null) {
          final raw = match.group(1)?.replaceAll(',', '') ?? '';
          final price = double.tryParse(raw);
          if (price != null && price > 100 && price < 100000) return price;
        }
      }
    } catch (_) {}
    return null;
  }

  // ── Main fetch: DirectMandi → fallback to Gemini AI prediction ────────────
  static Future<MarketCropData> fetchCropMarket({
    required String cropName,
    required String location,
  }) async {
    // 1. Check cache
    final cached = await _fromCache(cropName);
    if (cached != null) return cached;

    final key = cropName.toLowerCase().trim();
    final baseline = _baselineData[key] ??
        {'price': 2000.0, 'emoji': '🌱', 'mandi': 'Local Mandi'};

    // 2. Try directmandi.com scrape
    double? scrapedPrice = await _scrapeDirectMandi(cropName);

    // 3. Use Gemini AI for market analysis + price prediction
    final aiResult = await GeminiService.getMarketAnalysis(
      crop: cropName,
      location: location,
      scrapedPrice: scrapedPrice ?? (baseline['price'] as double),
      baselinePrice: baseline['price'] as double,
    );

    final finalPrice = scrapedPrice ??
        (aiResult['predictedPrice'] as num?)?.toDouble() ??
        (baseline['price'] as double);

    final data = MarketCropData(
      cropName: cropName,
      emoji: baseline['emoji'] as String? ?? '🌱',
      pricePerQuintal: finalPrice,
      demandTrend: aiResult['demandTrend'] as String? ?? 'Medium',
      changePercent: (aiResult['changePercent'] as num?)?.toDouble() ?? 0.0,
      recommendation: aiResult['recommendation'] as String? ?? 'HOLD',
      aiAnalysis: aiResult['analysis'] as String? ?? '',
      mandi: aiResult['mandi'] as String? ?? baseline['mandi'] as String,
      fetchedAt: DateTime.now(),
    );

    await _saveToCache(data);
    return data;
  }

  // ── Fetch multiple trending crops ─────────────────────────────────────────
  static Future<List<MarketCropData>> fetchTrending({
    required String location,
  }) async {
    final results = <MarketCropData>[];
    for (final crop in trendingCrops.take(6)) {
      try {
        final cached = await _fromCache(crop);
        if (cached != null) {
          results.add(cached);
        } else {
          final b = _baselineData[crop]!;
          // Fast local data with slight random variation (avoid API hammering)
          final variation = (DateTime.now().millisecond % 7) - 3;
          final price = (b['price'] as double) * (1 + variation / 100);
          results.add(MarketCropData(
            cropName: _capitalize(crop),
            emoji: b['emoji'] as String,
            pricePerQuintal: price,
            demandTrend: ['High', 'Medium', 'Low'][DateTime.now().second % 3],
            changePercent: variation.toDouble(),
            recommendation: 'HOLD',
            aiAnalysis: '',
            mandi: b['mandi'] as String,
            fetchedAt: DateTime.now(),
          ));
        }
      } catch (_) {}
    }
    return results;
  }

  static String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  // ── Cache ─────────────────────────────────────────────────────────────────
  static Future<MarketCropData?> _fromCache(String crop) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKey);
      if (raw == null) return null;
      final Map<String, dynamic> all = jsonDecode(raw);
      final key = crop.toLowerCase().trim();
      if (!all.containsKey(key)) return null;
      final data =
          MarketCropData.fromJson(all[key] as Map<String, dynamic>);
      if (DateTime.now().difference(data.fetchedAt).inHours >= _cacheTTLHours) {
        return null;
      }
      return data;
    } catch (_) {
      return null;
    }
  }

  static Future<void> _saveToCache(MarketCropData data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKey);
      final Map<String, dynamic> all =
          raw != null ? jsonDecode(raw) : {};
      all[data.cropName.toLowerCase().trim()] = data.toJson();
      if (all.length > 30) all.remove(all.keys.first);
      await prefs.setString(_cacheKey, jsonEncode(all));
    } catch (_) {}
  }
}
