import 'package:flutter/material.dart';
import '../models/category.dart';
import '../services/category_service.dart';
import '../services/transaction_service.dart';

class AddTransactionScreen extends StatefulWidget {
  const AddTransactionScreen({super.key});

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();

  DateTime _date = DateTime.now();
  String _type = 'Expense'; // default
  bool _saving = false;

  bool _loadingCats = true;
  String? _catError;
  List<Category> _categories = [];
  Category? _selectedCategory;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    setState(() {
      _loadingCats = true;
      _catError = null;
    });

    try {
      final cats = await CategoryService.getCategories();
      setState(() {
        _categories = cats;
        _selectedCategory = cats.isNotEmpty ? cats.first : null;
        _loadingCats = false;
      });
    } catch (e) {
      setState(() {
        _catError = e.toString();
        _loadingCats = false;
      });
    }
  }

  Future<void> _save() async {
    final amount = double.tryParse(_amountCtrl.text);
    if (amount == null || amount <= 0) {
      _show('Enter a valid amount');
      return;
    }

    if (_selectedCategory == null) {
      _show('Please select a category');
      return;
    }

    setState(() => _saving = true);

    try {
      await TransactionService.addTransaction(
        type: _type,
        amount: amount,
        date: _date,
        categoryId: _selectedCategory!.id,
        note: _noteCtrl.text,
      );

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      _show(e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _show(String msg) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Error'),
        content: Text(msg),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Transaction')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Type picker
            Row(
              children: [
                const Text('Type:'),
                const SizedBox(width: 12),
                DropdownButton<String>(
                  value: _type,
                  items: const [
                    DropdownMenuItem(value: 'Expense', child: Text('Expense')),
                    DropdownMenuItem(value: 'Income', child: Text('Income')),
                  ],
                  onChanged: (v) {
                    if (v != null) setState(() => _type = v);
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Category picker (from API)
            _buildCategorySection(),
            const SizedBox(height: 12),

            TextField(
              controller: _amountCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Amount'),
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _noteCtrl,
              decoration: const InputDecoration(labelText: 'Note (optional)'),
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Text('Date: ${_date.toLocal().toString().split(' ')[0]}'),
                const Spacer(),
                TextButton(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _date,
                      firstDate: DateTime(2000),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) setState(() => _date = picked);
                  },
                  child: const Text('Pick'),
                ),
              ],
            ),

            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator())
                    : const Text('Save'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategorySection() {
    if (_loadingCats) {
      return const Row(
        children: [
          Text('Category:'),
          SizedBox(width: 12),
          SizedBox(height: 16, width: 16, child: CircularProgressIndicator()),
        ],
      );
    }

    if (_catError != null) {
      return Row(
        children: [
          const Text('Category:'),
          const SizedBox(width: 12),
          Expanded(child: Text('Failed to load categories')),
          TextButton(
            onPressed: _loadCategories,
            child: const Text('Retry'),
          ),
        ],
      );
    }

    if (_categories.isEmpty) {
      return const Row(
        children: [
          Text('Category:'),
          SizedBox(width: 12),
          Text('No categories found'),
        ],
      );
    }

    return Row(
      children: [
        const Text('Category:'),
        const SizedBox(width: 12),
        DropdownButton<Category>(
          value: _selectedCategory,
          items: _categories
              .map((c) => DropdownMenuItem(
            value: c,
            child: Text(c.name),
          ))
              .toList(),
          onChanged: (v) {
            setState(() => _selectedCategory = v);
          },
        ),
      ],
    );
  }
}
