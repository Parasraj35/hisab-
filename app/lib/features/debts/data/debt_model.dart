class Debt {
  const Debt({
    required this.id,
    required this.direction,
    required this.personName,
    required this.personPhone,
    required this.amount,
    required this.settledAmount,
    required this.status,
    required this.note,
    this.dueDate,
  });

  final String id;
  final String direction; // lent | borrowed
  final String personName;
  final String personPhone;
  final double amount;
  final double settledAmount;
  final String status; // pending | partial | paid
  final String note;
  final DateTime? dueDate;

  double get outstanding => amount - settledAmount;
  bool get isPaid => status == 'paid';
  double get progress =>
      amount == 0 ? 0 : (settledAmount / amount).clamp(0.0, 1.0);

  /// True when money is still owed and the due date has passed.
  bool get isOverdue =>
      !isPaid && dueDate != null && dueDate!.isBefore(DateTime.now());

  factory Debt.fromJson(Map<String, dynamic> json) => Debt(
        id: (json['_id'] ?? json['id'] ?? '').toString(),
        direction: (json['direction'] ?? 'lent').toString(),
        personName: (json['personName'] ?? '').toString(),
        personPhone: (json['personPhone'] ?? '').toString(),
        amount: (json['amount'] ?? 0).toDouble(),
        settledAmount: (json['settledAmount'] ?? 0).toDouble(),
        status: (json['status'] ?? 'pending').toString(),
        note: (json['note'] ?? '').toString(),
        dueDate: json['dueDate'] == null
            ? null
            : DateTime.tryParse(json['dueDate'].toString())?.toLocal(),
      );
}

class DebtSummary {
  const DebtSummary({
    required this.lentTotal,
    required this.lentReceived,
    required this.borrowedTotal,
    required this.borrowedRepaid,
  });

  final double lentTotal;
  final double lentReceived;
  final double borrowedTotal;
  final double borrowedRepaid;

  factory DebtSummary.fromJson(Map<String, dynamic> json) {
    final lent = Map<String, dynamic>.from(json['lent'] ?? {});
    final borrowed = Map<String, dynamic>.from(json['borrowed'] ?? {});
    return DebtSummary(
      lentTotal: (lent['total'] ?? 0).toDouble(),
      lentReceived: (lent['received'] ?? 0).toDouble(),
      borrowedTotal: (borrowed['total'] ?? 0).toDouble(),
      borrowedRepaid: (borrowed['repaid'] ?? 0).toDouble(),
    );
  }
}

class DebtsPayload {
  const DebtsPayload({
    required this.debts,
    required this.summary,
    required this.currency,
  });
  final List<Debt> debts;
  final DebtSummary summary;
  final String currency;
}
