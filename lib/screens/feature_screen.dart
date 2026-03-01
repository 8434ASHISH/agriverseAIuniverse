import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/gemini_service.dart';
import '../services/location_service.dart';

class FeatureScreen extends StatefulWidget {
  final String title;
  final IconData icon;
  final Color iconColor;
  final String prompt;

  const FeatureScreen({
    super.key,
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.prompt,
  });

  @override
  State<FeatureScreen> createState() => _FeatureScreenState();
}

class _FeatureScreenState extends State<FeatureScreen> {
  bool _loading = true;
  String? _result;
  bool _success = false;

  @override
  void initState() {
    super.initState();
    _runAnalysis();
  }

  Future<void> _runAnalysis() async {
    setState(() { _loading = true; _result = null; });
    try {
      final locData = await LocationService.getLocationData();
      final location = locData['location'] ?? 'your location';
      final prompt = widget.prompt.contains('\$location')
          ? widget.prompt.replaceAll('\$location', location)
          : widget.prompt;

      final res = await GeminiService.chatWithAI(prompt, location, 28);
      if (mounted) {
        setState(() {
          _result = res['response'];
          _success = res['success'] == true;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _result = 'Failed to load analysis: ${e.toString()}';
          _success = false;
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0F0A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0F0A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Icon(widget.icon, color: widget.iconColor, size: 22),
            const SizedBox(width: 10),
            Text(widget.title,
                style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white)),
          ],
        ),
      ),
      body: _loading
          ? _buildLoading()
          : _buildResult(),
    );
  }

  Widget _buildLoading() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 64,
            height: 64,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: widget.iconColor,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'AgriVerse AI is analyzing...',
            style: GoogleFonts.inter(fontSize: 14, color: Colors.white70, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            widget.title,
            style: GoogleFonts.inter(fontSize: 12, color: Colors.white38),
          ),
        ],
      ),
    );
  }

  Widget _buildResult() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: widget.iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: widget.iconColor.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(widget.icon, color: widget.iconColor, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.title,
                          style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white)),
                      Text('Powered by AgriVerse AI',
                          style: GoogleFonts.inter(fontSize: 10, color: widget.iconColor)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFF111811),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF1E2E1E)),
            ),
            child: Text(
              _result ?? 'No analysis available.',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: Colors.white.withOpacity(0.85),
                height: 1.7,
              ),
            ),
          ),

          const SizedBox(height: 20),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _runAnalysis,
              icon: const Icon(Icons.refresh_rounded),
              label: Text('Regenerate Analysis',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w800)),
              style: ElevatedButton.styleFrom(
                backgroundColor: widget.iconColor,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),

          const SizedBox(height: 30),
        ],
      ),
    );
  }
}
