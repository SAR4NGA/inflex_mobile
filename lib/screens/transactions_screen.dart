import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../models/transaction.dart';
import '../services/transaction_service.dart';
import '../services/category_service.dart';
import '../utils/csv_exporter.dart';

import 'add_transaction_screen.dart';
import 'edit_transaction_screen.dart';
import 'import_transactions_screen.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  bool _loading = true;
  String? _error;

  List<TransactionItem> _transactions = [];
  bool _showAll = false;

  // Categories (used for breakdown)
  Map<String, String> _typeByCategoryName = {};

  // Breakdown expand (separate from tx table)
  bool _showAllExpenses = false;
  bool _showAllIncome = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  String _formatDate(DateTime d) {
    final y = d.year.toString();
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _showAll = false;
      _showAllExpenses = false;
      _showAllIncome = false;
    });

    try {
      final cats = await CategoryService.getCategories();
      final tx = await TransactionService.getTransactions(page: 1, pageSize: 50);

      final map = <String, String>{};
      for (final c in cats) {
        map[c.name.trim().toLowerCase()] = c.type.trim();
      }

      setState(() {
        _typeByCategoryName = map;
        _transactions = tx;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _openImport() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ImportTransactionsScreen()),
    );
    _load(); // refresh after import
  }

  Future<void> _exportCsv() async {
    try {
      final tx = await TransactionService.getTransactions(page: 1, pageSize: 1000);
      final file = await CsvExporter.exportTransactions(tx);

      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Transactions export',
      );
    } catch (e) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (_) => const AlertDialog(
          title: Text('Export failed'),
          content: Text('Something went wrong. Please try again.'),
        ),
      );
    }
  }

  Future<bool> _confirmDeleteDialog() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete transaction?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    return confirm == true;
  }

  Future<void> _deleteTransaction(TransactionItem t) async {
    try {
      await TransactionService.deleteTransaction(t.id);
      await _load();
    } catch (e) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (_) => const AlertDialog(
          title: Text('Delete failed'),
          content: Text('Something went wrong. Please try again.'),
        ),
      );
    }
  }

  Future<void> _openAdd() async {
    final added = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddTransactionScreen()),
    );

    if (added == true) {
      _load();
    }
  }

  // ---------- Table UI helpers ----------

  Widget _tableHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      color: Colors.grey.shade200,
      child: const Row(
        children: [
          Expanded(
            flex: 2,
            child: Text('Date', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          Expanded(
            flex: 3,
            child: Text('Category', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          Expanded(
            flex: 4,
            child: Text('Note', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerRight,
              child: Text('Amount', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tableRow(TransactionItem t) {
    final dateText = _formatDate(t.date);
    final categoryText = t.categoryName.isEmpty ? 'Uncategorized' : t.categoryName;
    final noteText = t.note.isEmpty ? '-' : t.note;

    return InkWell(
      onTap: () async {
        final updated = await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => EditTransactionScreen(transaction: t)),
        );
        if (updated == true) _load();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Expanded(flex: 2, child: Text(dateText)),
            Expanded(
              flex: 3,
              child: Text(categoryText, overflow: TextOverflow.ellipsis),
            ),
            Expanded(
              flex: 4,
              child: Text(noteText, overflow: TextOverflow.ellipsis),
            ),
            Expanded(
              flex: 2,
              child: Align(
                alignment: Alignment.centerRight,
                child: Text(
                  t.amount.toStringAsFixed(2),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------- Breakdown helpers ----------

  String _categoryTypeFor(TransactionItem t) {
    final name = (t.categoryName.isEmpty ? 'Uncategorized' : t.categoryName)
        .trim()
        .toLowerCase();

    return _typeByCategoryName[name] ?? '';
  }

  List<_BreakdownRow> _expenseBreakdown() {
    final map = <String, double>{};

    for (final t in _transactions) {
      if (_categoryTypeFor(t) != 'Expense') continue;

      final name = (t.categoryName.isEmpty ? 'Uncategorized' : t.categoryName).trim();
      map[name] = (map[name] ?? 0) + t.amount; // expenses are positive in your app
    }

    final rows = map.entries
        .map((e) => _BreakdownRow(category: e.key, total: e.value))
        .toList();

    rows.sort((a, b) => b.total.compareTo(a.total));
    return rows;
  }

  List<_BreakdownRow> _incomeBreakdown() {
    final map = <String, double>{};

    for (final t in _transactions) {
      if (_categoryTypeFor(t) != 'Income') continue;

      final name = (t.categoryName.isEmpty ? 'Uncategorized' : t.categoryName).trim();
      map[name] = (map[name] ?? 0) + t.amount;
    }

    final rows = map.entries
        .map((e) => _BreakdownRow(category: e.key, total: e.value))
        .toList();

    rows.sort((a, b) => b.total.compareTo(a.total));
    return rows;
  }

  Widget _breakdownHeader(String title) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      color: Colors.grey.shade200,
      child: Row(
        children: [
          Expanded(
            child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          const Text('Total', style: TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _breakdownRow(_BreakdownRow r) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(r.category, overflow: TextOverflow.ellipsis),
          ),
          Text(
            r.total.toStringAsFixed(2),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  // ---------- Build ----------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Transactions'),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download),
            tooltip: 'Export CSV',
            onPressed: _exportCsv,
          ),
          IconButton(
            icon: const Icon(Icons.file_upload),
            tooltip: 'Import CSV',
            onPressed: _openImport,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _load,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openAdd,
        child: const Icon(Icons.add),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Failed to load transactions'),
              const SizedBox(height: 8),
              const Text('Something went wrong. Please try again.'),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _load,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_transactions.isEmpty) {
      return const Center(child: Text('No transactions yet.'));
    }

    final canExpand = _transactions.length > 4;

    final txItemCount = _showAll
        ? _transactions.length + (canExpand ? 1 : 0) // +1 for "Less"
        : (canExpand ? 5 : _transactions.length); // 4 tx + "More"

    final expenseRows = _expenseBreakdown();
    final canExpandExpense = expenseRows.length > 4;
    final expenseItemCount = _showAllExpenses
        ? expenseRows.length + (canExpandExpense ? 1 : 0)
        : (canExpandExpense ? 5 : expenseRows.length);

    final incomeRows = _incomeBreakdown();
    final canExpandIncome = incomeRows.length > 4;
    final incomeItemCount = _showAllIncome
        ? incomeRows.length + (canExpandIncome ? 1 : 0)
        : (canExpandIncome ? 5 : incomeRows.length);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ----- Transactions table -----
          _tableHeader(),
          const Divider(height: 1),

          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: txItemCount,
            itemBuilder: (context, index) {
              if (!_showAll && canExpand && index == 4) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Center(
                    child: TextButton(
                      onPressed: () => setState(() => _showAll = true),
                      child: const Text('More'),
                    ),
                  ),
                );
              }

              if (_showAll && canExpand && index == txItemCount - 1) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Center(
                    child: TextButton(
                      onPressed: () => setState(() => _showAll = false),
                      child: const Text('Less'),
                    ),
                  ),
                );
              }

              final t = _transactions[index];

              return Column(
                children: [
                  Dismissible(
                    key: ValueKey(t.id),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      color: Colors.red,
                      child: const Icon(Icons.delete, color: Colors.white),
                    ),
                    confirmDismiss: (_) async => await _confirmDeleteDialog(),
                    onDismissed: (_) async => await _deleteTransaction(t),
                    child: _tableRow(t),
                  ),
                  const Divider(height: 1),
                ],
              );
            },
          ),

          const SizedBox(height: 16),

          // ----- Expense breakdown table -----
          _breakdownHeader('Expense breakdown'),
          const Divider(height: 1),

          if (expenseRows.isEmpty)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text('No expenses found.'),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: expenseItemCount,
              itemBuilder: (context, index) {
                if (!_showAllExpenses && canExpandExpense && index == 4) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Center(
                      child: TextButton(
                        onPressed: () => setState(() => _showAllExpenses = true),
                        child: const Text('More'),
                      ),
                    ),
                  );
                }

                if (_showAllExpenses && canExpandExpense && index == expenseItemCount - 1) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Center(
                      child: TextButton(
                        onPressed: () => setState(() => _showAllExpenses = false),
                        child: const Text('Less'),
                      ),
                    ),
                  );
                }

                final r = expenseRows[index];
                return Column(
                  children: [
                    _breakdownRow(r),
                    const Divider(height: 1),
                  ],
                );
              },
            ),

          const SizedBox(height: 16),

          // ----- Income breakdown table -----
          _breakdownHeader('Income breakdown'),
          const Divider(height: 1),

          if (incomeRows.isEmpty)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text('No income found.'),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: incomeItemCount,
              itemBuilder: (context, index) {
                if (!_showAllIncome && canExpandIncome && index == 4) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Center(
                      child: TextButton(
                        onPressed: () => setState(() => _showAllIncome = true),
                        child: const Text('More'),
                      ),
                    ),
                  );
                }

                if (_showAllIncome && canExpandIncome && index == incomeItemCount - 1) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Center(
                      child: TextButton(
                        onPressed: () => setState(() => _showAllIncome = false),
                        child: const Text('Less'),
                      ),
                    ),
                  );
                }

                final r = incomeRows[index];
                return Column(
                  children: [
                    _breakdownRow(r),
                    const Divider(height: 1),
                  ],
                );
              },
            ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _BreakdownRow {
  final String category;
  final double total;

  _BreakdownRow({required this.category, required this.total});
}
