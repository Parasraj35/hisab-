import '../../accounts/data/account_model.dart';
import '../../categories/data/category_model.dart';

class TransactionItem {
  const TransactionItem({
    required this.id,
    required this.type,
    required this.amount,
    required this.date,
    required this.note,
    this.account,
    this.toAccount,
    this.category,
  });

  final String id;
  final String type; // expense | income | transfer
  final double amount;
  final DateTime date;
  final String note;
  final Account? account;
  final Account? toAccount;
  final Category? category;

  bool get isExpense => type == 'expense';
  bool get isIncome => type == 'income';
  bool get isTransfer => type == 'transfer';

  /// Signed value for display: expenses and outgoing transfers read negative.
  double get signedAmount => isIncome ? amount : -amount;

  String get title {
    if (isTransfer) {
      return 'Transfer to ${toAccount?.name ?? 'account'}';
    }
    if (note.isNotEmpty) return note;
    return category?.name ?? (isIncome ? 'Income' : 'Expense');
  }

  String get subtitle => account?.name ?? '';

  static Account? _account(dynamic value) {
    if (value is Map) return Account.fromJson(Map<String, dynamic>.from(value));
    return null;
  }

  factory TransactionItem.fromJson(Map<String, dynamic> json) =>
      TransactionItem(
        id: (json['_id'] ?? json['id'] ?? '').toString(),
        type: (json['type'] ?? 'expense').toString(),
        amount: (json['amount'] ?? 0).toDouble(),
        date: DateTime.tryParse((json['date'] ?? '').toString())?.toLocal() ??
            DateTime.now(),
        note: (json['note'] ?? '').toString(),
        account: _account(json['account']),
        toAccount: _account(json['toAccount']),
        category: json['category'] is Map
            ? Category.fromJson(Map<String, dynamic>.from(json['category']))
            : null,
      );
}
