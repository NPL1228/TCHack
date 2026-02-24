import 'dart:io';
import 'dart:typed_data';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import '../models/transaction.dart';

class ExcelService {
  // ── Public entry point ───────────────────────────────────────
  /// Builds and saves an analysis .xlsx file for the given [months].
  /// [months] is a list of (year, month) records.
  /// [allTransactions] is the full transaction list (provider data).
  /// Returns the saved file path, or null if cancelled.
  static Future<String?> exportAnalysis({
    required List<({int year, int month})> months,
    required List<Transaction> allTransactions,
    required String Function(double) formatCurrency,
  }) async {
    // Filter transactions to requested months
    final txns = allTransactions.where((t) {
      return months.any((m) => t.date.year == m.year && t.date.month == m.month);
    }).toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    final excel = Excel.createExcel();

    // Remove the automatically created default Sheet1
    excel.delete('Sheet1');

    _buildSummarySheet(excel, txns, months, formatCurrency);
    _buildTransactionsSheet(excel, txns, formatCurrency);
    _buildCategorySheet(excel, txns, months, formatCurrency);

    final bytes = excel.save();
    if (bytes == null) throw Exception('Failed to encode Excel file');

    // Build file name
    final sortedMonths = [...months]..sort((a, b) {
        final da = DateTime(a.year, a.month);
        final db = DateTime(b.year, b.month);
        return da.compareTo(db);
      });
    final String fileName;
    if (sortedMonths.length == 1) {
      final m = sortedMonths.first;
      fileName = '${DateFormat('MMM_yyyy').format(DateTime(m.year, m.month))}_analysis.xlsx';
    } else {
      final first = sortedMonths.first;
      final last  = sortedMonths.last;
      fileName =
          '${DateFormat('MMM_yyyy').format(DateTime(first.year, first.month))}'
          '-${DateFormat('MMM_yyyy').format(DateTime(last.year, last.month))}'
          '_analysis.xlsx';
    }

    final String? path = await FilePicker.platform.saveFile(
      dialogTitle: 'Save Analysis',
      fileName: fileName,
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
      bytes: Uint8List.fromList(bytes),
    );

    if (path != null && !path.contains('blob:')) {
      try {
        await File(path).writeAsBytes(Uint8List.fromList(bytes));
      } catch (_) {}
    }
    return path;
  }

