import 'package:hive_flutter/hive_flutter.dart';

/// Built-in + user-created subcategories.
/// Stored in Hive as Map<String, List<String>>.
class SubcategoryService {
  static const _boxName = 'subcategories';

  static final Map<String, List<String>> _defaults = {
    'Food & Dining':  ['Breakfast', 'Lunch', 'Dinner', 'Coffee', 'Snacks', 'Delivery'],
    'Transport':      ['Grab', 'Petrol', 'Parking', 'Toll', 'Public Transit'],
    'Groceries':      ['Fresh Produce', 'Beverages', 'Household', 'Snacks'],
    'Shopping':       ['Clothing', 'Electronics', 'Online', 'Accessories'],
    'Health':         ['Pharmacy', 'Doctor', 'Gym', 'Vitamins'],
    'Utilities':      ['Electric', 'Water', 'Internet', 'Phone'],
    'Entertainment':  ['Movies', 'Games', 'Music', 'Events'],
    'Subscriptions':  ['Streaming', 'Software', 'News', 'Cloud Storage'],
    'Education':      ['Tuition', 'Books', 'Courses', 'Stationery'],
  };

  static Box<dynamic>? _box;
  static Box<dynamic> get _b {
    assert(_box != null, 'SubcategoryService.open() was not called');
    return _box!;
  }

  static Future<void> open() async {
    _box = await Hive.openBox<dynamic>(_boxName);
    // Seed defaults if empty
    for (final entry in _defaults.entries) {
      if (!_b.containsKey(entry.key)) {
        await _b.put(entry.key, entry.value);
      }
    }
  }

  static List<String> subcategoriesFor(String category) {
    final raw = _b.get(category);
    if (raw == null) return [];
    return List<String>.from(raw as List);
  }

  static Future<void> addSubcategory(String category, String name) async {
    final list = subcategoriesFor(category);
    if (!list.contains(name)) {
      list.add(name);
      await _b.put(category, list);
    }
  }

  static Future<void> removeSubcategory(String category, String name) async {
    final list = subcategoriesFor(category);
    list.remove(name);
    await _b.put(category, list);
  }

  static Map<String, List<String>> allSubcategories() {
    final result = <String, List<String>>{};
    for (final key in _b.keys) {
      result[key as String] = List<String>.from(_b.get(key) as List);
    }
    return result;
  }
}
