import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../services/gemini_service.dart';
import '../services/location_service.dart';

class EmergencyScreen extends StatefulWidget {
  const EmergencyScreen({super.key});

  @override
  State<EmergencyScreen> createState() => _EmergencyScreenState();
}

class _EmergencyScreenState extends State<EmergencyScreen>
    with TickerProviderStateMixin {
  final TextEditingController _ctrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  final List<Map<String, dynamic>> _messages = [];
  bool _sending = false;
  String _location = 'your location';
  double _temp = 28.0;
  String _detectedLang = '';

  // Voice
  late stt.SpeechToText _speech;
  bool _isListening = false;
  bool _speechAvailable = false;

  // Animations
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;
  late AnimationController _dotCtrl;
  late Animation<double> _dotAnim;

  // Quick emergency prompts
  final List<Map<String, String>> _quickPrompts = [
    {'emoji': '🐛', 'label': 'Pest Attack', 'text': 'My crops are under sudden pest attack. What should I do immediately?'},
    {'emoji': '🍂', 'label': 'Leaf Disease', 'text': 'Leaves on my crop are turning yellow/brown and falling. What is this disease and how to treat it?'},
    {'emoji': '🌊', 'label': 'Flood Damage', 'text': 'My farm field is flooded. What immediate steps to save my crops?'},
    {'emoji': '🌵', 'label': 'Drought Stress', 'text': 'My crops are wilting due to heat and no rain. Urgent help needed.'},
    {'emoji': '🧪', 'label': 'Chemical Burn', 'text': 'I accidentally applied excess pesticide/fertilizer and crops are burning. Help!'},
    {'emoji': '🐂', 'label': 'Animal Attack', 'text': 'Animals/cattle have damaged my crop fields. What to do?'},
  ];

  @override
  void initState() {
    super.initState();

    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800))
      ..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.85, end: 1.0).animate(_pulseCtrl);

    _dotCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400))
      ..repeat(reverse: true);
    _dotAnim = Tween<double>(begin: 0.4, end: 1.0).animate(_dotCtrl);

    _initSpeech();
    _initLocation();

    // Welcome message
    _messages.add({
      'role': 'bot',
      'text':
          '🚨 EMERGENCY MODE ACTIVATED\n\nMai AgriVerse Emergency AI hoon. Apni fasal ki koi bhi emergency batayein — Main turant madad karunga.\n\n🌐 Main aapki bhasha mein baat kar sakta hoon.\nHindi, English, ya koi bhi regional language use karein.\n\n✅ Common emergencies ke liye neeche buttons dabayein.',
      'timestamp': DateTime.now(),
      'isBot': true,
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _scrollCtrl.dispose();
    _pulseCtrl.dispose();
    _dotCtrl.dispose();
    if (_isListening) _speech.stop();
    super.dispose();
  }

  Future<void> _initSpeech() async {
    _speech = stt.SpeechToText();
    final ok = await _speech.initialize(
      onError: (_) => setState(() => _isListening = false),
      onStatus: (s) {
        if (s == 'done' || s == 'notListening') {
          if (mounted) setState(() => _isListening = false);
        }
      },
    );
    if (mounted) setState(() => _speechAvailable = ok);
  }

  Future<void> _initLocation() async {
    final loc = await LocationService.getLocationData();
    if (mounted) {
      setState(() {
        _location = loc['location'] ?? 'your location';
        _temp = (loc['temp'] as num?)?.toDouble() ?? 28.0;
      });
    }
  }

  // ── Voice input ────────────────────────────────────────────────────────────
  Future<void> _toggleVoice() async {
    if (!_speechAvailable) {
      _showSnack('Microphone not available');
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
              _ctrl.text = result.recognizedWords;
              _ctrl.selection = TextSelection.fromPosition(
                  TextPosition(offset: _ctrl.text.length));
            });
          }
        },
        listenFor: const Duration(seconds: 15),
        pauseFor: const Duration(seconds: 4),
        partialResults: true,
      );
    }
  }

  String _detectLanguage(String text) {
    // Check for Hindi/Devanagari script
    if (RegExp(r'[\u0900-\u097F]').hasMatch(text)) return 'Hindi';
    // Check for Hinglish / common Hindi words in Latin
    final hindiWords = ['kya', 'mera', 'meri', 'fasal', 'kheti', 'kisan', 'bhai', 'aur', 'hai', 'nahi', 'hum', 'phir', 'bhi', 'karo', 'kare'];
    final lowerText = text.toLowerCase();
    if (hindiWords.any((w) => lowerText.contains(w))) return 'Hinglish (Hindi-English mix)';
    // Check for Punjabi
    if (RegExp(r'[\u0A00-\u0A7F]').hasMatch(text)) return 'Punjabi';
    // Check for Bengali
    if (RegExp(r'[\u0980-\u09FF]').hasMatch(text)) return 'Bengali';
    // Check for Tamil
    if (RegExp(r'[\u0B80-\u0BFF]').hasMatch(text)) return 'Tamil';
    // Check for Telugu
    if (RegExp(r'[\u0C00-\u0C7F]').hasMatch(text)) return 'Telugu';
    // Default
    return 'English';
  }

  // ── Send message ───────────────────────────────────────────────────────────
  Future<void> _send([String? predefined]) async {
    final text = predefined ?? _ctrl.text.trim();
    if (text.isEmpty || _sending) return;

    final lang = _detectLanguage(text);
    if (lang.isNotEmpty && lang != _detectedLang) {
      setState(() => _detectedLang = lang);
    }

    setState(() {
      _messages.add({
        'role': 'user',
        'text': text,
        'timestamp': DateTime.now(),
        'isBot': false,
        'lang': lang,
      });
      _sending = true;
    });
    _ctrl.clear();
    _scrollToBottom();

    // Build conversation history (last 4 exchanges)
    final historyLines = _messages
        .where((m) => m['role'] != 'system')
        .take(_messages.length > 8 ? 8 : _messages.length)
        .map((m) => '[${m['isBot'] == true ? 'AI' : 'Farmer'}]: ${m['text']}')
        .join('\n');

    final res = await GeminiService.emergencyChatWithAI(
      message: text,
      location: _location,
      temp: _temp,
      detectedLang: _detectedLang,
      conversationHistory: historyLines,
    );

    if (mounted) {
      setState(() {
        _messages.add({
          'role': 'bot',
          'text': res['response'] ?? 'Emergency AI unavailable. Call: 1800-180-1551',
          'timestamp': DateTime.now(),
          'isBot': true,
        });
        _sending = false;
      });
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent + 100,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.inter(fontSize: 13)),
      backgroundColor: const Color(0xFF1A0000),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0000),
      appBar: _buildAppBar(),
      body: Column(
        children: [
          // Status bar
          _buildStatusBar(),
          // Chat messages
          Expanded(
            child: ListView.builder(
              controller: _scrollCtrl,
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
              itemCount: _messages.length + (_sending ? 1 : 0),
              itemBuilder: (_, i) {
                if (i == _messages.length && _sending) {
                  return _buildTypingIndicator();
                }
                return _buildMessage(_messages[i]);
              },
            ),
          ),
          // Quick prompts
          _buildQuickPrompts(),
          // Input bar
          _buildInputBar(),
        ],
      ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: const Color(0xFF1A0000),
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      title: Row(
        children: [
          AnimatedBuilder(
            animation: _pulseAnim,
            builder: (_, __) => Transform.scale(
              scale: _pulseAnim.value,
              child: Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  color: Color(0xFFEF4444),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Emergency AI',
                  style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: Colors.white)),
              Text('Live • Multilingual',
                  style: GoogleFonts.inter(
                      fontSize: 10, color: const Color(0xFF22C55E))),
            ],
          ),
        ],
      ),
      actions: [
        // Helpline button
        TextButton.icon(
          onPressed: () => _showHelplineDialog(),
          icon: const Icon(Icons.phone_rounded,
              color: Color(0xFFEF4444), size: 16),
          label: Text('Helpline',
              style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFFEF4444))),
        ),
      ],
    );
  }

  Widget _buildStatusBar() {
    return Container(
      color: const Color(0xFF1A0000),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Row(
        children: [
          const Icon(Icons.location_on_rounded, color: Colors.white38, size: 12),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              _location,
              style: GoogleFonts.inter(fontSize: 11, color: Colors.white38),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (_detectedLang.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFF22C55E).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: const Color(0xFF22C55E).withValues(alpha: 0.3)),
              ),
              child: Text(
                '🌐 $_detectedLang',
                style: GoogleFonts.inter(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF22C55E)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMessage(Map<String, dynamic> msg) {
    final isBot = msg['isBot'] as bool? ?? false;
    final text = msg['text'] as String? ?? '';
    final time = msg['timestamp'] as DateTime?;
    final timeStr = time != null
        ? '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}'
        : '';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment:
            isBot ? MainAxisAlignment.start : MainAxisAlignment.end,
        children: [
          if (isBot) ...[
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                shape: BoxShape.circle,
                border: Border.all(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.4)),
              ),
              child: const Center(
                child: Text('🤖', style: TextStyle(fontSize: 16)),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isBot ? CrossAxisAlignment.start : CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isBot
                        ? const Color(0xFF1F0011)
                        : const Color(0xFF1C1C1C),
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(isBot ? 4 : 16),
                      bottomRight: Radius.circular(isBot ? 16 : 4),
                    ),
                    border: Border.all(
                      color: isBot
                          ? const Color(0xFFEF4444).withValues(alpha: 0.2)
                          : Colors.white12,
                    ),
                  ),
                  child: Text(
                    text,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: isBot ? Colors.white : Colors.white70,
                      height: 1.6,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  timeStr,
                  style: GoogleFonts.inter(fontSize: 9, color: Colors.white24),
                ),
              ],
            ),
          ),
          if (!isBot) ...[
            const SizedBox(width: 8),
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.white12,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white24),
              ),
              child: const Center(
                child: Icon(Icons.person_rounded,
                    color: Colors.white54, size: 18),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: const Color(0xFFEF4444).withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Center(child: Text('🤖', style: TextStyle(fontSize: 16))),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFF1F0011),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
                bottomRight: Radius.circular(16),
                bottomLeft: Radius.circular(4),
              ),
              border: Border.all(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.2)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedBuilder(
                  animation: _dotAnim,
                  builder: (_, __) => Row(
                    children: List.generate(3, (i) {
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF4444)
                              .withValues(alpha: _dotAnim.value),
                          shape: BoxShape.circle,
                        ),
                      );
                    }),
                  ),
                ),
                const SizedBox(width: 8),
                Text('AI is responding...',
                    style: GoogleFonts.inter(
                        fontSize: 11, color: Colors.white38)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickPrompts() {
    return Container(
      height: 44,
      margin: const EdgeInsets.only(bottom: 4),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: _quickPrompts.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (_, i) {
          final p = _quickPrompts[i];
          return GestureDetector(
            onTap: () => _send(p['text']),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF1A0000),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(p['emoji'] ?? '', style: const TextStyle(fontSize: 14)),
                  const SizedBox(width: 6),
                  Text(
                    p['label'] ?? '',
                    style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white70),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 20),
      decoration: const BoxDecoration(
        color: Color(0xFF1A0000),
        border: Border(top: BorderSide(color: Color(0xFF3A1010))),
      ),
      child: Row(
        children: [
          // Voice mic
          GestureDetector(
            onTap: _toggleVoice,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _isListening
                    ? const Color(0xFFEF4444)
                    : const Color(0xFFEF4444).withValues(alpha: 0.15),
                shape: BoxShape.circle,
                border: Border.all(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.4)),
              ),
              child: Icon(
                _isListening ? Icons.mic_rounded : Icons.mic_none_rounded,
                color: _isListening
                    ? Colors.white
                    : const Color(0xFFEF4444),
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Text input
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF0D0000),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.3)),
              ),
              child: TextField(
                controller: _ctrl,
                style: GoogleFonts.inter(
                    fontSize: 14, color: Colors.white),
                maxLines: 3,
                minLines: 1,
                decoration: InputDecoration(
                  hintText:
                      'Describe your emergency... (Hindi/English/Any language)',
                  hintStyle: GoogleFonts.inter(
                      fontSize: 12, color: Colors.white30),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                ),
                onSubmitted: (_) => _send(),
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Send button
          GestureDetector(
            onTap: _sending ? null : () => _send(),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _sending
                    ? Colors.red.withValues(alpha: 0.3)
                    : const Color(0xFFEF4444),
                shape: BoxShape.circle,
              ),
              child: _sending
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.send_rounded,
                      color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  void _showHelplineDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A0000),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('🆘 Emergency Helplines',
            style: GoogleFonts.inter(
                fontWeight: FontWeight.w900, color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _helplineRow('Kisan Call Center', '1800-180-1551', '🌾'),
            _helplineRow('PM Kisan Helpline', '155261', '🏛️'),
            _helplineRow('NDMA Helpline', '1078', '🚨'),
            _helplineRow('Police', '100', '👮'),
            _helplineRow('Ambulance', '108', '🏥'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close',
                style: GoogleFonts.inter(
                    color: const Color(0xFFEF4444),
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Widget _helplineRow(String name, String number, String emoji) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.white70)),
                Text(number,
                    style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFFEF4444))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
