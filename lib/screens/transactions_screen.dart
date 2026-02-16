import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../models/transaction.dart';
import '../services/transaction_service.dart';
import '../services/category_service.dart';
import '../utils/csv_exporter.dart';

import 'add_transaction_screen.dart';
import 'edit_transaction_screen.dart';
import 'import_transactions_screen.dart';

enum TxTypeFilter { all, expense, income }

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

  // -------- Filters (Day 6) --------
  int? _filterYear;
  int? _filterMonth;
  int? _filterDay;

  TxTypeFilter _typeFilter = TxTypeFilter.all;

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
      // keep filters as-is; don’t reset them on refresh
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

  // ---------- Category type + breakdown helpers ----------

  String _categoryTypeFor(TransactionItem t) {
    final name = (t.categoryName.isEmpty ? 'Uncategorized' : t.categoryName)
        .trim()
        .toLowerCase();

    return _typeByCategoryName[name] ?? '';
  }

  // Filters apply here
  List<TransactionItem> _applyFilters(List<TransactionItem> source) {
    Iterable<TransactionItem> out = source;

    // Date filter (partial)
    if (_filterYear != null) {
      out = out.where((t) {
        final d = t.date;
        if (d.year != _filterYear) return false;
        if (_filterMonth != null && d.month != _filterMonth) return false;
        if (_filterDay != null && d.day != _filterDay) return false;
        return true;
      });
    }

    // Type filter
    if (_typeFilter != TxTypeFilter.all) {
      out = out.where((t) {
        final type = _categoryTypeFor(t);
        if (_typeFilter == TxTypeFilter.expense) return type == 'Expense';
        if (_typeFilter == TxTypeFilter.income) return type == 'Income';
        return true;
      });
    }

    return out.toList();
  }

  List<_BreakdownRow> _expenseBreakdown(List<TransactionItem> tx) {
    final map = <String, double>{};

    for (final t in tx) {
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

  List<_BreakdownRow> _incomeBreakdown(List<TransactionItem> tx) {
    final map = <String, double>{};

    for (final t in tx) {
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

  // ---------- Filter UI (Day 6) ----------

  Widget _buildFilterCard() {
    final years = List.generate(15, (i) => DateTime.now().year - i);
    final months = List.generate(12, (i) => i + 1);

    int daysInMonth(int year, int month) {
      final nextMonth = (month == 12) ? DateTime(year + 1, 1, 1) : DateTime(year, month + 1, 1);
      return nextMonth.subtract(const Duration(days: 1)).day;
    }

    final dayOptions = (_filterYear != null && _filterMonth != null)
        ? List.generate(daysInMonth(_filterYear!, _filterMonth!), (i) => i + 1)
        : <int>[];

    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Filters', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),

            // Type filter
            DropdownButtonFormField<TxTypeFilter>(
              initialValue: _typeFilter,
              decoration: const InputDecoration(labelText: 'Type'),
              items: const [
                DropdownMenuItem(value: TxTypeFilter.all, child: Text('All')),
                DropdownMenuItem(value: TxTypeFilter.expense, child: Text('Expense')),
                DropdownMenuItem(value: TxTypeFilter.income, child: Text('Income')),
              ],
              onChanged: (v) => setState(() => _typeFilter = v ?? TxTypeFilter.all),
            ),

            const SizedBox(height: 12),

            // Date filter (partial)
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    initialValue: _filterYear,
                    decoration: const InputDecoration(labelText: 'Year'),
                    items: years
                        .map((y) => DropdownMenuItem<int>(value: y, child: Text('$y')))
                        .toList(),
                    onChanged: (v) {
                      setState(() {
                        _filterYear = v;
                        _filterMonth = null;
                        _filterDay = null;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    initialValue: _filterMonth,
                    decoration: const InputDecoration(labelText: 'Month'),
                    items: months
                        .map((m) => DropdownMenuItem<int>(
                      value: m,
                      child: Text(m.toString().padLeft(2, '0')),
                    ))
                        .toList(),
                    onChanged: (_filterYear == null)
                        ? null
                        : (v) {
                      setState(() {
                        _filterMonth = v;
                        _filterDay = null;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    initialValue: _filterDay,
                    decoration: const InputDecoration(labelText: 'Day'),
                    items: dayOptions
                        .map((d) => DropdownMenuItem<int>(
                      value: d,
                      child: Text(d.toString().padLeft(2, '0')),
                    ))
                        .toList(),
                    onChanged: dayOptions.isEmpty
                        ? null
                        : (v) => setState(() => _filterDay = v),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () {
                  setState(() {
                    _filterYear = null;
                    _filterMonth = null;
                    _filterDay = null;
                    _typeFilter = TxTypeFilter.all;
                  });
                },
                child: const Text('Clear filters'),
              ),
            ),
          ],
        ),
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

    final filteredTx = _applyFilters(_transactions);

    if (filteredTx.isEmpty) {
      return ListView(
        children: [
          _buildFilterCard(),
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: Text('No transactions match the filters.')),
          ),
        ],
      );
    }

    final canExpandTx = filteredTx.length > 4;
    final txItemCount = _showAll
        ? filteredTx.length + (canExpandTx ? 1 : 0)
        : (canExpandTx ? 5 : filteredTx.length);

    final expenseRows = _expenseBreakdown(filteredTx);
    final canExpandExpense = expenseRows.length > 4;
    final expenseItemCount = _showAllExpenses
        ? expenseRows.length + (canExpandExpense ? 1 : 0)
        : (canExpandExpense ? 5 : expenseRows.length);

    final incomeRows = _incomeBreakdown(filteredTx);
    final canExpandIncome = incomeRows.length > 4;
    final incomeItemCount = _showAllIncome
        ? incomeRows.length + (canExpandIncome ? 1 : 0)
        : (canExpandIncome ? 5 : incomeRows.length);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Filters at top
          _buildFilterCard(),

          // ----- Transactions table -----
          _tableHeader(),
          const Divider(height: 1),

          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: txItemCount,
            itemBuilder: (context, index) {
              if (!_showAll && canExpandTx && index == 4) {
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

              if (_showAll && canExpandTx && index == txItemCount - 1) {
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

              final t = filteredTx[index];

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
