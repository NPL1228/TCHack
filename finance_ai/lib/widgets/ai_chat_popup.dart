import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/finance_provider.dart';
import '../services/gemini_service.dart';
import '../theme/app_theme.dart';

// ──────────────────────────────────────────────────────────────
// Public AiLedge Chat Popup – call via showAiChat(context)
// ──────────────────────────────────────────────────────────────

void showAiChat(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const AiChatPopup(),
  );
}

class AiChatPopup extends StatefulWidget {
  const AiChatPopup({super.key});
  @override
  State<AiChatPopup> createState() => _AiChatPopupState();
}

class _AiChatPopupState extends State<AiChatPopup> {
  final List<_ChatMsg> _messages = [];
  final _ctrl       = TextEditingController();
  final _scrollCtrl = ScrollController();
  bool _isLoading   = false;

  static const List<String> _quickPrompts = [
    '💡 How to save more?',
    '📊 Analyse my spending',
    '🛒 Reduce grocery costs',
    '📅 Monthly budget plan',
  ];

  @override
  void initState() {
    super.initState();
    _addAiMessage('👋 Hi! I\'m **AiLedge**. Ask me anything about your finances!');
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _addAiMessage(String text) {
    setState(() => _messages.add(_ChatMsg(text: text, isUser: false)));
    _scrollToBottom();
  }

  Future<void> _send(String text) async {
    if (text.trim().isEmpty) return;
    final msg = text.trim();
    _ctrl.clear();
    setState(() {
      _messages.add(_ChatMsg(text: msg, isUser: true));
      _isLoading = true;
    });
    _scrollToBottom();
    try {
      final fp       = context.read<FinanceProvider>();
      final response = await GeminiService.chat(msg, fp.allTransactions);
      _addAiMessage(response);
    } catch (_) {
      _addAiMessage('Sorry, something went wrong.');
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
    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.35,
      maxChildSize: 0.95,
      snap: true,
      snapSizes: const [0.35, 0.55, 0.95],
      builder: (ctx, _) => Container(
        decoration: const BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [BoxShadow(color: Colors.black45, blurRadius: 20)],
        ),
        child: Column(
          children: [
            // ─ Header ─
            Column(
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(color: AppTheme.border, borderRadius: BorderRadius.circular(2)),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 8, 6),
                  child: Row(
                    children: [
                      Container(
                        width: 32, height: 32,
                        decoration: const BoxDecoration(gradient: AppTheme.accentGradient, shape: BoxShape.circle),
                        child: const Center(child: Text('🤖', style: TextStyle(fontSize: 16))),
                      ),
                      const SizedBox(width: 10),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('AiLedge Advisor', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700, fontSize: 14)),
                          Text('Powered by Gemini', style: TextStyle(color: AppTheme.accent, fontSize: 10)),
                        ],
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.refresh_rounded, color: AppTheme.textMuted, size: 20),
                        onPressed: () {
                          GeminiService.resetChat();
                          setState(() => _messages.clear());
                          _addAiMessage('🔄 Chat reset! How can I help?');
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: AppTheme.textMuted, size: 20),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                const Divider(color: AppTheme.border, height: 1),
              ],
            ),

            // ─ Quick prompts ─
            if (_messages.length <= 1)
              SizedBox(
                height: 44,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  itemCount: _quickPrompts.length,
                  itemBuilder: (_, i) => GestureDetector(
                    onTap: () => _send(_quickPrompts[i]),
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceCard,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppTheme.accent.withValues(alpha: 0.4)),
                      ),
                      child: Text(_quickPrompts[i], style: const TextStyle(color: AppTheme.accent, fontSize: 11, fontWeight: FontWeight.w500)),
                    ),
                  ),
                ),
              ),

            // ─ Messages ─
            Expanded(
              child: ListView.builder(
                controller: _scrollCtrl,
                padding: const EdgeInsets.all(12),
                itemCount: _messages.length + (_isLoading ? 1 : 0),
                itemBuilder: (_, i) {
                  if (i == _messages.length && _isLoading) return const _TypingIndicator();
                  return _Bubble(message: _messages[i]);
                },
              ),
            ),

            // ─ Input ─
            Container(
              padding: EdgeInsets.fromLTRB(12, 10, 12, MediaQuery.of(ctx).padding.bottom + 12),
              decoration: const BoxDecoration(
                color: AppTheme.surface,
                border: Border(top: BorderSide(color: AppTheme.border)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _ctrl,
                      style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                      maxLines: 3,
                      minLines: 1,
                      onSubmitted: _send,
                      decoration: InputDecoration(
                        hintText: 'Ask about your finances...',
                        hintStyle: const TextStyle(fontSize: 13),
                        filled: true,
                        fillColor: AppTheme.surfaceCard,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: const BorderSide(color: AppTheme.border)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: const BorderSide(color: AppTheme.border)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: const BorderSide(color: AppTheme.accent, width: 1.5)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => _send(_ctrl.text),
                    child: Container(
                      width: 44, height: 44,
                      decoration: const BoxDecoration(gradient: AppTheme.accentGradient, shape: BoxShape.circle),
                      child: const Icon(Icons.send_rounded, color: Colors.black, size: 18),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Private helpers ──────────────────────────────────────────

class _ChatMsg {
  final String text;
  final bool isUser;
  _ChatMsg({required this.text, required this.isUser});
}

class _Bubble extends StatelessWidget {
  final _ChatMsg message;
  const _Bubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              width: 26, height: 26,
              decoration: const BoxDecoration(gradient: AppTheme.accentGradient, shape: BoxShape.circle),
              child: const Center(child: Text('🤖', style: TextStyle(fontSize: 13))),
            ),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isUser ? AppTheme.accent.withValues(alpha: 0.2) : AppTheme.surfaceCard,
                borderRadius: BorderRadius.only(
                  topLeft:     const Radius.circular(16),
                  topRight:    const Radius.circular(16),
                  bottomLeft:  Radius.circular(isUser ? 16 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 16),
                ),
                border: Border.all(color: isUser ? AppTheme.accent.withValues(alpha: 0.3) : AppTheme.border),
              ),
              child: _buildText(message.text),
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 6),
            const CircleAvatar(radius: 13, backgroundColor: AppTheme.surfaceCard, child: Text('👤', style: TextStyle(fontSize: 11))),
          ],
        ],
      ),
    );
  }

  Widget _buildText(String text) {
    final parts = text.split('**');
    final spans = <TextSpan>[];
    for (int i = 0; i < parts.length; i++) {
      spans.add(TextSpan(
        text: parts[i],
        style: TextStyle(color: AppTheme.textPrimary, fontWeight: i.isOdd ? FontWeight.w700 : FontWeight.normal, fontSize: 13, height: 1.5),
      ));
    }
    return RichText(text: TextSpan(children: spans));
  }
}

class _TypingIndicator extends StatelessWidget {
  const _TypingIndicator();
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      children: [
        Container(width: 26, height: 26, decoration: const BoxDecoration(gradient: AppTheme.accentGradient, shape: BoxShape.circle), child: const Center(child: Text('🤖', style: TextStyle(fontSize: 13)))),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(color: AppTheme.surfaceCard, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppTheme.border)),
          child: const SizedBox(width: 40, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accent)),
        ),
      ],
    ),
  );
}
