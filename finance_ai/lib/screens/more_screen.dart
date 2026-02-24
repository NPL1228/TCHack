import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../providers/finance_provider.dart';
import 'package:provider/provider.dart';
import 'budget_screen.dart';
import 'groceries_screen.dart';
import 'passcode_screen.dart';
import 'recurring_screen.dart';
import 'about_screen.dart';
import '../services/settings_service.dart';
import '../services/subcategory_service.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(title: const Text('More')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ─ Tools section ─
          _SectionHeader(label: 'TOOLS'),
          const SizedBox(height: 8),
          _MenuTile(
            icon: Icons.savings_rounded,
            color: AppTheme.accentGold,
            title: 'Budget',
            subtitle: 'Set and track monthly budgets',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BudgetScreen())),
          ),
          const SizedBox(height: 10),
          _MenuTile(
            icon: Icons.shopping_cart_rounded,
            color: AppTheme.accentBlue,
            title: 'Price Finder',
            subtitle: 'Compare prices with AI assistance',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const GroceriesScreen())),
          ),

          const SizedBox(height: 24),

          // ─ Data section ─
          _SectionHeader(label: 'DATA'),
          const SizedBox(height: 8),
          _MenuTile(
            icon: Icons.table_chart_rounded,
            color: AppTheme.accent,
            title: 'Export Analysis (Excel)',
            subtitle: 'Download .xlsx with expense breakdown',
            onTap: () => _showExportExcelSheet(context),
          ),

          const SizedBox(height: 24),

          // ─ Full Backup section ─
          _SectionHeader(label: 'FULL BACKUP'),
          const SizedBox(height: 8),
          _MenuTile(
            icon: Icons.restore_rounded,
            color: AppTheme.accentBlue,
            title: 'Restore from Backup',
            subtitle: 'Overwrites app with a .json restore file',
            onTap: () async {
              try {
                final result = await FilePicker.platform.pickFiles(
                  type: FileType.custom,
                  allowedExtensions: ['json'],
                );
                if (result == null || result.files.isEmpty) return;

                final file = File(result.files.single.path!);
                final content = await file.readAsString();

                if (!context.mounted) return;
                await context.read<FinanceProvider>().restoreFromBackup(content);

                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('App successfully restored!'), backgroundColor: AppTheme.accent),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Restore failed: $e'), backgroundColor: AppTheme.accentRed),
                  );
                }
              }
            },
          ),
          const SizedBox(height: 10),
          _MenuTile(
            icon: Icons.save_rounded,
            color: AppTheme.accent,
            title: 'Create Backup (.json)',
            subtitle: 'Securely export a full device snapshot',
            onTap: () async {
              try {
                final jsonString = await context.read<FinanceProvider>().exportFullBackup();
                final timestamp = DateTime.now().toIso8601String().split('.')[0].replaceAll(':', '-');
                final fileName = 'ailedge_backup_$timestamp.json';

                final String? path = await FilePicker.platform.saveFile(
                  dialogTitle: 'Save JSON Backup',
                  fileName: fileName,
                  type: FileType.custom,
                  allowedExtensions: ['json'],
                  bytes: Uint8List.fromList(utf8.encode(jsonString)),
                );

                if (path != null && !path.contains('blob:')) {
                  try {
                    final file = File(path);
                    await file.writeAsString(jsonString);
                  } catch (e) {
                    // Ignored
                  }

                  if (!context.mounted) return;
                  _showExportPath(context, path);
                } else if (path != null) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Backup saved successfully!'), backgroundColor: AppTheme.accent),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Backup failed: $e'), backgroundColor: AppTheme.accentRed),
                  );
                }
              }
            },
          ),

          const SizedBox(height: 24),

          // ─ App section ─
          _SectionHeader(label: 'APP'),
          const SizedBox(height: 8),
          _MenuTile(
            icon: Icons.settings_rounded,
            color: AppTheme.textSecondary,
            title: 'Settings',
            subtitle: 'App preferences & configuration',
            onTap: () => _showSettings(context),
          ),
          const SizedBox(height: 10),
          _MenuTile(
            icon: Icons.info_outline_rounded,
            color: AppTheme.textMuted,
            title: 'About',
            subtitle: 'AiLedge – Version 1.0.0',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AboutScreen()),
            ),
          ),
        ],
      ),
    );
  }

  // ── Excel Export Month Picker ─────────────────────────────────
  void _showExportExcelSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _ExportExcelSheet(fp: context.read<FinanceProvider>()),
    );
  }

  void _showExportPath(BuildContext context, String path) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceCard,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppTheme.border, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 20),
            const Row(children: [
              Icon(Icons.check_circle_rounded, color: AppTheme.accent, size: 22),
              SizedBox(width: 10),
              Text('Export Successful', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700, fontSize: 16)),
            ]),
            const SizedBox(height: 16),
            const Text('Saved file:', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w500)),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppTheme.background, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppTheme.border)),
              child: Text(path.split('/').last.split('\\').last, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w600, fontFamily: 'monospace')),
            ),
            const SizedBox(height: 8),
            const Text('Your file has been successfully saved to your chosen folder.', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showSettings(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceCard,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _SettingsSheet(context: context),
    );
  }

  void _showCurrencyPicker(BuildContext context, FinanceProvider fp) {
    const currencies = ['MYR', 'USD', 'EUR', 'GBP', 'SGD', 'JPY'];
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceCard,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Select Display Currency', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700, fontSize: 18)),
            const SizedBox(height: 16),
            ...currencies.map((c) => ListTile(
              title: Text(c, style: const TextStyle(color: AppTheme.textPrimary)),
              trailing: fp.mainCurrency == c ? const Icon(Icons.check_rounded, color: AppTheme.accent) : null,
              onTap: () {
                fp.setMainCurrency(c);
                Navigator.pop(context);
                _showSettings(context);
              },
            )),
          ],
        ),
      ),
    );
  }
}

