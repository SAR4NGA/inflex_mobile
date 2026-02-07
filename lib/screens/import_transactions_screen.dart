import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';

import '../models/category.dart';
import '../services/category_service.dart';
import '../services/transaction_service.dart';

class ImportTransactionsScreen extends StatefulWidget {
  const ImportTransactionsScreen({super.key});

  @override
  State<ImportTransactionsScreen> createState() => _ImportTransactionsScreenState();
}

class _ImportTransactionsScreenState extends State<ImportTransactionsScreen> {
  bool _loading = false;
  String? _error;

  List<_CsvTx> _rows = [];
  Map<String, Category> _categoryByName = {};

  int _imported = 0;
  int _failed = 0;

  Future<void> _pickAndParse() async {
    setState(() {
      _error = null;
      _rows = [];
      _imported = 0;
      _failed = 0;
    });

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
      withData: true,
    );

    if (result == null || result.files.isEmpty) return;

    final bytes = result.files.single.bytes;
    if (bytes == null) {
      setState(() => _error = 'Could not read file bytes.');
      return;
    }

    final text = utf8.decode(bytes);
    final table = const CsvToListConverter(eol: '\n').convert(text);

    if (table.isEmpty) {
      setState(() => _error = 'CSV is empty.');
      return;
    }

    // Expect header row
    final header = table.first.map((e) => e.toString().trim().toLowerCase()).toList();
    int idx(String name) => header.indexOf(name);

    final iDate = idx('date');
    final iAmount = idx('amount');
    final iCategory = idx('category');
    final iNote = idx('note');

    if (iDate == -1 || iAmount == -1 || iCategory == -1) {
      setState(() => _error = 'CSV must contain headers: date, amount, category (note optional).');
      return;
    }

    final parsed = <_CsvTx>[];
    for (var r = 1; r < table.length; r++) {
      final row = table[r];
      if (row.isEmpty) continue;

      try {
        final dateStr = row[iDate].toString().trim();
        final amountStr = row[iAmount].toString().trim();
        final catName = row[iCategory].toString().trim();
        final note = (iNote == -1) ? '' : row[iNote].toString();

        if (dateStr.isEmpty || amountStr.isEmpty || catName.isEmpty) continue;

        final date = DateTime.parse(dateStr);
        final amount = double.parse(amountStr);

        parsed.add(_CsvTx(date: date, amount: amount, categoryName: catName, note: note));
      } catch (_) {
        // skip bad row
        continue;
      }
    }

    if (parsed.isEmpty) {
      setState(() => _error = 'No valid rows found. Check date format (YYYY-MM-DD) and amount.');
      return;
    }

    // Load categories once so we can map "category name" -> categoryId
    setState(() => _loading = true);
    try {
      final cats = await CategoryService.getCategories();
      _categoryByName = {
        for (final c in cats) c.name.trim().toLowerCase(): c,
      };

      setState(() {
        _rows = parsed;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _import() async {
    if (_rows.isEmpty) return;

    setState(() {
      _loading = true;
      _error = null;
      _imported = 0;
      _failed = 0;
    });

    // Optional: auto-create categories that don't exist
    // Set to false if you want strict behavior.
    const autoCreateMissingCategories = true;

    for (final tx in _rows) {
      try {
        final key = tx.categoryName.trim().toLowerCase();
        Category? cat = _categoryByName[key];

        if (cat == null) {
          if (!autoCreateMissingCategories) {
            _failed++;
            continue;
          }

          // Default missing categories to Expense; you can improve this later
          await CategoryService.addCategory(name: tx.categoryName.trim(), type: 'Expense');
          final refreshed = await CategoryService.getCategories();
          _categoryByName = {
            for (final c in refreshed) c.name.trim().toLowerCase(): c,
          };
          cat = _categoryByName[key];
          if (cat == null) {
            _failed++;
            continue;
          }
        }

        await TransactionService.addTransaction(

          amount: tx.amount,
          type: cat.type,
          date: tx.date,
          categoryId: cat.id,
          note: tx.note,
        );

        _imported++;
      } catch (_) {
        _failed++;
      }

      if (mounted) setState(() {});
    }

    if (!mounted) return;
    setState(() => _loading = false);

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Import finished'),
        content: Text('Imported: $_imported\nFailed: $_failed'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final preview = _rows.take(5).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Import from CSV'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton.icon(
              onPressed: _loading ? null : _pickAndParse,
              icon: const Icon(Icons.upload_file),
              label: const Text('Pick CSV file'),
            ),
            const SizedBox(height: 12),

            if (_loading) const LinearProgressIndicator(),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],

            const SizedBox(height: 12),
            Text('Rows loaded: ${_rows.length}'),
            Text('Imported: $_imported   Failed: $_failed'),

            const SizedBox(height: 12),
            if (preview.isNotEmpty) ...[
              const Text('Preview (first 5):', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ...preview.map((t) => Text(
                '${t.date.toIso8601String().split("T")[0]} • ${t.amount} • ${t.categoryName} • ${t.note}',
              )),
            ],

            const Spacer(),
            ElevatedButton(
              onPressed: (_loading || _rows.isEmpty) ? null : _import,
              child: const Text('Import Transactions'),
            ),
          ],
        ),
      ),
    );
  }
}

class _CsvTx {
  final DateTime date;
  final double amount;
  final String categoryName;
  final String note;

  _CsvTx({
    required this.date,
    required this.amount,
    required this.categoryName,
    required this.note,
  });
}
