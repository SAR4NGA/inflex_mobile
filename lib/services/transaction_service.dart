import '../models/transaction.dart';
import 'api_client.dart';

class TransactionService {
  static Future<List<TransactionItem>> getTransactions({
    int page = 1,
    int pageSize = 20,
  }) async {
    final res = await ApiClient.get('api/transactions?page=$page&pageSize=$pageSize');

    // Your API returns: { success, message, data: { transactions: [...] } }
    final data = (res as Map<String, dynamic>)['data'] as Map<String, dynamic>?;

    final txList = (data?['transactions'] as List?) ?? [];

    return txList
        .map((e) => TransactionItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }
  static Future<void> addTransaction({
    required String type,
    required double amount,
    required DateTime date,
    required int categoryId,
    String? note,
  }) async {
    await ApiClient.post(
      'api/transactions',
      body: {
        'type': type,             // ✅ Income / Expense
        'amount': amount,
        'date': date.toIso8601String(),
        'categoryId': categoryId,
        'userId': 'ignored',      // required by DTO validation, controller ignores it
        'note': note ?? '',
      },
    );

  }
  static Future<void> deleteTransaction(int id) async {
    await ApiClient.delete('api/transactions/$id');
  }

}