// ── Excel Export Month Picker Sheet ──────────────────────────
class _ExportExcelSheet extends StatefulWidget {
  final FinanceProvider fp;
  const _ExportExcelSheet({required this.fp});

  @override
  State<_ExportExcelSheet> createState() => _ExportExcelSheetState();
}

class _ExportExcelSheetState extends State<_ExportExcelSheet> {
  final Set<String> _selected = {};
  bool _exporting = false;

  List<({int year, int month})> _last12Months() {
    final now    = DateTime.now();
    final result = <({int year, int month})>[];
    for (int i = 0; i < 12; i++) {
      final d = DateTime(now.year, now.month - i);
      result.add((year: d.year, month: d.month));
    }
    return result;
  }

  String _monthKey(int year, int month) => '$year-$month';

  @override
  void initState() {
    super.initState();
    // Pre-select current month
    final now = DateTime.now();
    _selected.add(_monthKey(now.year, now.month));
  }

  @override
  Widget build(BuildContext context) {
    final months = _last12Months();

    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.of(context).padding.bottom + 24),
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(child: Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(color: AppTheme.border, borderRadius: BorderRadius.circular(2)))),
          Row(children: [
            const Text('Export Analysis (Excel)',
                style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700, fontSize: 16)),
            const Spacer(),
            GestureDetector(
              onTap: () => setState(() {
                if (_selected.length == months.length) {
                  _selected.clear();
                } else {
                  _selected.addAll(months.map((m) => _monthKey(m.year, m.month)));
                }
              }),
              child: Text(_selected.length == months.length ? 'Deselect All' : 'Select All',
                  style: const TextStyle(color: AppTheme.accent, fontSize: 13, fontWeight: FontWeight.w600)),
            ),
          ]),
          const SizedBox(height: 6),
          const Text('Choose months to include in the report:',
              style: TextStyle(color: AppTheme.textMuted, fontSize: 13)),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: months.map((m) {
              final key  = _monthKey(m.year, m.month);
              final sel  = _selected.contains(key);
              final label = DateFormat('MMM yyyy').format(DateTime(m.year, m.month));
              return GestureDetector(
                onTap: () => setState(() {
                  if (sel) _selected.remove(key); else _selected.add(key);
                }),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: sel ? AppTheme.accent.withValues(alpha: 0.2) : AppTheme.surfaceCard,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: sel ? AppTheme.accent : AppTheme.border),
                  ),
                  child: Text(label, style: TextStyle(
                    color: sel ? AppTheme.accent : AppTheme.textSecondary,
                    fontWeight: sel ? FontWeight.w700 : FontWeight.normal,
                    fontSize: 13,
                  )),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _selected.isEmpty || _exporting ? null : () async {
                setState(() => _exporting = true);
                try {
                  final months = _selected.map((k) {
                    final parts = k.split('-');
                    return (year: int.parse(parts[0]), month: int.parse(parts[1]));
                  }).toList();
                  final path = await widget.fp.exportTransactionsExcel(months);
                  if (!context.mounted) return;
                  Navigator.pop(context);
                  if (path != null && !path.contains('blob:')) {
                    MoreScreen()._showExportPath(context, path);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Excel exported to Downloads!'), backgroundColor: AppTheme.accent),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Export failed: $e'), backgroundColor: AppTheme.accentRed),
                    );
                  }
                } finally {
                  if (mounted) setState(() => _exporting = false);
                }
              },
              icon: _exporting
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                  : const Icon(Icons.download_rounded, color: Colors.black),
              label: Text(_exporting ? 'Exporting…' : 'Export ${_selected.length} Month${_selected.length == 1 ? '' : 's'}',
                  style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w700)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accent,
                disabledBackgroundColor: AppTheme.accent.withValues(alpha: 0.4),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Settings Sheet ─────────────────────────────────────────────
