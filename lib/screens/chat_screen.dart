import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/gemini_service.dart';

class ChatScreen extends StatefulWidget {
  final String location;
  final double temp;
  final String? initialMessage;

  const ChatScreen({
    super.key,
    required this.location,
    required this.temp,
    this.initialMessage,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _ctrl = TextEditingController();
  final ScrollController _scroll = ScrollController();
  final List<Map<String, String>> _messages = [];
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _messages.add({
      'role': 'assistant',
      'text':
          'Hello! 👋 I\'m AgriVerse AI, your intelligent farming assistant.\n\nI\'m ready to help with crop diseases, weather analysis, market prices, irrigation tips, fertilizer planning, and any other farming questions you have!\n\nWhat farming problem can I help you solve today?',
    });
    // Auto-send pre-filled message if provided
    if (widget.initialMessage != null && widget.initialMessage!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _ctrl.text = widget.initialMessage!;
        _send();
      });
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _sending) return;

    setState(() {
      _messages.add({'role': 'user', 'text': text});
      _sending = true;
    });
    _ctrl.clear();
    _scrollToBottom();

    final res = await GeminiService.chatWithAI(text, widget.location, widget.temp);

    if (mounted) {
      setState(() {
        _messages.add({
          'role': 'assistant',
          'text': res['response'] ?? 'Sorry, I could not respond. Please try again.',
        });
        _sending = false;
      });
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 150), () {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0F0A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0F0A),
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white), onPressed: () => Navigator.pop(context)),
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(color: const Color(0xFF22C55E), borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.eco_rounded, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('AgriVerse AI Chat', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white)),
                Text(widget.location.length > 25 ? '${widget.location.substring(0, 25)}...' : widget.location,
                    style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF22C55E))),
              ],
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length + (_sending ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _messages.length && _sending) {
                  return _buildTypingIndicator();
                }
                final m = _messages[index];
                return _buildMessage(m['role']!, m['text']!);
              },
            ),
          ),
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildMessage(String role, String text) {
    final isUser = role == 'user';
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(color: const Color(0xFF22C55E), borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.eco_rounded, color: Colors.white, size: 16),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isUser ? const Color(0xFF22C55E) : const Color(0xFF111811),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isUser ? 16 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 16),
                ),
                border: isUser ? null : Border.all(color: const Color(0xFF1E2E1E)),
              ),
              child: Text(
                text,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: isUser ? Colors.black : Colors.white.withOpacity(0.85),
                  height: 1.6,
                  fontWeight: isUser ? FontWeight.w700 : FontWeight.w400,
                ),
              ),
            ),
          ),
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
            width: 32, height: 32,
            decoration: BoxDecoration(color: const Color(0xFF22C55E), borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.eco_rounded, color: Colors.white, size: 16),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(color: const Color(0xFF111811), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFF1E2E1E))),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('AI is thinking', style: GoogleFonts.inter(fontSize: 12, color: Colors.white54)),
                const SizedBox(width: 8),
                const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF22C55E))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.of(context).viewInsets.bottom + 16),
      decoration: const BoxDecoration(
        color: Color(0xFF0A0F0A),
        border: Border(top: BorderSide(color: Color(0xFF1A2A1A))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF111811),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF1E2E1E)),
              ),
              child: TextField(
                controller: _ctrl,
                style: GoogleFonts.inter(fontSize: 14, color: Colors.white),
                maxLines: null,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _send(),
                decoration: InputDecoration(
                  hintText: 'Ask about crops, weather, market...',
                  hintStyle: GoogleFonts.inter(fontSize: 13, color: Colors.white30),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: InputBorder.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: _send,
            child: Container(
              width: 46, height: 46,
              decoration: BoxDecoration(color: const Color(0xFF22C55E), borderRadius: BorderRadius.circular(14)),
              child: _sending
                  ? const Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.black))
                  : const Icon(Icons.send_rounded, color: Colors.black, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}
