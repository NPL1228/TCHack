import 'package:hive/hive.dart';

@HiveType(typeId: 0)
class Transaction extends HiveObject {
  @HiveField(0)
  late String id;

  @HiveField(1)
  late String title;

  @HiveField(2)
  late String storeName;

  @HiveField(3)
  late double amount;

  @HiveField(4)
  late String category;

  @HiveField(5)
  late DateTime date;

  @HiveField(6)
  late String currency;

  @HiveField(7)
  late bool isExpense;

  @HiveField(8)
  String? notes;

  @HiveField(9)
  List<String>? items;

  @HiveField(10)
  String? receiptImagePath;

  @HiveField(11)
  double? carbonFootprint; // legacy field – kept for binary compat

  @HiveField(12)
  String? accountId;

  @HiveField(13)
  bool isTransfer;

  @HiveField(14)
  String? transferToAccountId;
  @HiveField(15)
  bool isRecurring;

  @HiveField(16)
  String? recurringPeriod; // 'daily', 'weekly', 'monthly', 'yearly'

  @HiveField(17)
  DateTime? recurringNextDate;

  @HiveField(18)
  String? subcategory;

  Transaction({
    required this.id,
    required this.title,
    required this.storeName,
    required this.amount,
    required this.category,
    required this.date,
    this.currency = 'RM',
    this.isExpense = true,
    this.notes,
    this.items,
    this.receiptImagePath,
    this.accountId,
    this.isTransfer = false,
    this.transferToAccountId,
    this.isRecurring = false,
    this.recurringPeriod,
    this.recurringNextDate,
    this.subcategory,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'storeName': storeName,
    'amount': amount,
    'category': category,
    'date': date.toIso8601String(),
    'currency': currency,
    'isExpense': isExpense,
    'notes': notes,
    'items': items,
    'accountId': accountId,
    'isTransfer': isTransfer,
    'transferToAccountId': transferToAccountId,
  };

  factory Transaction.fromJson(Map<String, dynamic> json) => Transaction(
    id: json['id'],
    title: json['title'],
    storeName: json['storeName'] ?? '',
    amount: (json['amount'] as num).toDouble(),
    category: json['category'] ?? 'Other',
    date: DateTime.parse(json['date']),
    currency: json['currency'] ?? 'RM',
    isExpense: json['isExpense'] ?? true,
    notes: json['notes'],
    items: json['items'] != null ? List<String>.from(json['items']) : null,
    accountId: json['accountId'],
    isTransfer: json['isTransfer'] ?? false,
    transferToAccountId: json['transferToAccountId'],
  );
}

// ──────────────────────────
// Hive TypeAdapter (manual)
// ──────────────────────────
class TransactionAdapter extends TypeAdapter<Transaction> {
  @override
  final int typeId = 0;

  @override
  Transaction read(BinaryReader reader) {
    final id            = reader.readString();
    final title         = reader.readString();
    final storeName     = reader.readString();
    final amount        = reader.readDouble();
    final category      = reader.readString();
    final date          = DateTime.fromMillisecondsSinceEpoch(reader.readInt());
    final currency      = reader.readString();
    final isExpense     = reader.readBool();
    final notes         = reader.readBool() ? reader.readString() : null;
    final items         = reader.readBool() ? List<String>.from(reader.readList()) : null;
    final receiptPath   = reader.readBool() ? reader.readString() : null;
    // Legacy carbonFootprint field – read and discard
    if (reader.readBool()) reader.readDouble();
    final accountId     = reader.availableBytes > 0
                            ? (reader.readBool() ? reader.readString() : null)
                            : null;
    final isTransfer    = reader.availableBytes > 0 ? reader.readBool() : false;
    final transferToId  = reader.availableBytes > 0
                            ? (reader.readBool() ? reader.readString() : null)
                            : null;
    final isRecurring   = reader.availableBytes > 0 ? reader.readBool() : false;
    final recurPeriod   = reader.availableBytes > 0
                            ? (reader.readBool() ? reader.readString() : null)
                            : null;
    final recurNext     = reader.availableBytes > 0
                            ? (reader.readBool() ? DateTime.fromMillisecondsSinceEpoch(reader.readInt()) : null)
                            : null;
    final subcategory   = reader.availableBytes > 0
                            ? (reader.readBool() ? reader.readString() : null)
                            : null;
    return Transaction(
      id: id, title: title, storeName: storeName, amount: amount,
      category: category, date: date, currency: currency,
      isExpense: isExpense, notes: notes, items: items,
      receiptImagePath: receiptPath, accountId: accountId,
      isTransfer: isTransfer, transferToAccountId: transferToId,
      isRecurring: isRecurring, recurringPeriod: recurPeriod,
      recurringNextDate: recurNext, subcategory: subcategory,
    );
  }

  @override
  void write(BinaryWriter writer, Transaction obj) {
    writer.writeString(obj.id);
    writer.writeString(obj.title);
    writer.writeString(obj.storeName);
    writer.writeDouble(obj.amount);
    writer.writeString(obj.category);
    writer.writeInt(obj.date.millisecondsSinceEpoch);
    writer.writeString(obj.currency);
    writer.writeBool(obj.isExpense);
    writer.writeBool(obj.notes != null);     if (obj.notes != null) writer.writeString(obj.notes!);
    writer.writeBool(obj.items != null);     if (obj.items != null) writer.writeList(obj.items!);
    writer.writeBool(obj.receiptImagePath != null); if (obj.receiptImagePath != null) writer.writeString(obj.receiptImagePath!);
    
    // Legacy carbon footprint (always false now)
    writer.writeBool(false);
    
    // Account ID handling
    writer.writeBool(obj.accountId != null);
    if (obj.accountId != null) writer.writeString(obj.accountId!);

    // Transfers
    writer.writeBool(obj.isTransfer);
    writer.writeBool(obj.transferToAccountId != null);
    if (obj.transferToAccountId != null) writer.writeString(obj.transferToAccountId!);
    
    // Future expansion: we'll add recurring/subcategory blocks later during their features
    writer.writeBool(obj.isRecurring);
    writer.writeBool(obj.recurringPeriod != null); if (obj.recurringPeriod != null) writer.writeString(obj.recurringPeriod!);
    writer.writeBool(obj.recurringNextDate != null); if (obj.recurringNextDate != null) writer.writeInt(obj.recurringNextDate!.millisecondsSinceEpoch);
    writer.writeBool(obj.subcategory != null); if (obj.subcategory != null) writer.writeString(obj.subcategory!);
  }
}
