import 'package:flutter/material.dart';

import '../models/category.dart';
import '../services/category_service.dart';
import '../services/transaction_service.dart';

class ComparisonScreen extends StatefulWidget {
  const ComparisonScreen({super.key});

  @override
  State<ComparisonScreen> createState() => _ComparisonScreenState();
}

class _ComparisonScreenState extends State<ComparisonScreen> {
  bool _loading = true;
  String? _error;

  DateTime _month1 = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _month2 = DateTime(DateTime.now().year, DateTime.now().month - 1, 1);

  double _m1Income = 0;
  double _m1Expense = 0;
  double _m2Income = 0;
  double _m2Expense = 0;

  Map<int, double> _m1CategoryTotals = {};
  Map<int, double> _m2CategoryTotals = {};
  Map<int, Category> _categoryCache = {};

  @override
  void initState() {
    super.initState();
    _loadComparisonData();
  }

  bool _isInMonth(DateTime d, DateTime monthStart) {
    return d.year == monthStart.year && d.month == monthStart.month;
  }

  Future<void> _loadComparisonData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final cats = await CategoryService.getCategories();
      _categoryCache = {for (final c in cats) c.id: c};

      final tx = await TransactionService.getTransactions(page: 1, pageSize: 2000);

      double m1Inc = 0;
      double m1Exp = 0;
      double m2Inc = 0;
      double m2Exp = 0;

      Map<int, double> m1CatTotals = {};
      Map<int, double> m2CatTotals = {};

      for (final t in tx) {
        final isM1 = _isInMonth(t.date, _month1);
        final isM2 = _isInMonth(t.date, _month2);

        if (!isM1 && !isM2) continue;

        final cat = _categoryCache[t.categoryId];
        final type = (cat?.type ?? '').toLowerCase();
        
        if (isM1) {
          if (type == 'income') {
            m1Inc += t.amount;
          } else {
            m1Exp += t.amount;
            m1CatTotals[t.categoryId] = (m1CatTotals[t.categoryId] ?? 0) + t.amount;
          }
        } 
        
        if (isM2) {
          if (type == 'income') {
            m2Inc += t.amount;
          } else {
            m2Exp += t.amount;
            m2CatTotals[t.categoryId] = (m2CatTotals[t.categoryId] ?? 0) + t.amount;
          }
        }
      }

      setState(() {
        _m1Income = m1Inc;
        _m1Expense = m1Exp;
        _m2Income = m2Inc;
        _m2Expense = m2Exp;
        _m1CategoryTotals = m1CatTotals;
        _m2CategoryTotals = m2CatTotals;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _selectMonth(int monthIndex) async {
    final DateTime initialDate = monthIndex == 1 ? _month1 : _month2;
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
      helpText: 'Select Month (Day is ignored)',
    );
    if (picked != null) {
      setState(() {
        if (monthIndex == 1) {
          _month1 = DateTime(picked.year, picked.month, 1);
        } else {
          _month2 = DateTime(picked.year, picked.month, 1);
        }
      });
      _loadComparisonData();
    }
  }

  String _monthLabel(DateTime m) {
    const names = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${names[m.month - 1]} ${m.year}';
  }

  Widget _buildSummaryCard() {
    return Card(
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text(
              'Summary',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const Divider(),
            _buildComparisonRow('Income', _m1Income, _m2Income, Colors.green),
            const SizedBox(height: 8),
            _buildComparisonRow('Expense', _m1Expense, _m2Expense, Colors.red),
            const SizedBox(height: 8),
            _buildComparisonRow(
                'Balance', _m1Income - _m1Expense, _m2Income - _m2Expense, Colors.blue),
          ],
        ),
      ),
    );
  }

  Widget _buildComparisonRow(String label, double m1Value, double m2Value, Color color) {
    double diff = m1Value - m2Value;
    String sign = diff > 0 ? '+' : '';
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(flex: 2, child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold))),
        Expanded(
          flex: 3,
          child: Text(
            m1Value.toStringAsFixed(2),
            textAlign: TextAlign.center,
            style: TextStyle(color: color, fontWeight: FontWeight.bold),
          ),
        ),
        Expanded(
          flex: 3,
          child: Text(
            m2Value.toStringAsFixed(2),
            textAlign: TextAlign.center,
            style: TextStyle(color: color, fontWeight: FontWeight.bold),
          ),
        ),
        Expanded(
          flex: 2,
          child: Text(
            '$sign${diff.toStringAsFixed(2)}',
            textAlign: TextAlign.right,
            style: TextStyle(
              color: diff > 0 ? Colors.green : (diff < 0 ? Colors.red : Colors.grey),
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryComparison() {
    // Combine all unique categories that have expenses in either month
    final allCatIds = <int>{..._m1CategoryTotals.keys, ..._m2CategoryTotals.keys};
    
    if (allCatIds.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text('No expenses to compare.'),
        ),
      );
    }

    // Sort categories by highest expense in Month 1, then Month 2
    final sortedCatIds = allCatIds.toList()
      ..sort((a, b) {
        final aVal = (_m1CategoryTotals[a] ?? 0) + (_m2CategoryTotals[a] ?? 0);
        final bVal = (_m1CategoryTotals[b] ?? 0) + (_m2CategoryTotals[b] ?? 0);
        return bVal.compareTo(aVal);
      });

    return Card(
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Expense Breakdown',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const Divider(),
            ...sortedCatIds.map((id) {
              final cat = _categoryCache[id];
              final m1Val = _m1CategoryTotals[id] ?? 0;
              final m2Val = _m2CategoryTotals[id] ?? 0;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: _buildComparisonRow(cat?.name ?? 'Unknown', m1Val, m2Val, Colors.black87),
              );
            }),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Compare Months'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('Failed to load comparison'),
                      const SizedBox(height: 8),
                      Text(_error!),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: _loadComparisonData,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.calendar_month),
                              label: Text('M1: ${_monthLabel(_month1)}', style: const TextStyle(fontSize: 12)),
                              onPressed: () => _selectMonth(1),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.calendar_month),
                              label: Text('M2: ${_monthLabel(_month2)}', style: const TextStyle(fontSize: 12)),
                              onPressed: () => _selectMonth(2),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildSummaryCard(),
                      const SizedBox(height: 16),
                      _buildCategoryComparison(),
                    ],
                  ),
                ),
    );
  }
}
