import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/finance_provider.dart';
import '../services/gemini_service.dart';
import '../theme/app_theme.dart';

/// Universal price comparison screen — not just groceries. Works for
/// any item: movie tickets, dining, electronics, household goods, etc.
class GroceriesScreen extends StatefulWidget {
  const GroceriesScreen({super.key});

  @override
  State<GroceriesScreen> createState() => _GroceriesScreenState();
}

class _GroceriesScreenState extends State<GroceriesScreen> {
  final _ctrl         = TextEditingController();
  final List<String>  _items       = [];
  List<Map<String, dynamic>> _results = [];
  bool _isLoading     = false;
  bool _hasResults    = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _addItem() {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _items.add(text);
      _results = [];
      _hasResults = false;
    });
    _ctrl.clear();
  }

  void _removeItem(int index) {
    setState(() {
      _items.removeAt(index);
      _results = [];
      _hasResults = false;
    });
  }

  Future<void> _findBestPrices() async {
    if (_items.isEmpty) return;
    setState(() { _isLoading = true; _results = []; _hasResults = false; });
    final fp = context.read<FinanceProvider>();
    final suggestions = await GeminiService.generateGrocerySuggestions(_items, fp.allTransactions);
    setState(() {
      _results   = suggestions;
      _isLoading = false;
      _hasResults = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Price Finder'),
        actions: [
          if (_items.isNotEmpty)
            TextButton.icon(
              onPressed: () => setState(() { _items.clear(); _results = []; _hasResults = false; }),
              icon: const Icon(Icons.clear_all_rounded, color: AppTheme.accentRed, size: 18),
              label: const Text('Clear', style: TextStyle(color: AppTheme.accentRed, fontSize: 13)),
            ),
        ],
      ),
      body: Column(
        children: [
          // ─ Header hint ─
          Container(
            width: double.infinity,
            color: AppTheme.surface,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: const Text(
              '🔍 Add anything you want to price-compare — groceries, movie tickets, restaurants, electronics, and more. AI finds the best value based on your history.',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
            ),
          ),

          // ─ Input row ─
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _ctrl,
                    style: const TextStyle(color: AppTheme.textPrimary),
                    onSubmitted: (_) => _addItem(),
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      hintText: 'e.g. GSC ticket, Chicken rice, iPhone case...',
                      prefixIcon: const Icon(Icons.add_shopping_cart_rounded, color: AppTheme.textMuted),
                      suffixIcon: _ctrl.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, color: AppTheme.textMuted),
                              onPressed: () { _ctrl.clear(); setState(() {}); },
                            )
                          : null,
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: _addItem,
                  child: Container(
                    width: 48, height: 48,
                    decoration: const BoxDecoration(gradient: AppTheme.accentGradient, shape: BoxShape.circle),
                    child: const Icon(Icons.add_rounded, color: Colors.black),
                  ),
                ),
              ],
            ),
          ),

          // ─ Shopping list ─
          if (_items.isNotEmpty)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: AppTheme.surfaceCard,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.border),
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    child: Row(
                      children: [
                        const Text('Shopping List', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700, fontSize: 14)),
                        const Spacer(),
                        Text('${_items.length} item${_items.length == 1 ? '' : 's'}',
                            style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                      ],
                    ),
                  ),
                  const Divider(color: AppTheme.border, height: 1),
                  ...List.generate(_items.length, (i) {
                    final isLast = i == _items.length - 1;
                    return Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          child: Row(
                            children: [
                              Container(
                                width: 8, height: 8,
                                decoration: const BoxDecoration(color: AppTheme.accent, shape: BoxShape.circle),
                              ),
                              const SizedBox(width: 12),
                              Expanded(child: Text(_items[i], style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14))),
                              GestureDetector(
                                onTap: () => _removeItem(i),
                                child: const Icon(Icons.close_rounded, color: AppTheme.textMuted, size: 18),
                              ),
                            ],
                          ),
                        ),
                        if (!isLast) const Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Divider(color: AppTheme.border, height: 1)),
                      ],
                    );
                  }),
                ],
              ),
            ),

          const SizedBox(height: 12),

          // ─ Find Best Prices button ─
          if (_items.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _findBestPrices,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accent,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: _isLoading
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black54))
                      : const Icon(Icons.search_rounded),
                  label: Text(_isLoading ? 'Analysing...' : 'Find Best Prices',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                ),
              ),
            ),

          const SizedBox(height: 8),

          // ─ Results ─
          Expanded(
            child: _isLoading
                ? const Center(child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(color: AppTheme.accent),
                      SizedBox(height: 16),
                      Text('AiLedge is finding the best deals...', style: TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
                    ],
                  ))
                : _hasResults && _results.isNotEmpty
                    ? ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
                        itemCount: _results.length,
                        itemBuilder: (ctx, i) => _GroceryResultCard(data: _results[i]),
                      )
                    : _hasResults && _results.isEmpty
                        ? const Center(child: Text('No suggestions found.', style: TextStyle(color: AppTheme.textMuted)))
                        : _items.isEmpty
                            ? _EmptyState()
                            : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: const [
      Text('🛒', style: TextStyle(fontSize: 56)),
      SizedBox(height: 16),
      Text('Start your shopping list above', style: TextStyle(color: AppTheme.textSecondary, fontSize: 15, fontWeight: FontWeight.w600)),
      SizedBox(height: 6),
      Text('AI will suggest the best places\nto buy each item based on your history',
          textAlign: TextAlign.center, style: TextStyle(color: AppTheme.textMuted, fontSize: 13)),
    ],
  );
}

// ─────────────────────────────────────────────────────────────
class _GroceryResultCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _GroceryResultCard({required this.data});

  Color _ratingColor(String rating) {
    switch (rating) {
      case 'Budget':  return AppTheme.accent;
      case 'Mid':     return AppTheme.accentBlue;
      case 'Premium': return AppTheme.accentGold;
      default:        return AppTheme.textMuted;
    }
  }

  @override
  Widget build(BuildContext context) {
    final item        = data['item'] as String? ?? '';
    final suggestions = (data['suggestions'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Item header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppTheme.accent.withValues(alpha: 0.08),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              border: const Border(bottom: BorderSide(color: AppTheme.border)),
            ),
            child: Row(
              children: [
                const Text('🛒', style: TextStyle(fontSize: 18)),
                const SizedBox(width: 10),
                Text(item, style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700, fontSize: 15)),
              ],
            ),
          ),

          // Suggestions
          ...List.generate(suggestions.length, (i) {
            final s      = suggestions[i];
            final store  = s['store']     as String? ?? '';
            final price  = s['est_price'] as String? ?? '';
            final rating = s['rating']    as String? ?? '';
            final note   = s['note']      as String? ?? '';
            final color  = _ratingColor(rating);
            final isLast = i == suggestions.length - 1;
            final rank   = ['🥇', '🥈', '🥉'][i.clamp(0, 2)];

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Text(rank, style: const TextStyle(fontSize: 18)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(store, style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 14)),
                            if (note.isNotEmpty)
                              Text(note, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(price, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 14)),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(rating, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (!isLast) const Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Divider(color: AppTheme.border, height: 1)),
              ],
            );
          }),
        ],
      ),
    );
  }
}
