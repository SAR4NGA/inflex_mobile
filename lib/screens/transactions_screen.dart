import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../models/transaction.dart';
import '../services/transaction_service.dart';
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
      final data = await TransactionService.getTransactions(page: 1, pageSize: 50);
      setState(() {
        _transactions = data;
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

  // ---------- Expense breakdown (Day 3) ----------

  List<_BreakdownRow> _expenseBreakdown() {
    // Assumption: expense is negative amount
    final map = <String, double>{};

    for (final t in _transactions) {
      if (t.amount >= 0) continue; // expense only
      final name = (t.categoryName.isEmpty ? 'Uncategorized' : t.categoryName).trim();
      map[name] = (map[name] ?? 0) + t.amount.abs(); // show expense as positive
    }

    final rows = map.entries
        .map((e) => _BreakdownRow(category: e.key, total: e.value))
        .toList();

    rows.sort((a, b) => b.total.compareTo(a.total)); // highest first
    return rows;
  }
  List<_BreakdownRow> _incomeBreakdown() {
    final map = <String, double>{};

    for (final t in _transactions) {
      if (t.amount <= 0) continue; // income only
      final name = (t.categoryName.isEmpty ? 'Uncategorized' : t.categoryName).trim();
      map[name] = (map[name] ?? 0) + t.amount; // income already positive
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
          Text(r.total.toStringAsFixed(2), style: const TextStyle(fontWeight: FontWeight.bold)),
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

    // Collapsed: show 4 tx + a "More" row (5th row)
    // Expanded: show all tx (and we’ll add "Less" row at end)
    final txItemCount = _showAll
        ? _transactions.length + (canExpand ? 1 : 0) // +1 for "Less"
        : (canExpand ? 5 : _transactions.length); // 4 tx + "More"

    // Expense breakdown rows
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

    return Column(
      children: [
        // ----- Transactions table -----
        _tableHeader(),
        const Divider(height: 1),
        Expanded(
          child: ListView(
            children: [
              // Transactions list (table)
              SizedBox(
                height: 320, // keeps both sections visible; adjust if you like
                child: ListView.builder(
                  itemCount: txItemCount,
                  itemBuilder: (context, index) {
                    // COLLAPSED: index 4 is "More"
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

                    // EXPANDED: last row is "Less"
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
                    // COLLAPSED: index 4 is "More"
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

                    // EXPANDED: last row is "Less"
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
                    // COLLAPSED: index 4 is "More"
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

                    // EXPANDED: last row is "Less"
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

            ],

          ),
        ),
      ],
    );
  }
}

class _BreakdownRow {
  final String category;
  final double total;

  _BreakdownRow({required this.category, required this.total});
}
