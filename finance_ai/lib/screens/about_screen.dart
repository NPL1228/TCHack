import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import '../theme/app_theme.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('About AiLedge'),
        leading: BackButton(color: AppTheme.textPrimary),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 40),
            // ── Logo and Name ───────────────────────────────────
            FadeInDown(
              child: Center(
                child: Column(
                  children: [
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: AppTheme.accent.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                        border: Border.all(color: AppTheme.accent.withValues(alpha: 0.3), width: 2),
                      ),
                      child: const Center(
                        child: Text(
                          'AL',
                          style: TextStyle(
                            color: AppTheme.accent,
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'AiLedge',
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -1,
                      ),
                    ),
                    const Text(
                      'AI-Powered Personal Finance',
                      style: TextStyle(
                        color: AppTheme.textMuted,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 48),

            // ── Description ────────────────────────────────────
            FadeInUp(
              delay: const Duration(milliseconds: 200),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'The Smarter Way to Save',
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'AiLedge is your personal financial companion that combines smart tracking with artificial intelligence. We help you understand where your money goes, find savings you didn\'t know existed, and reach your goals faster.',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 15,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 40),

            // ── Features List ──────────────────────────────────
            FadeInUp(
              delay: const Duration(milliseconds: 400),
              child: Column(
                children: [
                  _FeatureTile(
                    icon: Icons.auto_awesome_rounded,
                    title: 'AI Advisor',
                    desc: 'Get deep insights into your spending habits powered by Google Gemini.',
                  ),
                  _FeatureTile(
                    icon: Icons.repeat_rounded,
                    title: 'Recurring Magic',
                    desc: 'Manage recurring bills and subscriptions effortlessly in one place.',
                  ),
                  _FeatureTile(
                    icon: Icons.table_view_rounded,
                    title: 'Excel Analysis',
                    desc: 'Export beautiful, data-rich Excel sheets for professional financial review.',
                  ),
                  _FeatureTile(
                    icon: Icons.lock_rounded,
                    title: 'Privacy First',
                    desc: 'Your data stays on your device. Securely backup to JSON whenever you want.',
                  ),
                ],
              ),
            ),

            const SizedBox(height: 40),

            // ── Footer info ─────────────────────────────────────
            FadeIn(
              delay: const Duration(milliseconds: 600),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    const Divider(color: AppTheme.border),
                    const SizedBox(height: 16),
                    const Text(
                      'Version 1.0.0 (Stable)',
                      style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'Powered by ',
                          style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
                        ),
                        Text(
                          'Google Gemini',
                          style: TextStyle(color: AppTheme.accent, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Text(
                      '© 2026 AiLedge Team. All rights reserved.',
                      style: TextStyle(color: AppTheme.textMuted.withValues(alpha: 0.5), fontSize: 11),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeatureTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String desc;

  const _FeatureTile({required this.icon, required this.title, required this.desc});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.surfaceCard,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.border),
            ),
            child: Icon(icon, color: AppTheme.accent, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  desc,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 13,
                    height: 1.4,
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