class _SettingsSheet extends StatefulWidget {
  final BuildContext context;
  const _SettingsSheet({required this.context});
  @override
  State<_SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<_SettingsSheet> {
  static const _backupOptions = [
    (label: 'Daily',   days: 1),
    (label: 'Weekly',  days: 7),
    (label: 'Monthly', days: 30),
  ];

  @override
  Widget build(BuildContext context) {
    final fp = context.watch<FinanceProvider>();
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom + MediaQuery.of(context).padding.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(child: Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(color: AppTheme.border, borderRadius: BorderRadius.circular(2)))),
          const Text('Settings', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700, fontSize: 18)),
          const SizedBox(height: 20),

          // ── Currency ─────────────────────────────────────────────
          GestureDetector(
            onTap: () {
              Navigator.pop(context);
              MoreScreen().._showCurrencyPicker(widget.context, fp);
            },
            behavior: HitTestBehavior.opaque,
            child: _SettingRow(
              icon: Icons.language_rounded, label: 'Display Currency',
              child: Row(children: [
                Text(fp.mainCurrency, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(width: 4),
                const Icon(Icons.arrow_drop_down_rounded, color: AppTheme.textMuted),
              ]),
            ),
          ),
          const Divider(color: AppTheme.border, height: 24),

          // ── Passcode ─────────────────────────────────────────────
          _SettingRow(
            icon: Icons.lock_rounded, label: 'App Passcode',
            child: Switch(
              value: SettingsService.passcodeEnabled,
              activeColor: AppTheme.accent,
              onChanged: (v) async {
                if (v) {
                  final res = await Navigator.push<bool>(context, MaterialPageRoute(
                    builder: (_) => const PasscodeScreen(mode: PasscodeMode.setup),
                  ));
                  if (res == true) setState(() {});
                } else {
                  await SettingsService.clearPasscode();
                  setState(() {});
                }
              },
            ),
          ),
          const Divider(color: AppTheme.border, height: 24),

          // ── Recurring ────────────────────────────────────────────
          _SettingRow(
            icon: Icons.repeat_rounded, label: 'Recurring Transactions',
            child: Row(children: [
              Switch(
                value: SettingsService.recurringEnabled,
                activeColor: AppTheme.accent,
                onChanged: (v) async {
                  await SettingsService.setRecurringEnabled(v);
                  setState(() {});
                },
              ),
              if (SettingsService.recurringEnabled) ...[
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const RecurringScreen()));
                  },
                  child: const Text('Manage', style: TextStyle(color: AppTheme.accent, fontSize: 12, fontWeight: FontWeight.w600)),
                ),
              ],
            ]),
          ),
          const Divider(color: AppTheme.border, height: 24),

          // ── Subcategories ────────────────────────────────────────
          _SettingRow(
            icon: Icons.category_rounded, label: 'Subcategories',
            child: Row(children: [
              Switch(
                value: SettingsService.subcategoriesEnabled,
                activeColor: AppTheme.accent,
                onChanged: (v) async {
                  await SettingsService.setSubcategoriesEnabled(v);
                  setState(() {});
                },
              ),
              if (SettingsService.subcategoriesEnabled) ...[
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: () => _showManageSubcategories(context),
                  child: const Text('Manage', style: TextStyle(color: AppTheme.accent, fontSize: 12, fontWeight: FontWeight.w600)),
                ),
              ],
            ]),
          ),
          const Divider(color: AppTheme.border, height: 24),

          // ── Auto Backup ──────────────────────────────────────────
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SettingRow(
                icon: Icons.backup_rounded, label: 'Auto Backup (JSON)',
                child: Switch(
                  value: SettingsService.backupEnabled,
                  activeColor: AppTheme.accent,
                  onChanged: (v) async {
                    await SettingsService.setBackupEnabled(v);
                    setState(() {});
                  },
                ),
              ),
              if (SettingsService.backupEnabled) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: _backupOptions.map((opt) {
                    final sel = SettingsService.backupPeriodDays == opt.days;
                    return ChoiceChip(
                      label: Text(opt.label),
                      selected: sel,
                      selectedColor: AppTheme.accent.withValues(alpha: 0.2),
                      backgroundColor: AppTheme.background,
                      labelStyle: TextStyle(color: sel ? AppTheme.accent : AppTheme.textSecondary, fontSize: 12),
                      side: BorderSide(color: sel ? AppTheme.accent : AppTheme.border),
                      onSelected: (_) async {
                        await SettingsService.setBackupPeriodDays(opt.days);
                        setState(() {});
                      },
                    );
                  }).toList(),
                ),
                if (SettingsService.lastBackupAt != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      'Last backup: ${SettingsService.lastBackupAt!.toLocal().toString().split('.').first}',
                      style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
                    ),
                  ),
              ],
            ],
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  void _showManageSubcategories(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceCard,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _ManageSubcategoriesSheet(),
    );
  }
}

