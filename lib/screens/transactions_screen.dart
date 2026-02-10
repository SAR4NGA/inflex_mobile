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
    });

    try {
      final data =
      await TransactionService.getTransactions(page: 1, pageSize: 50);
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
            child:
            Text('Category', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          Expanded(
            flex: 4,
            child: Text('Note', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerRight,
              child:
              Text('Amount', style: TextStyle(fontWeight: FontWeight.bold)),
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

    return Column(
      children: [
        _tableHeader(),
        const Divider(height: 1),
        Expanded(
          child: ListView.separated(
            itemCount: _transactions.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final t = _transactions[index];

              return Dismissible(
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
              );
            },
          ),
        ),
      ],
    );
  }
}
