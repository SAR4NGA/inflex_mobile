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
  String _type = 'Expense';
  bool _saving = false;

  // Categories state
  bool _loadingCats = true;
  String? _catError;
  List<Category> _categories = [];
  int? _selectedCategoryId;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
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
        _selectedCategoryId = cats.isNotEmpty ? cats.first.id : null;
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

    if (_selectedCategoryId == null) {
      _show('Please select a category');
      return;
    }

    setState(() => _saving = true);

    try {
      await TransactionService.addTransaction(
        type: _type,
        amount: amount,
        date: _date,
        categoryId: _selectedCategoryId!,
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
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
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

            const SizedBox(height: 16),

            // Category dropdown
            _buildCategorySection(),

            const SizedBox(height: 16),

            // Amount field
            TextField(
              controller: _amountCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Amount',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 16),

            // Note field
            TextField(
              controller: _noteCtrl,
              decoration: const InputDecoration(
                labelText: 'Note (optional)',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 16),

            // Date picker
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

                    if (picked != null) {
                      setState(() => _date = picked);
                    }
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
                    ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
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
          Expanded(child: Text('Failed: $_catError')),
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
        Expanded(
          child: DropdownButton<int>(
            isExpanded: true,
            value: _selectedCategoryId,
            items: _categories
                .map(
                  (c) => DropdownMenuItem<int>(
                value: c.id,
                child: Text(
                  c.name,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            )
                .toList(),
            onChanged: (v) => setState(() => _selectedCategoryId = v),
          ),
        ),
      ],
    );
  }
}