  // ── Sheet 1: Summary ─────────────────────────────────────────
  static void _buildSummarySheet(
    Excel excel,
    List<Transaction> txns,
    List<({int year, int month})> months,
    String Function(double) fmt,
  ) {
    final sheet = excel['Summary'];

    // Title row
    _writeCell(sheet, 0, 0, 'Month', bold: true, bgHex: '1E293B', fgHex: 'F8FAFC');
    _writeCell(sheet, 0, 1, 'Income', bold: true, bgHex: '1E293B', fgHex: '4ADE80');
    _writeCell(sheet, 0, 2, 'Expenses', bold: true, bgHex: '1E293B', fgHex: 'F87171');
    _writeCell(sheet, 0, 3, 'Net', bold: true, bgHex: '1E293B', fgHex: 'F8FAFC');
    _writeCell(sheet, 0, 4, '# Transactions', bold: true, bgHex: '1E293B', fgHex: 'F8FAFC');

    final sortedMonths = [...months]..sort((a, b) {
        return DateTime(a.year, a.month).compareTo(DateTime(b.year, b.month));
      });

    int row = 1;
    double grandIncome = 0, grandExpense = 0;
    int grandCount = 0;

    for (final m in sortedMonths) {
      final mTxns = txns.where((t) => t.date.year == m.year && t.date.month == m.month).toList();
      final income  = mTxns.where((t) => !t.isExpense).fold(0.0, (s, t) => s + t.amount);
      final expense = mTxns.where((t) =>  t.isExpense).fold(0.0, (s, t) => s + t.amount);
      final net     = income - expense;
      final label   = DateFormat('MMMM yyyy').format(DateTime(m.year, m.month));

      final isEven = row.isEven;
      final rowBg  = isEven ? 'F1F5F9' : 'FFFFFF';

      _writeCell(sheet, row, 0, label, bgHex: rowBg);
      _writeCell(sheet, row, 1, fmt(income),   bgHex: rowBg, fgHex: '16A34A');
      _writeCell(sheet, row, 2, fmt(expense),  bgHex: rowBg, fgHex: 'DC2626');
      _writeCell(sheet, row, 3, fmt(net),      bgHex: rowBg, fgHex: net >= 0 ? '16A34A' : 'DC2626');
      _writeCell(sheet, row, 4, mTxns.length.toString(), bgHex: rowBg);

      grandIncome   += income;
      grandExpense  += expense;
      grandCount    += mTxns.length;
      row++;
    }

    // Totals row
    _writeCell(sheet, row, 0, 'TOTAL', bold: true, bgHex: '334155', fgHex: 'F8FAFC');
    _writeCell(sheet, row, 1, fmt(grandIncome),   bold: true, bgHex: '334155', fgHex: '4ADE80');
    _writeCell(sheet, row, 2, fmt(grandExpense),  bold: true, bgHex: '334155', fgHex: 'F87171');
    _writeCell(sheet, row, 3, fmt(grandIncome - grandExpense), bold: true, bgHex: '334155',
        fgHex: grandIncome >= grandExpense ? '4ADE80' : 'F87171');
    _writeCell(sheet, row, 4, grandCount.toString(), bold: true, bgHex: '334155', fgHex: 'F8FAFC');

    // Column widths
    sheet.setColumnWidth(0, 20);
    sheet.setColumnWidth(1, 18);
    sheet.setColumnWidth(2, 18);
    sheet.setColumnWidth(3, 18);
    sheet.setColumnWidth(4, 16);
  }

  // ── Sheet 2: All Transactions ────────────────────────────────
  static void _buildTransactionsSheet(
    Excel excel,
    List<Transaction> txns,
    String Function(double) fmt,
  ) {
    final sheet = excel['Transactions'];

    final headers = ['Date', 'Description', 'Store / Vendor', 'Category', 'Type', 'Amount', 'Account', 'Notes'];
    for (var c = 0; c < headers.length; c++) {
      _writeCell(sheet, 0, c, headers[c], bold: true, bgHex: '1E293B', fgHex: 'F8FAFC');
    }

    for (var i = 0; i < txns.length; i++) {
      final t = txns[i];
      final row     = i + 1;
      final isEven  = row.isEven;
      final rowBg   = isEven ? 'F1F5F9' : 'FFFFFF';
      final typeFg  = t.isExpense ? 'DC2626' : '16A34A';
      final amtFg   = t.isExpense ? 'DC2626' : '16A34A';

      _writeCell(sheet, row, 0, DateFormat('dd MMM yyyy').format(t.date), bgHex: rowBg);
      _writeCell(sheet, row, 1, t.title,    bgHex: rowBg);
      _writeCell(sheet, row, 2, t.storeName, bgHex: rowBg);
      _writeCell(sheet, row, 3, t.category,  bgHex: rowBg);
      _writeCell(sheet, row, 4, t.isExpense ? 'Expense' : 'Income', bgHex: rowBg, fgHex: typeFg);
      _writeCell(sheet, row, 5, fmt(t.amount), bgHex: rowBg, fgHex: amtFg, bold: true);
      _writeCell(sheet, row, 6, t.accountId ?? '-', bgHex: rowBg);
      _writeCell(sheet, row, 7, t.notes ?? '', bgHex: rowBg);
    }

    // Column widths
    sheet.setColumnWidth(0, 14);
    sheet.setColumnWidth(1, 30);
    sheet.setColumnWidth(2, 22);
    sheet.setColumnWidth(3, 16);
    sheet.setColumnWidth(4, 10);
    sheet.setColumnWidth(5, 16);
    sheet.setColumnWidth(6, 14);
    sheet.setColumnWidth(7, 28);
  }

