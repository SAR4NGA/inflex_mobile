class Category {
  final int id;
  final String name;
  final String type; // e.g. "Income" / "Expense" (API has it in the model)

  Category({
    required this.id,
    required this.name,
    required this.type,
  });

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'] as int,
      name: json['name'] as String,
      type: (json['type'] ?? '').toString(),
    );
  }
}
