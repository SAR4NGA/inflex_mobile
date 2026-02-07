class TransactionItem {
  final int id;
  final String type;

  final double amount;
  final DateTime date;
  final String note;
  final int categoryId;
  final String categoryName;

  TransactionItem({
    required this.id,
    required this.type,
    required this.amount,
    required this.date,
    required this.note,
    required this.categoryId,
    required this.categoryName,
  });

  factory TransactionItem.fromJson(Map<String, dynamic> json) {
    return TransactionItem(
      id: json['id'] as int,
      type: (json['type'] ?? '').toString(),

      amount: (json['amount'] as num).toDouble(),
      date: DateTime.parse(json['date'] as String),
      note: (json['note'] ?? '').toString(),
      categoryId: json['categoryId'] as int,
      categoryName: (json['categoryName'] ?? '').toString(),
    );
  }
}
