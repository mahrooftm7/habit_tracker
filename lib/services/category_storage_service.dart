import 'package:shared_preferences/shared_preferences.dart';

class CategoryStorageService {
  static const String _categoriesPrefix = 'finance_categories_v1_';

  final List<String> defaultCategories = [
    'Salary',
    'Freelance',
    'Food & Groceries',
    'Bills & Utilities',
    'Transport / Fuel',
    'Shopping',
    'Entertainment',
    'Health',
    'Other',
  ];

  Future<List<String>> loadCategories(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_categoriesPrefix$userId';
    final saved = prefs.getStringList(key);

    if (saved == null || saved.isEmpty) {
      await saveCategories(userId, defaultCategories);
      return List<String>.from(defaultCategories);
    }
    return saved;
  }

  Future<void> saveCategories(String userId, List<String> categories) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_categoriesPrefix$userId';
    await prefs.setStringList(key, categories);
  }

  Future<List<String>> addCategory(String userId, String categoryName) async {
    final trimmed = categoryName.trim();
    if (trimmed.isEmpty) return await loadCategories(userId);

    final categories = await loadCategories(userId);
    if (!categories.any((c) => c.toLowerCase() == trimmed.toLowerCase())) {
      categories.add(trimmed);
      await saveCategories(userId, categories);
    }
    return categories;
  }

  Future<List<String>> deleteCategory(String userId, String categoryName) async {
    final categories = await loadCategories(userId);
    categories.removeWhere((c) => c.toLowerCase() == categoryName.trim().toLowerCase());
    await saveCategories(userId, categories);
    return categories;
  }
}