  // ── Sheet 3: Category Breakdown ──────────────────────────────
  static void _buildCategorySheet(
    Excel excel,
    List<Transaction> txns,
    List<({int year, int month})> months,
    String Function(double) fmt,
  ) {
    final sheet = excel['Category Breakdown'];

    // Collect all expense categories
    final categories = txns
        .where((t) => t.isExpense)
        .map((t) => t.category)
        .toSet()
        .toList()
      ..sort();

    // Header
    _writeCell(sheet, 0, 0, 'Category', bold: true, bgHex: '1E293B', fgHex: 'F8FAFC');
    final sortedMonths = [...months]..sort((a, b) {
        return DateTime(a.year, a.month).compareTo(DateTime(b.year, b.month));
      });
    for (var c = 0; c < sortedMonths.length; c++) {
      final m = sortedMonths[c];
      final label = DateFormat('MMM yy').format(DateTime(m.year, m.month));
      _writeCell(sheet, 0, c + 1, label, bold: true, bgHex: '1E293B', fgHex: 'F8FAFC');
    }
    _writeCell(sheet, 0, sortedMonths.length + 1, 'TOTAL', bold: true, bgHex: '1E293B', fgHex: 'F8FAFC');

    // Build totals map: category → month → amount
    final Map<String, Map<String, double>> catMonthMap = {};
    for (final t in txns.where((t) => t.isExpense)) {
      final key = DateFormat('yyyy-MM').format(t.date);
      catMonthMap.putIfAbsent(t.category, () => {});
      catMonthMap[t.category]![key] = (catMonthMap[t.category]![key] ?? 0) + t.amount;
    }

    // Sort categories by total descending
    final sortedCats = categories.toList()
      ..sort((a, b) {
        final ta = catMonthMap[a]?.values.fold(0.0, (s, v) => s + v) ?? 0;
        final tb = catMonthMap[b]?.values.fold(0.0, (s, v) => s + v) ?? 0;
        return tb.compareTo(ta);
      });

    for (var r = 0; r < sortedCats.length; r++) {
      final cat   = sortedCats[r];
      final row   = r + 1;
      final isEven = row.isEven;
      final rowBg  = isEven ? 'F1F5F9' : 'FFFFFF';

      _writeCell(sheet, row, 0, cat, bgHex: rowBg, bold: true);
      double rowTotal = 0;
      for (var c = 0; c < sortedMonths.length; c++) {
        final m     = sortedMonths[c];
        final mKey  = DateFormat('yyyy-MM').format(DateTime(m.year, m.month));
        final amt   = catMonthMap[cat]?[mKey] ?? 0;
        _writeCell(sheet, row, c + 1, amt > 0 ? fmt(amt) : '-', bgHex: rowBg, fgHex: amt > 0 ? 'DC2626' : 'CBD5E1');
        rowTotal += amt;
      }
      _writeCell(sheet, row, sortedMonths.length + 1, fmt(rowTotal), bgHex: rowBg, fgHex: 'DC2626', bold: true);
    }

    // Column widths
    sheet.setColumnWidth(0, 20);
    for (var c = 1; c <= sortedMonths.length + 1; c++) {
      sheet.setColumnWidth(c, 14);
    }
  }

  // ── Cell writer helper ────────────────────────────────────────
  static void _writeCell(
    Sheet sheet,
    int row,
    int col,
    String value, {
    bool bold = false,
    String? bgHex,
    String? fgHex,
  }) {
    final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row));
    cell.value = TextCellValue(value);

    var style = CellStyle(
      bold: bold,
      verticalAlign: VerticalAlign.Center,
    );

    if (bgHex != null) {
      style = style.copyWith(backgroundColorHexVal: ExcelColor.fromHexString('#$bgHex'));
    }
    if (fgHex != null) {
      style = style.copyWith(fontColorHexVal: ExcelColor.fromHexString('#$fgHex'));
    }

    cell.cellStyle = style;
  }
}
