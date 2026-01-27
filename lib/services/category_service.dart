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
}
