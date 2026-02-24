import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:animate_do/animate_do.dart';
import '../services/gemini_service.dart';
import '../theme/app_theme.dart';
import 'add_transaction_screen.dart';

class ScanReceiptScreen extends StatefulWidget {
  const ScanReceiptScreen({super.key});

  @override
  State<ScanReceiptScreen> createState() => _ScanReceiptScreenState();
}

class _ScanReceiptScreenState extends State<ScanReceiptScreen> {
  File? _image;
  bool _isAnalyzing = false;
  Map<String, dynamic>? _result;
  String? _error;

  final _picker = ImagePicker();

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(source: source, imageQuality: 85);
      if (picked == null) return;
      setState(() {
        _image = File(picked.path);
        _result = null;
        _error = null;
      });
    } catch (e) {
      setState(() => _error = 'Could not open camera/gallery: $e');
    }
  }

  Future<void> _analyzeReceipt() async {
    if (_image == null) return;
    setState(() { _isAnalyzing = true; _error = null; });

    try {
      final result = await GeminiService.analyzeReceipt(_image!);
      setState(() { _result = result; _isAnalyzing = false; });
    } catch (e) {
      setState(() {
        _error = 'Analysis failed: $e';
        _isAnalyzing = false;
      });
    }
  }

  void _confirmAndSave() {
    if (_result == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddTransactionScreen(prefill: _result),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Scan Receipt'),
        leading: BackButton(color: AppTheme.textPrimary),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // API key notice
            if (!GeminiService.hasApiKey)
              FadeInDown(
                child: Container(
                  padding: const EdgeInsets.all(14),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppTheme.accentGold.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.accentGold.withOpacity(0.4)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline_rounded, color: AppTheme.accentGold, size: 18),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Demo mode – Gemini API key not set. Using sample receipt data.',
                          style: TextStyle(color: AppTheme.accentGold, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Image area
            GestureDetector(
              onTap: () => _showPickOptions(),
              child: Container(
                height: 220,
                decoration: BoxDecoration(
                  color: AppTheme.surfaceCard,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _image != null ? AppTheme.accent : AppTheme.border,
                    width: _image != null ? 2 : 1,
                  ),
                ),
                child: _image != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(19),
                        child: Image.file(_image!, fit: BoxFit.cover),
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 64, height: 64,
                            decoration: BoxDecoration(
                              color: AppTheme.accent.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.document_scanner_rounded, color: AppTheme.accent, size: 32),
                          ),
                          const SizedBox(height: 16),
                          const Text('Tap to take or upload a photo', style: TextStyle(color: AppTheme.textSecondary, fontSize: 15)),
                          const SizedBox(height: 6),
                          const Text('of your receipt', style: TextStyle(color: AppTheme.textMuted, fontSize: 13)),
                        ],
                      ),
              ),
            ),

            const SizedBox(height: 16),

            // Pick buttons
            Row(
              children: [
                Expanded(
                  child: _PickButton(
                    icon: Icons.camera_alt_rounded,
                    label: 'Camera',
                    onTap: () => _pickImage(ImageSource.camera),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _PickButton(
                    icon: Icons.photo_library_rounded,
                    label: 'Gallery',
                    onTap: () => _pickImage(ImageSource.gallery),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Analyze button
            if (_image != null && _result == null)
              ElevatedButton.icon(
                onPressed: _isAnalyzing ? null : _analyzeReceipt,
                icon: _isAnalyzing
                    ? const SizedBox(width: 18, height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                    : const Icon(Icons.auto_awesome_rounded),
                label: Text(_isAnalyzing ? 'Analyzing...' : 'Analyze with AI'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),

            // Error
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(_error!, style: const TextStyle(color: AppTheme.accentRed)),
              ),

            // Result
            if (_result != null) ...[
              const SizedBox(height: 24),
              FadeInUp(
                child: _ResultCard(result: _result!),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _confirmAndSave,
                icon: const Icon(Icons.edit_note_rounded),
                label: const Text('Review & Fill Details →'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showPickOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _PickButton(icon: Icons.camera_alt_rounded, label: 'Camera', onTap: () { Navigator.pop(context); _pickImage(ImageSource.camera); }),
            _PickButton(icon: Icons.photo_library_rounded, label: 'Gallery', onTap: () { Navigator.pop(context); _pickImage(ImageSource.gallery); }),
          ],
        ),
      ),
    );
  }
}

class _PickButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _PickButton({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.surfaceCard,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Column(
            children: [
              Icon(icon, color: AppTheme.accent, size: 24),
              const SizedBox(height: 6),
              Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  final Map<String, dynamic> result;

  const _ResultCard({required this.result});

  @override
  Widget build(BuildContext context) {
    final store    = result['store_name'] ?? 'Unknown Store';
    final date     = result['date'] ?? '–';
    final amount   = result['total_amount'];
    final currency = result['currency'] ?? 'RM';
    final category = result['category'] ?? 'Other';
    final items    = (result['items'] as List?)?.cast<String>() ?? [];
    final conf     = ((result['confidence'] ?? 0.85) * 100).toInt();
    final catColor = AppTheme.categoryColors[category] ?? AppTheme.textSecondary;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.accent.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome_rounded, color: AppTheme.accent, size: 18),
              const SizedBox(width: 8),
              const Text('AI Extracted Data', style: TextStyle(color: AppTheme.accent, fontWeight: FontWeight.w700)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.accent.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('$conf% confident', style: const TextStyle(color: AppTheme.accent, fontSize: 11, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _Row('Store', store),
          _Row('Date', date),
          _Row('Total', '$currency ${amount?.toStringAsFixed(2) ?? '–'}'),
          _Row('Category', category, valueColor: catColor),
          if (items.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text('Items', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
            const SizedBox(height: 6),
            ...items.take(5).map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(children: [
                const Text('• ', style: TextStyle(color: AppTheme.accent)),
                Expanded(child: Text(item, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13))),
              ]),
            )),
          ],
        ],
      ),
    );
  }

  Widget _Row(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          SizedBox(width: 80, child: Text(label, style: const TextStyle(color: AppTheme.textMuted, fontSize: 13))),
          Expanded(child: Text(value, style: TextStyle(color: valueColor ?? AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 14))),
        ],
      ),
    );
  }
}
