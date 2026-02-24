import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import '../models/transaction.dart';
import 'package:uuid/uuid.dart';

class CsvService {
  static const _headers = [
    'date', 'title', 'store', 'amount', 'is_expense',
    'category', 'currency', 'account_id', 'notes',
  ];

  // ── Export ──────────────────────────────────────────────────
  static String buildCsv(List<Transaction> txns) {
    final buf = StringBuffer();
    buf.writeln(_headers.join(','));
    for (final t in txns) {
      buf.writeln([
        _escape(t.date.toIso8601String().split('T').first),
        _escape(t.title),
        _escape(t.storeName),
        t.amount.toStringAsFixed(2),
        t.isExpense ? 'true' : 'false',
        _escape(t.category),
        _escape(t.currency),
        _escape(t.accountId ?? ''),
        _escape(t.notes ?? ''),
      ].join(','));
    }
    return buf.toString();
  }

  /// Saves the CSV natively to the device (Downloads folder/Save dialog).
  static Future<String?> shareCSV(List<Transaction> txns) async {
    final csv = buildCsv(txns);
    final timestamp = DateTime.now().toIso8601String().split('.')[0].replaceAll(':', '-');
    final fileName = 'finance_export_$timestamp.csv';
    final bytes = Uint8List.fromList(utf8.encode(csv));

    final String? path = await FilePicker.platform.saveFile(
      dialogTitle: 'Save Finance Export',
      fileName: fileName,
      type: FileType.custom,
      allowedExtensions: ['csv'],
      bytes: bytes, 
    );
    
    // Fallback if the user is on a Desktop platform and saveFile gives a path but we still need to write the file ourselves
    if (path != null && !path.contains('blob:')) {
      try {
        final file = File(path);
        await file.writeAsBytes(bytes);
      } catch (e) {
        // Ignored, `file_picker` might have already written it depending on version and platform
      }
    }
    
    return path;
  }

  // ── Import ──────────────────────────────────────────────────
  /// Returns parsed [Transaction] objects ready for insertion.
  /// [accountNameToId] maps display name → id for the optional account column.
  static List<Transaction> parseCSV(
    String content, {
    Map<String, String> accountNameToId = const {},
    String fallbackCurrency = 'MYR',
    required String defaultAccountId,
    required Set<String> validAccountIds,
  }) {
    final lines = content.replaceAll('\r\n', '\n').replaceAll('\r', '\n').split('\n');
    if (lines.isEmpty) return [];

    // Detect header row
    final rawHeaders = _splitLine(lines.first).map((h) => h.toLowerCase().trim()).toList();
    int col(String name) => rawHeaders.indexOf(name);

    final iDate       = col('date');
    final iTitle      = col('title');
    final iStore      = col('store');
    final iAmount     = col('amount');
    final iIsExpense  = col('is_expense');
    final iCategory   = col('category');
    final iCurrency   = col('currency');
    final iAccount    = col('account');          // name-based (optional)
    final iAccountId  = col('account_id');       // id-based (optional)
    final iNotes      = col('notes');

    const uuid = Uuid();
    final results = <Transaction>[];

    for (int i = 1; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;
      final cells = _splitLine(line);
      T get<T>(int idx, T fallback, T Function(String) parse) {
        if (idx < 0 || idx >= cells.length) return fallback;
        final v = cells[idx].trim();
        if (v.isEmpty) return fallback;
        try { return parse(v); } catch (_) { return fallback; }
      }

      final date = get(iDate, DateTime.now(), DateTime.parse);
      final title = get(iTitle, 'Imported', (v) => v);
      final store = get(iStore, '', (v) => v);
      final amount = get(iAmount, 0.0, double.parse);
      if (amount <= 0) continue; // skip zero / invalid rows
      final isExpense = get(iIsExpense, true, (v) => v.toLowerCase() == 'true' || v == '1');
      final category = get(iCategory, 'Other', (v) => v);
      final currency = get(iCurrency, fallbackCurrency, (v) => v.isEmpty ? fallbackCurrency : v);
      final notes = get(iNotes, null, (v) => v.isEmpty ? null as String? : v);

      // resolve account
      String? accountId;
      if (iAccountId >= 0) {
        final aid = get(iAccountId, '', (v) => v);
        if (aid.isNotEmpty) accountId = aid;
      } else if (iAccount >= 0) {
        final aName = get(iAccount, '', (v) => v);
        accountId = accountNameToId[aName];
      }

      // Check validity against live accounts
      if (accountId == null || !validAccountIds.contains(accountId)) {
        accountId = defaultAccountId;
      }

      results.add(Transaction(
        id: uuid.v4(),
        title: title,
        storeName: store,
        amount: amount,
        category: category,
        date: date,
        currency: currency,
        isExpense: isExpense,
        notes: notes,
        accountId: accountId,
      ));
    }
    return results;
  }

  // ── Helpers ─────────────────────────────────────────────────
  static String _escape(String v) {
    if (v.contains(',') || v.contains('"') || v.contains('\n')) {
      return '"${v.replaceAll('"', '""')}"';
    }
    return v;
  }

  static List<String> _splitLine(String line) {
    final cells = <String>[];
    final buf = StringBuffer();
    bool inQuotes = false;
    for (int i = 0; i < line.length; i++) {
      final ch = line[i];
      if (ch == '"') {
        if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
          buf.write('"');
          i++;
        } else {
          inQuotes = !inQuotes;
        }
      } else if (ch == ',' && !inQuotes) {
        cells.add(buf.toString());
        buf.clear();
      } else {
        buf.write(ch);
      }
    }
    cells.add(buf.toString());
    return cells;
  }
}
