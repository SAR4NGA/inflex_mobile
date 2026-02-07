import '../models/category.dart';
import 'api_client.dart';

class CategoryService {
  static Future<List<Category>> getCategories() async {
    final data = await ApiClient.get('api/categories');

    // Expecting: a JSON array
    final list = (data as List).cast<dynamic>();

    return list
        .map((e) => Category.fromJson(e as Map<String, dynamic>))
        .toList();
  }
  static Future<Map<int, String>> getCategoryTypeMap() async {
    final cats = await getCategories();
    return {for (final c in cats) c.id: c.type};
  }
  static Future<void> addCategory({
    required String name,
    required String type, // "Income" or "Expense"
  }) async {
    await ApiClient.post(
      'api/categories',
      body: {'name': name, 'type': type},
    );
  }

  static Future<void> deleteCategory(int id) async {
    await ApiClient.delete('api/categories/$id');
  }


}
