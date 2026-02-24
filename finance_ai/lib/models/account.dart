import 'package:hive/hive.dart';

enum AccountType { bank, eWallet, cash, card }

@HiveType(typeId: 2)
class Account extends HiveObject {
  @HiveField(0)
  late String id;

  @HiveField(1)
  late String name;

  @HiveField(2)
  late String type; // 'Bank' | 'E-Wallet' | 'Cash' | 'Card'

  @HiveField(3)
  late double balance;

  @HiveField(4)
  late String colorHex; // e.g. '#00D084'

  @HiveField(5)
  late String iconName; // e.g. 'account_balance', 'wallet', 'payments'

  @HiveField(6)
  late String currency; // e.g. 'MYR', 'USD'

  Account({
    required this.id,
    required this.name,
    required this.type,
    required this.balance,
    required this.colorHex,
    required this.iconName,
    this.currency = 'MYR',
  });
}

// ──────────────────────────
// Account Types & Defaults
// ──────────────────────────
class AccountConfig {
  static const List<String> types = ['Bank', 'E-Wallet', 'Cash', 'Card'];

  static const Map<String, String> typeIcons = {
    'Bank':     'account_balance',
    'E-Wallet': 'account_balance_wallet',
    'Cash':     'payments',
    'Card':     'credit_card',
  };

  static const Map<String, String> typeColors = {
    'Bank':     '#3B82F6',
    'E-Wallet': '#8B5CF6',
    'Cash':     '#10B981',
    'Card':     '#F59E0B',
  };
}

// ──────────────────────────
// Hive TypeAdapter (manual)
// ──────────────────────────
class AccountAdapter extends TypeAdapter<Account> {
  @override
  final int typeId = 2;

  @override
  Account read(BinaryReader reader) {
    return Account(
      id:       reader.readString(),
      name:     reader.readString(),
      type:     reader.readString(),
      balance:  reader.readDouble(),
      colorHex: reader.readString(),
      iconName: reader.readString(),
      currency: reader.availableBytes > 0 ? reader.readString() : 'MYR',
    );
  }

  @override
  void write(BinaryWriter writer, Account obj) {
    writer.writeString(obj.id);
    writer.writeString(obj.name);
    writer.writeString(obj.type);
    writer.writeDouble(obj.balance);
    writer.writeString(obj.colorHex);
    writer.writeString(obj.iconName);
    writer.writeString(obj.currency);
  }
}
