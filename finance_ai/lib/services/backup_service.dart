import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/account.dart';
import '../models/transaction.dart';
import '../models/budget.dart';

/// Service responsible for generating and parsing Full App Data Backups in JSON format.
class BackupService {
  /// Packages the entire active Hive database into a JSON string.
  static String exportBackup({
    required List<Account> accounts,
    required List<Transaction> transactions,
    required List<Budget> budgets,
  }) {
    final Map<String, dynamic> backupData = {
      'version': 1, // Schema version for future-proofing
      'exported_at': DateTime.now().toIso8601String(),
      'accounts': accounts.map((a) => {
        'id': a.id,
        'name': a.name,
        'type': a.type,
        'balance': a.balance,
        'colorHex': a.colorHex,
        'iconName': a.iconName,
        'currency': a.currency,
      }).toList(),
      'transactions': transactions.map((t) => t.toJson()).toList(),
      'budgets': budgets.map((b) => {
        'category': b.category,
        'monthlyLimit': b.monthlyLimit,
        'month': b.month,
        'year': b.year,
      }).toList(),
    };

    return jsonEncode(backupData);
  }

  /// Parses a given JSON string back into the discrete Hive entity lists.
  static Map<String, dynamic> importBackup(String jsonContent) {
    try {
      final Map<String, dynamic> data = jsonDecode(jsonContent);

      // Verify basic schema
      if (!data.containsKey('version') || data['version'] != 1) {
        throw const FormatException('Unsupported backup version.');
      }

      // Parse Accounts
      final parsedAccounts = <Account>[];
      if (data.containsKey('accounts')) {
        for (final accJson in data['accounts'] as List) {
          parsedAccounts.add(Account(
            id: accJson['id'],
            name: accJson['name'],
            type: accJson['type'],
            balance: (accJson['balance'] as num).toDouble(),
            colorHex: accJson['colorHex'],
            iconName: accJson['iconName'],
            currency: accJson['currency'] ?? 'MYR',
          ));
        }
      }

      // Parse Transactions
      final parsedTxns = <Transaction>[];
      if (data.containsKey('transactions')) {
        for (final txnJson in data['transactions'] as List) {
          parsedTxns.add(Transaction.fromJson(txnJson));
        }
      }

      // Parse Budgets
      final parsedBudgets = <Budget>[];
      if (data.containsKey('budgets')) {
        for (final bJson in data['budgets'] as List) {
          parsedBudgets.add(Budget(
            category: bJson['category'],
            monthlyLimit: (bJson['monthlyLimit'] as num).toDouble(),
            month: bJson['month'],
            year: bJson['year'],
          ));
        }
      }

      return {
        'accounts': parsedAccounts,
        'transactions': parsedTxns,
        'budgets': parsedBudgets,
      };
    } catch (e) {
      debugPrint('Backup Import Parsing Error: $e');
      throw const FormatException('Invalid or corrupted backup file.');
    }
  }
}