// ── Manage Subcategories Sheet ────────────────────────────────
class _ManageSubcategoriesSheet extends StatefulWidget {
  @override
  State<_ManageSubcategoriesSheet> createState() => _ManageSubcategoriesSheetState();
}

class _ManageSubcategoriesSheetState extends State<_ManageSubcategoriesSheet> {
  final _catCtrl  = TextEditingController();
  String _selectedCat = AppTheme.categories.first;

  @override
  void dispose() { _catCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final subMap  = SubcategoryService.allSubcategories();
    final subcats = subMap[_selectedCat] ?? [];

    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.75,
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(color: AppTheme.border, borderRadius: BorderRadius.circular(2)))),
            const Text('Manage Subcategories', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700, fontSize: 17)),
            const SizedBox(height: 14),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(color: AppTheme.background, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppTheme.border)),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedCat,
                  isExpanded: true,
                  dropdownColor: AppTheme.surfaceCard,
                  style: const TextStyle(color: AppTheme.textPrimary),
                  items: AppTheme.categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                  onChanged: (v) => setState(() => _selectedCat = v!),
                ),
              ),
            ),
            const SizedBox(height: 12),

            Expanded(
              child: subcats.isEmpty
                  ? const Center(child: Text('No subcategories yet.', style: TextStyle(color: AppTheme.textMuted)))
                  : ListView.separated(
                      itemCount: subcats.length,
                      separatorBuilder: (_, __) => const Divider(color: AppTheme.border, height: 1),
                      itemBuilder: (_, i) => ListTile(
                        dense: true,
                        title: Text(subcats[i], style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14)),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, color: AppTheme.accentRed, size: 18),
                          onPressed: () async {
                            await SubcategoryService.removeSubcategory(_selectedCat, subcats[i]);
                            setState(() {});
                          },
                        ),
                      ),
                    ),
            ),

            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _catCtrl,
                    style: const TextStyle(color: AppTheme.textPrimary),
                    decoration: const InputDecoration(hintText: 'New subcategory name', contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () async {
                    final name = _catCtrl.text.trim();
                    if (name.isEmpty) return;
                    await SubcategoryService.addSubcategory(_selectedCat, name);
                    _catCtrl.clear();
                    setState(() {});
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accent, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12)),
                  child: const Text('Add', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});
  @override
  Widget build(BuildContext context) => Text(
    label,
    style: const TextStyle(color: AppTheme.textMuted, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1),
  );
}

class _MenuTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _MenuTile({required this.icon, required this.color, required this.title, required this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.surfaceCard,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(width: 44, height: 44,
                  decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
                  child: Icon(icon, color: color, size: 22)),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 15)),
                Text(subtitle, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
              ])),
              const Icon(Icons.chevron_right_rounded, color: AppTheme.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final Widget child;
  const _SettingRow({required this.icon, required this.label, required this.child});

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, color: AppTheme.textSecondary, size: 20),
      const SizedBox(width: 12),
      Expanded(child: Text(label, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 15))),
      child,
    ],
  );
}
