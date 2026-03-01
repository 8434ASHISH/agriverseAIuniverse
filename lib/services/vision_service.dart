import 'dart:convert';
import 'package:http/http.dart' as http;

class VisionService {
  static const String _apiKey =
      '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';
  static const String _baseUrl = 'https://openrouter.ai/api/v1/chat/completions';

  static Future<Map<String, dynamic>> analyzeImage(String base64Image) async {
    try {
      final String mimeType = base64Image.startsWith('data:image/png')
          ? 'image/png'
          : 'image/jpeg';

      String imageData = base64Image;
      if (base64Image.contains(',')) {
        imageData = base64Image.split(',').last;
      }

      final headers = {
        'Authorization': 'Bearer $_apiKey',
        'Content-Type': 'application/json',
        'HTTP-Referer': 'https://agriverse.ai',
        'X-Title': 'AgriVerse AI',
      };

      final body = jsonEncode({
        'model': 'meta-llama/llama-3.2-11b-vision-instruct:free',
        'messages': [
          {
            'role': 'user',
            'content': [
              {
                'type': 'image_url',
                'image_url': {
                  'url': 'data:$mimeType;base64,$imageData',
                },
              },
              {
                'type': 'text',
                'text': '''You are an expert agricultural AI. Analyze this crop/farm image and provide:

1. DISEASE/PEST DETECTED: What disease, pest, or issue do you see? Be specific.
2. SEVERITY: Low / Moderate / High  
3. AFFECTED AREA: Estimate % of crop affected
4. CAUSE: What causes this problem?
5. IMMEDIATE ACTION: What to do right now (3 steps)
6. TREATMENT: Specific pesticide/fungicide/fertilizer recommendations
7. PREVENTION: How to prevent this in future
8. YIELD IMPACT: Estimated % yield loss if untreated

Format your response clearly with these exact headings. If the image is not a crop or plant, say so politely.''',
              },
            ],
          },
        ],
        'max_tokens': 1000,
      });

      final response = await http
          .post(Uri.parse(_baseUrl), headers: headers, body: body)
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content =
            data['choices']?[0]?['message']?['content'] as String? ??
                'Analysis complete. No specific issues detected.';

        return {
          'success': true,
          'analysis': content,
        };
      } else {
        final errorData = jsonDecode(response.body);
        final errorMsg = errorData['error']?['message'] ?? 'API error ${response.statusCode}';
        return {
          'success': false,
          'analysis': 'Vision analysis failed: $errorMsg. Please try again.',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'analysis':
            'Analysis failed: ${e.toString()}. Please check your internet connection and try again.',
      };
    }
  }

  static Future<Map<String, dynamic>> chatWithAI(
      String message, String location, double temp) async {
    try {
      final headers = {
        'Authorization': 'Bearer $_apiKey',
        'Content-Type': 'application/json',
        'HTTP-Referer': 'https://agriverse.ai',
        'X-Title': 'AgriVerse AI',
      };

      final body = jsonEncode({
        'model': 'meta-llama/llama-3.2-3b-instruct:free',
        'messages': [
          {
            'role': 'system',
            'content':
                'You are AgriVerse AI, an expert agricultural assistant. The farmer is located at $location with temperature ${temp.toStringAsFixed(1)}°C. Provide practical, actionable farming advice. Be concise but comprehensive.',
          },
          {
            'role': 'user',
            'content': message,
          },
        ],
        'max_tokens': 800,
      });

      final response = await http
          .post(Uri.parse(_baseUrl), headers: headers, body: body)
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content =
            data['choices']?[0]?['message']?['content'] as String? ??
                'I apologize, I could not generate a response. Please try again.';
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
}
