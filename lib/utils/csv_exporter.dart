import 'dart:io';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import '../models/transaction.dart';

class CsvExporter {
  static Future<File> exportTransactions(List<TransactionItem> tx) async {
    final rows = <List<dynamic>>[
      ['date', 'amount', 'category', 'note'],
      ...tx.map((t) => [
        _dateOnly(t.date),
        t.amount.toStringAsFixed(2),
        t.categoryName,
        t.note,
      ]),
    ];

    final csv = const ListToCsvConverter().convert(rows);

    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/transactions_${DateTime.now().millisecondsSinceEpoch}.csv');
    await file.writeAsString(csv);
    return file;
  }

  static String _dateOnly(DateTime d) {
    final y = d.year.toString();
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }
}
