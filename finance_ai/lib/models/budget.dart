import 'package:hive/hive.dart';

@HiveType(typeId: 1)
class Budget extends HiveObject {
  @HiveField(0)
  late String category;

  @HiveField(1)
  late double monthlyLimit;

  @HiveField(2)
  late int month;

  @HiveField(3)
  late int year;

  Budget({
    required this.category,
    required this.monthlyLimit,
    required this.month,
    required this.year,
  });

  Map<String, dynamic> toJson() => {
    'category': category,
    'monthlyLimit': monthlyLimit,
    'month': month,
    'year': year,
  };

  factory Budget.fromJson(Map<String, dynamic> json) => Budget(
    category: json['category'],
    monthlyLimit: (json['monthlyLimit'] as num).toDouble(),
    month: json['month'],
    year: json['year'],
  );
}

// ──────────────────────────
// Hive TypeAdapter (manual)
// ──────────────────────────
class BudgetAdapter extends TypeAdapter<Budget> {
  @override
  final int typeId = 1;

  @override
  Budget read(BinaryReader reader) {
    return Budget(
      category:     reader.readString(),
      monthlyLimit: reader.readDouble(),
      month:        reader.readInt(),
      year:         reader.readInt(),
    );
  }

  @override
  void write(BinaryWriter writer, Budget obj) {
    writer.writeString(obj.category);
    writer.writeDouble(obj.monthlyLimit);
    writer.writeInt(obj.month);
    writer.writeInt(obj.year);
  }
}
