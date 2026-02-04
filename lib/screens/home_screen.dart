import 'package:flutter/material.dart';

import '../models/category.dart';
import '../models/transaction.dart';
import '../services/category_service.dart';
import '../services/transaction_service.dart';
import '../services/token_store.dart';

import 'categories_screen.dart';
import 'transactions_screen.dart';
import 'login_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _loading = true;
  String? _error;

  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month, 1);

  double _income = 0;
  double _expense = 0;

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  double get _balance => _income - _expense;

  Future<void> _logout() async {
    await TokenStore().clear();

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  bool _isInMonth(DateTime d, DateTime monthStart) {
    return d.year == monthStart.year && d.month == monthStart.month;
  }

  Future<void> _loadDashboard() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final cats = await CategoryService.getCategories();
      final catById = <int, Category>{for (final c in cats) c.id: c};

      // Fetch a “large” page size for now. If you have >1000 in a month,
      // we’ll add proper paging/aggregation later.
      final tx = await TransactionService.getTransactions(page: 1, pageSize: 1000);

      double income = 0;
      double expense = 0;

      for (final t in tx) {
        if (!_isInMonth(t.date, _month)) continue;

        final cat = catById[t.categoryId];
        final type = (cat?.type ?? '').toLowerCase();

        // If your API uses "Income" / "Expense"
        if (type == 'income') {
          income += t.amount;
        } else {
          // default to expense if unknown (safer for balance)
          expense += t.amount;
        }
      }

      setState(() {
        _income = income;
        _expense = expense;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  String _monthLabel(DateTime m) {
    const names = [
      'Jan','Feb','Mar','Apr','May','Jun',
      'Jul','Aug','Sep','Oct','Nov','Dec'
    ];
    return '${names[m.month - 1]} ${m.year}';
  }

  Widget _tile(String title, String value, IconData icon) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon),
                  const SizedBox(width: 8),
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                value,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Home • ${_monthLabel(_month)}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDashboard,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Failed to load dashboard'),
              const SizedBox(height: 8),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _loadDashboard,
                child: const Text('Retry'),
              ),
            ],
          ),
        )
            : Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                _tile('Income', _income.toStringAsFixed(2), Icons.arrow_upward),
                const SizedBox(width: 8),
                _tile('Expense', _expense.toStringAsFixed(2), Icons.arrow_downward),
                const SizedBox(width: 8),
                _tile('Balance', _balance.toStringAsFixed(2), Icons.account_balance_wallet),
              ],
            ),
            const SizedBox(height: 16),

            ElevatedButton.icon(
              icon: const Icon(Icons.receipt_long),
              label: const Text('Transactions'),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const TransactionsScreen()),
                );
              },
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              icon: const Icon(Icons.category),
              label: const Text('Categories'),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CategoriesScreen()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
