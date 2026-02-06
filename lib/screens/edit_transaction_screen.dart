import 'package:flutter/material.dart';

import '../models/transaction.dart';
import '../models/category.dart';
import '../services/category_service.dart';
import '../services/transaction_service.dart';

class EditTransactionScreen extends StatefulWidget {
  final TransactionItem transaction;

  const EditTransactionScreen({super.key, required this.transaction});

  @override
  State<EditTransactionScreen> createState() => _EditTransactionScreenState();
}

class _EditTransactionScreenState extends State<EditTransactionScreen> {
  late TextEditingController _amountCtrl;
  late TextEditingController _noteCtrl;

  DateTime _date = DateTime.now();
  bool _saving = false;

  List<Category> _categories = [];
  int? _selectedCategoryId;

  @override
  void initState() {
    super.initState();

    _amountCtrl =
        TextEditingController(text: widget.transaction.amount.toString());
    _noteCtrl = TextEditingController(text: widget.transaction.note);
    _date = widget.transaction.date;

    _loadCategories();
  }

  Future<void> _loadCategories() async {
    final cats = await CategoryService.getCategories();
    setState(() {
      _categories = cats;
      _selectedCategoryId = widget.transaction.categoryId;
    });
  }

  Future<void> _save() async {
    final amount = double.tryParse(_amountCtrl.text);
    if (amount == null || amount <= 0) {
      _show('Enter a valid amount');
      return;
    }

    if (_selectedCategoryId == null) {
      _show('Select a category');
      return;
    }

    setState(() => _saving = true);

    try {
      await TransactionService.updateTransaction(
        id: widget.transaction.id,
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
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Transaction')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _amountCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Amount'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _noteCtrl,
              decoration: const InputDecoration(labelText: 'Note'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Text(_date.toLocal().toString().split(' ')[0]),
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
                  child: const Text('Pick Date'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              value: _selectedCategoryId,
              decoration: const InputDecoration(labelText: 'Category'),
              items: _categories
                  .map(
                    (c) => DropdownMenuItem<int>(
                  value: c.id,
                  child: Text(c.name),
                ),
              )
                  .toList(),
              onChanged: (v) => setState(() => _selectedCategoryId = v),
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const CircularProgressIndicator()
                  : const Text('Save Changes'),
            ),
          ],
        ),
      ),
    );
  }
}
