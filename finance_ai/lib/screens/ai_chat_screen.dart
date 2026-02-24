import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:animate_do/animate_do.dart';
import '../providers/finance_provider.dart';
import '../services/gemini_service.dart';
import '../theme/app_theme.dart';

class _ChatMessage {
  final String text;
  final bool isUser;
  final DateTime time;

  _ChatMessage({required this.text, required this.isUser, required this.time});
}

class AiChatScreen extends StatefulWidget {
  const AiChatScreen({super.key});

  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends State<AiChatScreen> {
  final List<_ChatMessage> _messages = [];
  final _ctrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  bool _isLoading = false;

  static const List<String> _quickPrompts = [
    '💡 How can I save more?',
    '📊 Analyse my spending',
    '🎯 Set a savings goal',
    '🛒 Reduce grocery costs',
    '📅 Monthly budget plan',
  ];

  @override
  void initState() {
    super.initState();
    _addAiMessage('👋 Hi! I\'m **AiLedge**, your personal finance advisor.\n\nI\'ve already reviewed your spending data. Ask me anything — I can help you save money, set budgets, or understand your spending habits!');
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _addAiMessage(String text) {
    setState(() {
      _messages.add(_ChatMessage(text: text, isUser: false, time: DateTime.now()));
    });
    _scrollToBottom();
  }

  Future<void> _send(String text) async {
    if (text.trim().isEmpty) return;
    final msg = text.trim();
    _ctrl.clear();

    setState(() {
      _messages.add(_ChatMessage(text: msg, isUser: true, time: DateTime.now()));
      _isLoading = true;
    });
    _scrollToBottom();

    try {
      final fp = context.read<FinanceProvider>();
      final response = await GeminiService.chat(msg, fp.allTransactions);
      _addAiMessage(response);
    } catch (_) {
      _addAiMessage('Sorry, I encountered an error. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent + 200,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                gradient: AppTheme.accentGradient,
                shape: BoxShape.circle,
              ),
              child: const Center(child: Text('🤖', style: TextStyle(fontSize: 18))),
            ),
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('AiLedge Advisor', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                Text('Powered by Gemini', style: TextStyle(fontSize: 11, color: AppTheme.accent)),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              GeminiService.resetChat();
              setState(() => _messages.clear());
              _addAiMessage('🔄 Chat reset! How can I help you with your finances?');
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Quick prompts
          if (_messages.length <= 1)
            SizedBox(
              height: 48,
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                scrollDirection: Axis.horizontal,
                itemCount: _quickPrompts.length,
                itemBuilder: (_, i) => GestureDetector(
                  onTap: () => _send(_quickPrompts[i]),
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceCard,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppTheme.accent.withOpacity(0.4)),
                    ),
                    child: Text(_quickPrompts[i], style: const TextStyle(color: AppTheme.accent, fontSize: 12, fontWeight: FontWeight.w500)),
                  ),
                ),
              ),
            ),

          const Divider(color: AppTheme.border, height: 1),

          // Messages
          Expanded(
            child: ListView.builder(
              controller: _scrollCtrl,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length + (_isLoading ? 1 : 0),
              itemBuilder: (_, i) {
                if (i == _messages.length && _isLoading) {
                  return const _TypingIndicator();
                }
                final msg = _messages[i];
                return FadeInUp(
                  duration: const Duration(milliseconds: 300),
                  child: _MessageBubble(message: msg),
                );
              },
            ),
          ),

          // Input
          Container(
            padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
            decoration: const BoxDecoration(
              color: AppTheme.surface,
              border: Border(top: BorderSide(color: AppTheme.border)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _ctrl,
                    style: const TextStyle(color: AppTheme.textPrimary),
                    maxLines: 3,
                    minLines: 1,
                    onSubmitted: _send,
                    decoration: InputDecoration(
                      hintText: 'Ask about your finances...',
                      filled: true,
                      fillColor: AppTheme.surfaceCard,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: const BorderSide(color: AppTheme.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: const BorderSide(color: AppTheme.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: const BorderSide(color: AppTheme.accent, width: 1.5),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: () => _send(_ctrl.text),
                  child: Container(
                    width: 48, height: 48,
                    decoration: const BoxDecoration(
                      gradient: AppTheme.accentGradient,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.send_rounded, color: Colors.black, size: 20),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final _ChatMessage message;
  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              width: 32, height: 32,
              decoration: const BoxDecoration(gradient: AppTheme.accentGradient, shape: BoxShape.circle),
              child: const Center(child: Text('🤖', style: TextStyle(fontSize: 16))),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isUser ? AppTheme.accent.withOpacity(0.2) : AppTheme.surfaceCard,
                borderRadius: BorderRadius.only(
                  topLeft:     const Radius.circular(18),
                  topRight:    const Radius.circular(18),
                  bottomLeft:  Radius.circular(isUser ? 18 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 18),
                ),
                border: Border.all(
                  color: isUser ? AppTheme.accent.withOpacity(0.3) : AppTheme.border,
                ),
              ),
              child: _buildText(message.text),
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 8),
            const CircleAvatar(
              radius: 16,
              backgroundColor: AppTheme.surface,
              child: Text('👤', style: TextStyle(fontSize: 14)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildText(String text) {
    // Simple markdown-ish rendering for bold
    final parts = text.split('**');
    final spans = <TextSpan>[];
    for (int i = 0; i < parts.length; i++) {
      spans.add(TextSpan(
        text: parts[i],
        style: TextStyle(
          color: AppTheme.textPrimary,
          fontWeight: i.isOdd ? FontWeight.w700 : FontWeight.normal,
          fontSize: 14,
          height: 1.5,
        ),
      ));
    }
    return RichText(text: TextSpan(children: spans));
  }
}

class _TypingIndicator extends StatefulWidget {
  const _TypingIndicator();

  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600))..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.4, end: 1.0).animate(_ctrl);
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            width: 32, height: 32,
            decoration: const BoxDecoration(gradient: AppTheme.accentGradient, shape: BoxShape.circle),
            child: const Center(child: Text('🤖', style: TextStyle(fontSize: 16))),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.surfaceCard,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18), topRight: Radius.circular(18), bottomRight: Radius.circular(18),
              ),
              border: Border.all(color: AppTheme.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (i) => FadeTransition(
                opacity: _anim,
                child: Container(
                  margin: EdgeInsets.only(right: i < 2 ? 4 : 0),
                  width: 6, height: 6,
                  decoration: const BoxDecoration(color: AppTheme.accent, shape: BoxShape.circle),
                ),
              )),
            ),
          ),
        ],
      ),
    );
  }
}
