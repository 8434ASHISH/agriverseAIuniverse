import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../services/gemini_service.dart';

class VisionScannerScreen extends StatefulWidget {
  const VisionScannerScreen({super.key});

  @override
  State<VisionScannerScreen> createState() => _VisionScannerScreenState();
}

class _VisionScannerScreenState extends State<VisionScannerScreen>
    with SingleTickerProviderStateMixin {
  File? _selectedImage;
  String? _base64Image;
  bool _analyzing = false;
  Map<String, dynamic>? _analysisData;
  bool _resultSuccess = false;
  bool _showTreatmentProducts = false;
  final ImagePicker _picker = ImagePicker();
  late AnimationController _scanController;
  late Animation<double> _scanAnim;

  @override
  void initState() {
    super.initState();
    _scanController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _scanAnim = Tween<double>(begin: 0, end: 1).animate(_scanController);
  }

  @override
  void dispose() {
    _scanController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? file = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (file != null) {
        final bytes = await file.readAsBytes();
        final base64 = 'data:image/jpeg;base64,${_encodeBase64(bytes)}';
        setState(() {
          _selectedImage = File(file.path);
          _base64Image = base64;
          _analysisData = null;
          _showTreatmentProducts = false;
        });
      }
    } catch (e) {
      _showError('Could not access image: ${e.toString()}');
    }
  }

  String _encodeBase64(List<int> bytes) {
    const String chars =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
    final StringBuffer result = StringBuffer();
    int i = 0;
    while (i < bytes.length) {
      int b0 = bytes[i++];
      int b1 = i < bytes.length ? bytes[i++] : 0;
      int b2 = i < bytes.length ? bytes[i++] : 0;
      result.write(chars[(b0 >> 2) & 0x3F]);
      result.write(chars[((b0 << 4) | (b1 >> 4)) & 0x3F]);
      result.write(chars[((b1 << 2) | (b2 >> 6)) & 0x3F]);
      result.write(chars[b2 & 0x3F]);
    }
    final int padding = (3 - bytes.length % 3) % 3;
    final String s = result.toString();
    if (padding == 1) return '${s.substring(0, s.length - 1)}=';
    if (padding == 2) return '${s.substring(0, s.length - 2)}==';
    return s;
  }

  Future<void> _analyze() async {
    if (_base64Image == null) return;
    setState(() {
      _analyzing = true;
      _analysisData = null;
      _showTreatmentProducts = false;
    });
    final res = await GeminiService.analyzeImage(_base64Image!);
    if (mounted) {
      setState(() {
        _analyzing = false;
        _resultSuccess = res['success'] == true;
        _analysisData =
            _resultSuccess ? res['data'] as Map<String, dynamic>? : null;
        if (!_resultSuccess) {
          _showError(res['error'] ?? 'Analysis failed. Please try again.');
        }
      });
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg,
          style: GoogleFonts.inter(fontSize: 13, color: Colors.white)),
      backgroundColor: const Color(0xFF991B1B),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  Color _getRiskColor(String? risk) {
    switch (risk?.toLowerCase()) {
      case 'low':
        return const Color(0xFF22C55E);
      case 'medium':
        return const Color(0xFFF59E0B);
      case 'high':
        return const Color(0xFFEF4444);
      case 'critical':
        return const Color(0xFF7C3AED);
      default:
        return const Color(0xFF6B7280);
    }
  }

  Color _getCostColor(String? cost) {
    switch (cost?.toLowerCase()) {
      case 'low':
        return const Color(0xFF22C55E);
      case 'medium':
        return const Color(0xFFF59E0B);
      case 'high':
        return const Color(0xFFEF4444);
      default:
        return const Color(0xFF6B7280);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded,
              color: Colors.black87, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Pest & Disease Detection',
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: Colors.black87,
          ),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16, top: 10, bottom: 10),
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.black87,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.info_outline_rounded,
                color: Colors.white, size: 18),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Image Area ───────────────────────────────────────────────
            _buildImageArea(),

            // ── Scan Controls ────────────────────────────────────────────
            if (_selectedImage == null) _buildPickButtons(),

            // ── Analyzing Indicator ──────────────────────────────────────
            if (_analyzing) _buildAnalyzingIndicator(),

            // ── Results ──────────────────────────────────────────────────
            if (_analysisData != null && !_analyzing)
              _buildResultSection(_analysisData!),

            // ── Analyze Button (when image selected, not yet analyzed) ───
            if (_selectedImage != null && _analysisData == null && !_analyzing)
              _buildAnalyzeButton(),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildImageArea() {
    return GestureDetector(
      onTap: _analysisData == null ? _showImageSourceDialog : null,
      child: Container(
        width: double.infinity,
        height: 260,
        decoration: const BoxDecoration(color: Colors.black),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (_selectedImage != null)
              Image.file(_selectedImage!, fit: BoxFit.cover)
            else
              _buildNoImagePlaceholder(),

            // Scanning line animation when analyzing
            if (_analyzing && _selectedImage != null)
              Container(
                color: Colors.black54,
                child: AnimatedBuilder(
                  animation: _scanAnim,
                  builder: (_, __) => Align(
                    alignment: Alignment(0, (_scanAnim.value * 2) - 1),
                    child: Container(
                      height: 3,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [
                          Colors.transparent,
                          const Color(0xFF22C55E),
                          Colors.transparent,
                        ]),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF22C55E).withOpacity(0.6),
                            blurRadius: 8,
                          )
                        ],
                      ),
                    ),
                  ),
                ),
              ),

            // "IMAGE ANALYZED BY GEMINI" badge at bottom
            if (_analysisData != null)
              Positioned(
                bottom: 12,
                left: 16,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.75),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Color(0xFF22C55E),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'IMAGE ANALYZED BY GEMINI',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Camera icon top-right
            if (_selectedImage != null)
              Positioned(
                top: 12,
                right: 12,
                child: GestureDetector(
                  onTap: _showImageSourceDialog,
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: const Color(0xFF22C55E),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.camera_alt_rounded,
                        color: Colors.white, size: 20),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoImagePlaceholder() {
    return Container(
      color: const Color(0xFF111811),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: const Color(0xFF22C55E).withOpacity(0.15),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                  color: const Color(0xFF22C55E).withOpacity(0.3), width: 2),
            ),
            child: const Icon(Icons.camera_alt_rounded,
                color: Color(0xFF22C55E), size: 34),
          ),
          const SizedBox(height: 14),
          Text(
            'Tap to scan your crop',
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Camera or Gallery',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: Colors.white38,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPickButtons() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Row(
        children: [
          Expanded(
            child: _actionBtn(
              label: 'Camera',
              icon: Icons.camera_alt_rounded,
              onTap: () => _pickImage(ImageSource.camera),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _actionBtn(
              label: 'Upload Photo',
              icon: Icons.photo_library_rounded,
              onTap: () => _pickImage(ImageSource.gallery),
              outlined: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyzingIndicator() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FFF4),
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: const Color(0xFF22C55E).withOpacity(0.3)),
      ),
      child: Column(
        children: [
          const SizedBox(
            width: 46,
            height: 46,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: Color(0xFF22C55E),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Gemini AI is analyzing your crop...',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF166534),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Detecting pests, diseases & nutrient issues',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: const Color(0xFF16A34A),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyzeButton() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _analyze,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF22C55E),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            elevation: 0,
          ),
          child: Text(
            'Analyze with AI Vision',
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w800,
              fontSize: 15,
              color: Colors.black,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResultSection(Map<String, dynamic> data) {
    final diseaseName = data['disease_name'] as String? ?? 'Unknown';
    final scientificName = data['scientific_name'] as String? ?? '';
    final confidence = (data['confidence'] as num?)?.toDouble() ?? 0.0;
    final description = data['description'] as String? ?? '';
    final riskLevel = data['risk_level'] as String? ?? 'Unknown';
    final costImpact = data['cost_impact'] as String? ?? 'Unknown';
    final actions = (data['immediate_actions'] as List<dynamic>?) ?? [];
    final products = (data['treatment_products'] as List<dynamic>?) ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Disease Name Card ─────────────────────────────────────────
        Container(
          margin: const EdgeInsets.fromLTRB(16, 20, 16, 0),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 12,
                offset: const Offset(0, 2),
              )
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FFF4),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.biotech_rounded,
                        color: Color(0xFF22C55E), size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Possible $diseaseName',
                          style: GoogleFonts.inter(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: Colors.black87,
                            height: 1.2,
                          ),
                        ),
                        if (scientificName.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            scientificName,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                              color: Colors.black45,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                description,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: Colors.black54,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 16),

              // Confidence + View Full Report
              Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'CONFIDENCE',
                        style: GoogleFonts.inter(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: Colors.black38,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${confidence.toStringAsFixed(1)}%',
                        style: GoogleFonts.inter(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF22C55E),
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () {
                      setState(
                          () => _showTreatmentProducts = !_showTreatmentProducts);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF22C55E),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'View Full Report',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(Icons.open_in_new_rounded,
                              color: Colors.white, size: 14),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // ── Risk Level + Cost Impact ───────────────────────────────────
        Container(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 12,
                offset: const Offset(0, 2),
              )
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'RISK LEVEL',
                      style: GoogleFonts.inter(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: Colors.black38,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Text(
                          riskLevel,
                          style: GoogleFonts.inter(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: _getRiskColor(riskLevel),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(
                          riskLevel.toLowerCase() == 'low'
                              ? Icons.check_circle_rounded
                              : riskLevel.toLowerCase() == 'critical'
                                  ? Icons.dangerous_rounded
                                  : Icons.warning_amber_rounded,
                          color: _getRiskColor(riskLevel),
                          size: 20,
                        ),
                      ],
                    ),
                    Container(
                      height: 3,
                      width: 60,
                      decoration: BoxDecoration(
                        color: _getRiskColor(riskLevel),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 1,
                height: 60,
                color: Colors.black12,
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'COST IMPACT',
                        style: GoogleFonts.inter(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: Colors.black38,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Text(
                            costImpact,
                            style: GoogleFonts.inter(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: _getCostColor(costImpact),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Icon(Icons.monetization_on_rounded,
                              color: _getCostColor(costImpact), size: 20),
                        ],
                      ),
                      Container(
                        height: 3,
                        width: 60,
                        decoration: BoxDecoration(
                          color: _getCostColor(costImpact),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        // ── Actionable Advice ──────────────────────────────────────────
        if (actions.isNotEmpty)
          Container(
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FFF4),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.eco_rounded,
                        color: Color(0xFF16A34A), size: 22),
                    const SizedBox(width: 8),
                    Text(
                      'Actionable Advice',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                ...actions.map((action) {
                  final a = action as Map<String, dynamic>;
                  return _buildActionItem(
                    a['title'] as String? ?? '',
                    a['description'] as String? ?? '',
                  );
                }),
              ],
            ),
          ),

        // ── Treatment Products (shown on demand) ──────────────────────
        if (_showTreatmentProducts && products.isNotEmpty)
          Container(
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 12,
                  offset: const Offset(0, 2),
                )
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FFF4),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.medical_services_rounded,
                          color: Color(0xFF22C55E), size: 20),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Treatment Products',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                ...products.map((p) {
                  final product = p as Map<String, dynamic>;
                  return _buildProductCard(product);
                }),
              ],
            ),
          ),

        // ── Re-scan option ──────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                setState(() {
                  _selectedImage = null;
                  _base64Image = null;
                  _analysisData = null;
                  _showTreatmentProducts = false;
                });
              },
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: Text('Scan Another Crop',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF22C55E),
                side: const BorderSide(color: Color(0xFF22C55E), width: 1.5),
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ),

        // ── Find Treatment Products Button ─────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                setState(() => _showTreatmentProducts = !_showTreatmentProducts);
                // Scroll to show products
              },
              icon: const Icon(Icons.local_pharmacy_rounded,
                  color: Colors.black, size: 20),
              label: Text(
                _showTreatmentProducts
                    ? 'Hide Treatment Products'
                    : 'Find Treatment Products',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                  color: Colors.black,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF22C55E),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionItem(String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: const Color(0xFF22C55E).withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_rounded,
                color: Color(0xFF22C55E), size: 17),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  description,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.black54,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductCard(Map<String, dynamic> product) {
    final name = product['name'] as String? ?? 'Unknown Product';
    final type = product['type'] as String? ?? 'Treatment';
    final dosage = product['dosage'] as String? ?? '';
    final priceRange = product['price_range'] as String? ?? '';

    Color typeColor;
    switch (type.toLowerCase()) {
      case 'fungicide':
        typeColor = const Color(0xFF7C3AED);
        break;
      case 'pesticide':
        typeColor = const Color(0xFFEF4444);
        break;
      case 'organic':
        typeColor = const Color(0xFF22C55E);
        break;
      default:
        typeColor = const Color(0xFF3B82F6);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black.withOpacity(0.06)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: typeColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.science_rounded, color: typeColor, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: typeColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        type,
                        style: GoogleFonts.inter(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: typeColor,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
                if (dosage.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Dosage: $dosage',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Colors.black54,
                    ),
                  ),
                ],
                if (priceRange.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    priceRange,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF22C55E),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: Colors.black12,
                    borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            Text('Select Image Source',
                style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: Colors.black87)),
            const SizedBox(height: 6),
            Text(
              'Take a clear photo of an affected leaf or crop',
              style: GoogleFonts.inter(fontSize: 12, color: Colors.black45),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                    child: _actionBtn(
                        label: 'Camera',
                        icon: Icons.camera_alt_rounded,
                        onTap: () {
                          Navigator.pop(context);
                          _pickImage(ImageSource.camera);
                        })),
                const SizedBox(width: 12),
                Expanded(
                    child: _actionBtn(
                        label: 'Gallery',
                        icon: Icons.photo_library_rounded,
                        outlined: true,
                        onTap: () {
                          Navigator.pop(context);
                          _pickImage(ImageSource.gallery);
                        })),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _actionBtn({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
    bool outlined = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: outlined ? Colors.white : const Color(0xFF22C55E),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: outlined ? const Color(0xFFE5E7EB) : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                color: outlined ? Colors.black54 : Colors.black, size: 18),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w800,
                color: outlined ? Colors.black87 : Colors.black,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
