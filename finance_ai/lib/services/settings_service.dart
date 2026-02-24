import 'package:hive_flutter/hive_flutter.dart';

/// Centralised persistent settings backed by a Hive box.
/// Call [open()] once at startup (inside [FinanceProvider.openBoxes]).
class SettingsService {
  static const _boxName = 'settings';

  // Keys
  static const _kPasscodeEnabled    = 'passcode_enabled';
  static const _kPasscodePin        = 'passcode_pin';
  static const _kSubcatEnabled      = 'subcategories_enabled';
  static const _kRecurringEnabled   = 'recurring_enabled';
  static const _kBackupEnabled      = 'backup_enabled';
  static const _kBackupPeriodDays   = 'backup_period_days';
  static const _kLastBackupAt       = 'last_backup_at';

  static Box<dynamic>? _box;
  static Box<dynamic> get _b {
    assert(_box != null, 'SettingsService.open() was not called');
    return _box!;
  }

  static Future<void> open() async {
    _box = await Hive.openBox<dynamic>(_boxName);
  }

  // ── Passcode ──────────────────────────────────────────────────
  static bool get passcodeEnabled => _b.get(_kPasscodeEnabled, defaultValue: false) as bool;
  static Future<void> setPasscodeEnabled(bool v) => _b.put(_kPasscodeEnabled, v);

  static String? get passcodePin => _b.get(_kPasscodePin) as String?;
  static Future<void> setPasscodePin(String pin) => _b.put(_kPasscodePin, pin);
  static Future<void> clearPasscode() async {
    await _b.put(_kPasscodeEnabled, false);
    await _b.delete(_kPasscodePin);
  }

  // ── Subcategories ─────────────────────────────────────────────
  static bool get subcategoriesEnabled => _b.get(_kSubcatEnabled, defaultValue: false) as bool;
  static Future<void> setSubcategoriesEnabled(bool v) => _b.put(_kSubcatEnabled, v);

  // ── Recurring ─────────────────────────────────────────────────
  static bool get recurringEnabled => _b.get(_kRecurringEnabled, defaultValue: false) as bool;
  static Future<void> setRecurringEnabled(bool v) => _b.put(_kRecurringEnabled, v);

  // ── Auto backup ───────────────────────────────────────────────
  static bool get backupEnabled => _b.get(_kBackupEnabled, defaultValue: false) as bool;
  static Future<void> setBackupEnabled(bool v) => _b.put(_kBackupEnabled, v);

  static int get backupPeriodDays => _b.get(_kBackupPeriodDays, defaultValue: 7) as int;
  static Future<void> setBackupPeriodDays(int d) => _b.put(_kBackupPeriodDays, d);

  static DateTime? get lastBackupAt {
    final ms = _b.get(_kLastBackupAt) as int?;
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }
  static Future<void> setLastBackupAt(DateTime dt) =>
      _b.put(_kLastBackupAt, dt.millisecondsSinceEpoch);

  static bool get isBackupDue {
    final last = lastBackupAt;
    if (last == null) return true;
    final now  = DateTime.now();
    final days = backupPeriodDays;
    final DateTime periodStart;
    if (days == 1) {
      // Daily – start of today
      periodStart = DateTime(now.year, now.month, now.day);
    } else if (days == 7) {
      // Weekly – start of this Monday
      final daysFromMon = (now.weekday - 1) % 7;
      final mon = DateTime(now.year, now.month, now.day - daysFromMon);
      periodStart = mon;
    } else {
      // Monthly – 1st of this month
      periodStart = DateTime(now.year, now.month, 1);
    }
    return last.isBefore(periodStart);
  }
}
