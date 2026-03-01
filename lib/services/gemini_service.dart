import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class GeminiService {
  static String get _apiKey => dotenv.env['GEMINI_API_KEY'] ?? '';
  static const String _baseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models';

  // ─── Pest & Disease Detection (Vision - image analysis) ───────────────────
  static Future<Map<String, dynamic>> analyzeImage(String base64Image) async {
    try {
      String imageData = base64Image;
      String mimeType = 'image/jpeg';

      if (base64Image.contains(',')) {
        final parts = base64Image.split(',');
        imageData = parts.last;
        if (parts.first.contains('png')) mimeType = 'image/png';
      }

      final url =
          '$_baseUrl/gemini-1.5-flash:generateContent?key=$_apiKey';

      final body = jsonEncode({
        'contents': [
          {
            'parts': [
              {
                'inline_data': {
                  'mime_type': mimeType,
                  'data': imageData,
                }
              },
              {
                'text': '''You are an expert agricultural AI assistant powered by Gemini. 
Analyze this crop/plant image and return a structured JSON response ONLY (no markdown, no extra text).

Return this exact JSON:
{
  "disease_name": "Name of disease or pest (e.g. Early Blight, Aphid Infestation)",
  "scientific_name": "Scientific name if applicable",
  "confidence": 94.2,
  "description": "2-3 sentence description of the disease/pest and what causes it",
  "risk_level": "Low|Medium|High|Critical",
  "cost_impact": "Low|Medium|High",
  "affected_percentage": 35,
  "immediate_actions": [
    {"title": "Action title", "description": "Detailed description"},
    {"title": "Action title", "description": "Detailed description"},
    {"title": "Action title", "description": "Detailed description"}
  ],
  "treatment_products": [
    {"name": "Product name", "type": "Fungicide|Pesticide|Organic|Fertilizer", "dosage": "dosage info", "price_range": "₹X-Y per litre"},
    {"name": "Product name", "type": "Fungicide|Pesticide|Organic|Fertilizer", "dosage": "dosage info", "price_range": "₹X-Y per litre"},
    {"name": "Product name", "type": "Fungicide|Pesticide|Organic|Fertilizer", "dosage": "dosage info", "price_range": "₹X-Y per litre"}
  ],
  "prevention": "How to prevent this in future (2-3 sentences)",
  "yield_impact": "Estimated yield loss if untreated"
}

If the image is not a crop or plant, return:
{
  "disease_name": "Not a crop image",
  "scientific_name": "",
  "confidence": 0,
  "description": "The image does not appear to show a plant or crop. Please upload a clear photo of your crop.",
  "risk_level": "Low",
  "cost_impact": "Low",
  "affected_percentage": 0,
  "immediate_actions": [],
  "treatment_products": [],
  "prevention": "",
  "yield_impact": ""
}'''
              }
            ]
          }
        ],
        'generationConfig': {
          'temperature': 0.2,
          'maxOutputTokens': 1500,
        }
      });

      final response = await http
          .post(
            Uri.parse(url),
            headers: {'Content-Type': 'application/json'},
            body: body,
          )
          .timeout(const Duration(seconds: 45));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content =
            data['candidates']?[0]?['content']?['parts']?[0]?['text'] as String? ?? '';

        // Parse the JSON from Gemini's response
        try {
          // Clean the response - extract JSON if wrapped in markdown
          String cleanJson = content.trim();
          if (cleanJson.startsWith('```')) {
            cleanJson = cleanJson
                .replaceAll(RegExp(r'```json\s*'), '')
                .replaceAll(RegExp(r'```\s*'), '')
                .trim();
          }
          final analysisData = jsonDecode(cleanJson) as Map<String, dynamic>;
          return {
            'success': true,
            'data': analysisData,
          };
        } catch (_) {
          return {
            'success': false,
            'error': 'Could not parse AI response. Please try again.',
          };
        }
      } else {
        final errorBody = response.body;
        return {
          'success': false,
          'error': 'API error ${response.statusCode}: $errorBody',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Analysis failed: ${e.toString()}',
      };
    }
  }

  // ─── Chat with AI (for ChatScreen & FeatureScreen) ────────────────────────
  static Future<Map<String, dynamic>> chatWithAI(
      String message, String location, double temp) async {
    try {
      final url =
          '$_baseUrl/gemini-1.5-flash:generateContent?key=$_apiKey';

      final body = jsonEncode({
        'contents': [
          {
            'parts': [
              {
                'text':
                    'You are AgriVerse AI, an expert agricultural assistant. The farmer is located at $location with temperature ${temp.toStringAsFixed(1)}°C. Provide practical, actionable farming advice. Be concise but comprehensive.\n\nFarmer\'s question: $message'
              }
            ]
          }
        ],
        'generationConfig': {
          'temperature': 0.7,
          'maxOutputTokens': 800,
        }
      });

      final response = await http
          .post(
            Uri.parse(url),
            headers: {'Content-Type': 'application/json'},
            body: body,
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content =
            data['candidates']?[0]?['content']?['parts']?[0]?['text'] as String? ??
                'I could not generate a response. Please try again.';
        return {'success': true, 'response': content};
      } else {
        return {
          'success': false,
          'response': 'Failed to get AI response. Please try again.',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'response': 'Connection error: ${e.toString()}',
      };
    }
  }
  // ─── Fertilizer Planner ────────────────────────────────────────────────────
  static Future<dynamic> getFertilizerPlan({
    required String crop,
    required double areaInAcres,
    required String unitName,
    required String location,
  }) async {
    // Import is resolved by the caller (fertilizer_planner_screen.dart)
    final url = '$_baseUrl/gemini-1.5-flash:generateContent?key=$_apiKey';

    final totalArea = areaInAcres;

    final body = jsonEncode({
      'contents': [
        {
          'parts': [
            {
              'text': '''You are an expert agronomist AI for Indian farmers. Create a complete fertilizer plan and return ONLY valid JSON (no markdown, no extra text).

Crop: $crop
Area: ${totalArea.toStringAsFixed(2)} Acres (entered as: $unitName)
Location: $location

Return this exact JSON structure:
{
  "mixture": "NPK formula string e.g. NPK 10-26-26 + Urea",
  "totalAmount": "e.g. 150 kg / Acre",
  "whenToApply": "e.g. Within 48 Hours",
  "actionSteps": [
    "Step 1 description (practical, specific)",
    "Step 2 description",
    "Step 3 description"
  ],
  "safetyWarning": "Important safety caution for this fertilizer mix",
  "estimatedCostPerAcre": 1250.50,
  "yieldIncrease": 18.5,
  "imagePrompt": "a healthy $crop field with green crops"
}

Rules:
- estimatedCostPerAcre must be a realistic number in Indian Rupees (₹)
- yieldIncrease should be realistic percentage (5-35%)
- actionSteps should have 3 practical steps
- Tailor everything specifically for $crop grown in India
- Consider current season (March 2026)'''
            }
          ]
        }
      ],
      'generationConfig': {
        'temperature': 0.3,
        'maxOutputTokens': 800,
      }
    });

    final response = await http
        .post(
          Uri.parse(url),
          headers: {'Content-Type': 'application/json'},
          body: body,
        )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode != 200) {
      throw Exception('Gemini API error: ${response.statusCode}');
    }

    final data = jsonDecode(response.body);
    String text =
        data['candidates']?[0]?['content']?['parts']?[0]?['text'] as String? ??
            '';
    text = text.trim()
        .replaceAll(RegExp(r'```json\s*'), '')
        .replaceAll(RegExp(r'```\s*'), '')
        .trim();

    final json = jsonDecode(text) as Map<String, dynamic>;

    // Import FertPlan from the screen file is not possible here,
    // so we return raw map and let the screen construct the model.
    return json;
  }

  // ─── Emergency multilingual chat ───────────────────────────────────────────
  static Future<Map<String, dynamic>> emergencyChatWithAI({
    required String message,
    required String location,
    required double temp,
    required String detectedLang,
    required String conversationHistory,
  }) async {
    try {
      final url = '$_baseUrl/gemini-1.5-flash:generateContent?key=$_apiKey';

      final langInstruction = detectedLang.isNotEmpty
          ? 'IMPORTANT: The farmer appears to be communicating in $detectedLang. Respond in the SAME language ($detectedLang) as the farmer.'
          : 'Respond in the same language the farmer used.';

      final body = jsonEncode({
        'contents': [
          {
            'parts': [
              {
                'text': '''You are AgriVerse Emergency AI Assistant. $langInstruction

Location: $location | Temperature: ${temp.toStringAsFixed(0)}°C
Previous conversation:
$conversationHistory

Farmer's current message: "$message"

Respond with IMMEDIATE, ACTIONABLE emergency advice. Be empathetic. Keep response concise (3-5 sentences max). If the situation is life-threatening, clearly say so and advise calling emergency services.'''
              }
            ]
          }
        ],
        'generationConfig': {
          'temperature': 0.5,
          'maxOutputTokens': 500,
        }
      });

      final res = await http
          .post(
            Uri.parse(url),
            headers: {'Content-Type': 'application/json'},
            body: body,
          )
          .timeout(const Duration(seconds: 25));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final content =
            data['candidates']?[0]?['content']?['parts']?[0]?['text'] as String? ??
                'Emergency AI is temporarily unavailable.';
        return {'success': true, 'response': content};
      }
      return {
        'success': false,
        'response': 'Emergency AI unavailable. Please call your local Kisan Call Center: 1800-180-1551'
      };
    } catch (e) {
      return {
        'success': false,
        'response': 'Connection error. Kisan Helpline: 1800-180-1551'
      };
    }
  }

  // ─── Crop Growth Plan (Update #5) ─────────────────────────────────────────
  static Future<Map<String, dynamic>> getCropGrowthPlan({
    required String crop,
    required String soilType,
    required String season,
    required String location,
  }) async {
    final url = '$_baseUrl/gemini-1.5-flash:generateContent?key=$_apiKey';
    final body = jsonEncode({
      'contents': [
        {
          'parts': [
            {
              'text': '''You are an expert agronomist for Indian farmers. Create a crop growth suitability plan. Return ONLY valid JSON, no markdown.

Crop: $crop
Soil Type: $soilType
Season: $season
Location: $location

Return exactly this JSON:
{
  "suitabilityScore": 82,
  "tempRange": "20-30°C",
  "waterNeeds": "Medium",
  "harvestDays": "90 Days",
  "actionableAdvice": [
    "Ensure soil pH is maintained between 6.0 and 6.8 for optimal nutrient absorption.",
    "Implement mulching to retain moisture during drier transition phases.",
    "Initial investment estimated at approximately ₹4,500 per acre for high-yield seeds.",
    "Schedule preventive organic pesticide spraying every 15 days."
  ],
  "aiSummary": "2-3 sentence overall suitability summary for $crop in $soilType soil during $season season in $location."
}

Rules:
- suitabilityScore: realistic 40-95 based on actual crop-soil-season compatibility
- All values must be tailored specifically for $crop, $soilType, $season in India
- actionableAdvice: exactly 4 items, specific and practical'''
            }
          ]
        }
      ],
      'generationConfig': {'temperature': 0.3, 'maxOutputTokens': 700}
    });

    final res = await http
        .post(Uri.parse(url), headers: {'Content-Type': 'application/json'}, body: body)
        .timeout(const Duration(seconds: 30));
    if (res.statusCode != 200) throw Exception('Gemini API ${res.statusCode}');
    final data = jsonDecode(res.body);
    String text = data['candidates']?[0]?['content']?['parts']?[0]?['text'] as String? ?? '{}';
    text = text.trim().replaceAll(RegExp(r'```json\s*'), '').replaceAll(RegExp(r'```\s*'), '').trim();
    return jsonDecode(text) as Map<String, dynamic>;
  }

  // ─── Market Analysis (Update #6) ─────────────────────────────────────────
  static Future<Map<String, dynamic>> getMarketAnalysis({
    required String crop,
    required String location,
    required double scrapedPrice,
    required double baselinePrice,
  }) async {
    final url = '$_baseUrl/gemini-1.5-flash:generateContent?key=$_apiKey';
    final body = jsonEncode({
      'contents': [
        {
          'parts': [
            {
              'text': '''You are an Indian agricultural market analyst. Analyze current market conditions. Return ONLY valid JSON, no markdown.

Crop: $crop
Location: $location
Current Price Data: ₹${scrapedPrice.toStringAsFixed(0)}/quintal
Baseline MSP: ₹${baselinePrice.toStringAsFixed(0)}/quintal
Date: March 2026

Return exactly this JSON:
{
  "predictedPrice": ${scrapedPrice.toStringAsFixed(0)},
  "demandTrend": "High",
  "changePercent": 3.2,
  "recommendation": "SELL NOW",
  "analysis": "2-3 sentence analysis of why to sell/hold/wait, including specific market factors for $crop right now.",
  "mandi": "Best mandi name for $crop in $location region"
}

Rules:
- recommendation must be one of: "SELL NOW", "HOLD", "WAIT"
- demandTrend must be one of: "High", "Medium", "Low"
- changePercent is week-over-week % change (positive or negative)
- analysis should mention seasonal factors, supply/demand, and price trends'''
            }
          ]
        }
      ],
      'generationConfig': {'temperature': 0.4, 'maxOutputTokens': 400}
    });

    final res = await http
        .post(Uri.parse(url), headers: {'Content-Type': 'application/json'}, body: body)
        .timeout(const Duration(seconds: 20));
    if (res.statusCode != 200) {
      return {
        'predictedPrice': scrapedPrice,
        'demandTrend': 'Medium',
        'changePercent': 0.0,
        'recommendation': 'HOLD',
        'analysis': 'Market analysis temporarily unavailable.',
        'mandi': location,
      };
    }
    final data = jsonDecode(res.body);
    String text = data['candidates']?[0]?['content']?['parts']?[0]?['text'] as String? ?? '{}';
    text = text.trim().replaceAll(RegExp(r'```json\s*'), '').replaceAll(RegExp(r'```\s*'), '').trim();
    try {
      return jsonDecode(text) as Map<String, dynamic>;
    } catch (_) {
      return {'predictedPrice': scrapedPrice, 'demandTrend': 'Medium', 'changePercent': 0.0, 'recommendation': 'HOLD', 'analysis': '', 'mandi': location};
    }
  }

}

