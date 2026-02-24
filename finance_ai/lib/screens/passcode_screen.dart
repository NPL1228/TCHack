import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/settings_service.dart';
import '../theme/app_theme.dart';

/// Mode of the passcode screen.
enum PasscodeMode { setup, verify }

class PasscodeScreen extends StatefulWidget {
  final PasscodeMode mode;
  /// Called when verify succeeds (mode == verify).
  final VoidCallback? onSuccess;

  const PasscodeScreen({super.key, required this.mode, this.onSuccess});

  @override
  State<PasscodeScreen> createState() => _PasscodeScreenState();
}

class _PasscodeScreenState extends State<PasscodeScreen> with SingleTickerProviderStateMixin {
  String _input = '';
  String? _firstPin;
  String _hint = '';
  late AnimationController _shakeCtrl;
  late Animation<double> _shakeAnim;

  @override
  void initState() {
    super.initState();
    _hint = widget.mode == PasscodeMode.setup
        ? 'Set a 4-digit PIN'
        : 'Enter your PIN';
    _shakeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _shakeAnim = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -8.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -8.0, end: 8.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 8.0, end: 0.0), weight: 1),
    ]).animate(_shakeCtrl);
  }

  @override
  void dispose() {
    _shakeCtrl.dispose();
    super.dispose();
  }

  void _onKey(String digit) {
    if (_input.length >= 4) return;
    setState(() => _input += digit);
    if (_input.length == 4) _evaluate();
  }

  void _onDelete() {
    if (_input.isEmpty) return;
    setState(() => _input = _input.substring(0, _input.length - 1));
  }

  Future<void> _evaluate() async {
    await Future.delayed(const Duration(milliseconds: 100));
    if (widget.mode == PasscodeMode.setup) {
      if (_firstPin == null) {
        // First entry — store and ask to confirm
        setState(() {
          _firstPin = _input;
          _input = '';
          _hint = 'Confirm your PIN';
        });
      } else {
        if (_input == _firstPin) {
          // Confirmed — save
          await SettingsService.setPasscodePin(_input);
          await SettingsService.setPasscodeEnabled(true);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('PIN set successfully!'), backgroundColor: AppTheme.accent),
            );
            Navigator.pop(context, true);
          }
        } else {
          // Mismatch — reset
          _doShake();
          setState(() { _input = ''; _firstPin = null; _hint = 'PINs don\'t match. Try again.'; });
        }
      }
    } else {
      // Verify mode
      final correct = SettingsService.passcodePin;
      if (_input == correct) {
        widget.onSuccess?.call();
        if (mounted && Navigator.canPop(context)) Navigator.pop(context, true);
      } else {
        _doShake();
        setState(() { _input = ''; _hint = 'Incorrect PIN. Try again.'; });
      }
    }
  }

  void _doShake() {
    _shakeCtrl.forward(from: 0);
    HapticFeedback.mediumImpact();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Lock icon
              Container(
                width: 72, height: 72,
                decoration: BoxDecoration(
                  color: AppTheme.accent.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                  border: Border.all(color: AppTheme.accent.withValues(alpha: 0.3), width: 2),
                ),
                child: const Icon(Icons.lock_rounded, color: AppTheme.accent, size: 36),
              ),
              const SizedBox(height: 24),

              Text(_hint,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppTheme.textPrimary, fontSize: 17, fontWeight: FontWeight.w600)),
              const SizedBox(height: 32),

              // PIN dots
              AnimatedBuilder(
                animation: _shakeAnim,
                builder: (_, child) => Transform.translate(offset: Offset(_shakeAnim.value, 0), child: child),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(4, (i) {
                    final filled = i < _input.length;
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 10),
                      width: 16, height: 16,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: filled ? AppTheme.accent : Colors.transparent,
                        border: Border.all(color: filled ? AppTheme.accent : AppTheme.border, width: 2),
                      ),
                    );
                  }),
                ),
              ),
              const SizedBox(height: 48),

              // Keypad
              GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.4,
                children: [
                  ...'123456789'.split('').map((d) => _Key(label: d, onTap: () => _onKey(d))),
                  const SizedBox.shrink(),
                  _Key(label: '0', onTap: () => _onKey('0')),
                  _Key(icon: Icons.backspace_outlined, onTap: _onDelete),
                ],
              ),

              if (widget.mode == PasscodeMode.verify) ...[
                const SizedBox(height: 24),
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel', style: TextStyle(color: AppTheme.textMuted)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Key extends StatelessWidget {
  final String? label;
  final IconData? icon;
  final VoidCallback onTap;

  const _Key({this.label, this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.surfaceCard,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Center(
          child: label != null
              ? Text(label!, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 24, fontWeight: FontWeight.w600))
              : Icon(icon, color: AppTheme.textSecondary, size: 22),
        ),
      ),
    );
  }
}
