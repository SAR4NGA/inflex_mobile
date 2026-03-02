import 'package:flutter/material.dart';

import '../models/category.dart';
import '../services/category_service.dart';
import '../services/transaction_service.dart';

enum CompareMode { month, date }

class ComparisonScreen extends StatefulWidget {
  const ComparisonScreen({super.key});

  @override
  State<ComparisonScreen> createState() => _ComparisonScreenState();
}

class _ComparisonScreenState extends State<ComparisonScreen> {
  bool _loading = true;
  String? _error;

  CompareMode _compareMode = CompareMode.month;

  DateTime _date1 = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
  DateTime _date2 = DateTime(DateTime.now().year, DateTime.now().month - 1, DateTime.now().day);

  double _m1Income = 0;
  double _m1Expense = 0;
  double _m2Income = 0;
  double _m2Expense = 0;

  Map<int, double> _m1ExpenseCategoryTotals = {};
  Map<int, double> _m2ExpenseCategoryTotals = {};
  Map<int, double> _m1IncomeCategoryTotals = {};
  Map<int, double> _m2IncomeCategoryTotals = {};
  Map<int, Category> _categoryCache = {};

  @override
  void initState() {
    super.initState();
    _loadComparisonData();
  }

  bool _isMatch(DateTime d, DateTime target) {
    if (_compareMode == CompareMode.month) {
      return d.year == target.year && d.month == target.month;
    } else {
      return d.year == target.year && d.month == target.month && d.day == target.day;
    }
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

      Map<int, double> m1ExpCatTotals = {};
      Map<int, double> m2ExpCatTotals = {};
      Map<int, double> m1IncCatTotals = {};
      Map<int, double> m2IncCatTotals = {};

      for (final t in tx) {
        final isM1 = _isMatch(t.date, _date1);
        final isM2 = _isMatch(t.date, _date2);

        if (!isM1 && !isM2) continue;

        final cat = _categoryCache[t.categoryId];
        final type = (cat?.type ?? '').toLowerCase();
        
        if (isM1) {
          if (type == 'income') {
            m1Inc += t.amount;
            m1IncCatTotals[t.categoryId] = (m1IncCatTotals[t.categoryId] ?? 0) + t.amount;
          } else {
            m1Exp += t.amount;
            m1ExpCatTotals[t.categoryId] = (m1ExpCatTotals[t.categoryId] ?? 0) + t.amount;
          }
        } 
        
        if (isM2) {
          if (type == 'income') {
            m2Inc += t.amount;
            m2IncCatTotals[t.categoryId] = (m2IncCatTotals[t.categoryId] ?? 0) + t.amount;
          } else {
            m2Exp += t.amount;
            m2ExpCatTotals[t.categoryId] = (m2ExpCatTotals[t.categoryId] ?? 0) + t.amount;
          }
        }
      }

      setState(() {
        _m1Income = m1Inc;
        _m1Expense = m1Exp;
        _m2Income = m2Inc;
        _m2Expense = m2Exp;
        _m1ExpenseCategoryTotals = m1ExpCatTotals;
        _m2ExpenseCategoryTotals = m2ExpCatTotals;
        _m1IncomeCategoryTotals = m1IncCatTotals;
        _m2IncomeCategoryTotals = m2IncCatTotals;
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

  Future<void> _selectDate(int index) async {
    final DateTime initialDate = index == 1 ? _date1 : _date2;
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
      helpText: _compareMode == CompareMode.month ? 'Select Month' : 'Select Date',
    );
    if (picked != null) {
      setState(() {
        if (index == 1) {
          _date1 = picked;
        } else {
          _date2 = picked;
        }
      });
      _loadComparisonData();
    }
  }

  String _dateLabel(DateTime d) {
    const names = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    if (_compareMode == CompareMode.month) {
      return '${names[d.month - 1]} ${d.year}';
    } else {
      return '${d.day} ${names[d.month - 1]} ${d.year}';
    }
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

  Widget _buildCategoryComparison(String title, Map<int, double> m1Totals, Map<int, double> m2Totals) {
    // Combine all unique categories that have transactions in either month
    final allCatIds = <int>{...m1Totals.keys, ...m2Totals.keys};
    
    if (allCatIds.isEmpty) {
      return Card(
        elevation: 3,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const Divider(),
              const SizedBox(height: 8),
              const Text('No data to compare.', style: TextStyle(fontStyle: FontStyle.italic)),
            ],
          ),
        ),
      );
    }

    // Sort categories by highest amount in Month 1, then Month 2
    final sortedCatIds = allCatIds.toList()
      ..sort((a, b) {
        final aVal = (m1Totals[a] ?? 0) + (m2Totals[a] ?? 0);
        final bVal = (m1Totals[b] ?? 0) + (m2Totals[b] ?? 0);
        return bVal.compareTo(aVal);
      });

    return Card(
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const Divider(),
            ...sortedCatIds.map((id) {
              final cat = _categoryCache[id];
              final m1Val = m1Totals[id] ?? 0;
              final m2Val = m2Totals[id] ?? 0;
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
        title: const Text('Compare'),
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
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ChoiceChip(
                            label: const Text('By Month'),
                            selected: _compareMode == CompareMode.month,
                            onSelected: (selected) {
                              if (selected) {
                                setState(() => _compareMode = CompareMode.month);
                                _loadComparisonData();
                              }
                            },
                          ),
                          const SizedBox(width: 8),
                          ChoiceChip(
                            label: const Text('By Date'),
                            selected: _compareMode == CompareMode.date,
                            onSelected: (selected) {
                              if (selected) {
                                setState(() => _compareMode = CompareMode.date);
                                _loadComparisonData();
                              }
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.calendar_month),
                              label: Text('1: ${_dateLabel(_date1)}', style: const TextStyle(fontSize: 12)),
                              onPressed: () => _selectDate(1),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.calendar_month),
                              label: Text('2: ${_dateLabel(_date2)}', style: const TextStyle(fontSize: 12)),
                              onPressed: () => _selectDate(2),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildSummaryCard(),
                      const SizedBox(height: 16),
                      _buildCategoryComparison('Income Breakdown', _m1IncomeCategoryTotals, _m2IncomeCategoryTotals),
                      const SizedBox(height: 16),
                      _buildCategoryComparison('Expense Breakdown', _m1ExpenseCategoryTotals, _m2ExpenseCategoryTotals),
                    ],
                  ),
                ),
    );
  }
}
