class SavingsGoal {
  const SavingsGoal({
    required this.id,
    required this.name,
    required this.targetAmount,
    required this.savedAmount,
    required this.isCompleted,
    required this.icon,
    required this.color,
    this.deadline,
  });

  final String id;
  final String name;
  final double targetAmount;
  final double savedAmount;
  final bool isCompleted;
  final String icon;
  final String color;
  final DateTime? deadline;

  double get progress =>
      targetAmount == 0 ? 0 : (savedAmount / targetAmount).clamp(0.0, 1.0);
  int get progressPercent => (progress * 100).round();
  double get remaining => (targetAmount - savedAmount).clamp(0, double.infinity);

  factory SavingsGoal.fromJson(Map<String, dynamic> json) => SavingsGoal(
        id: (json['_id'] ?? json['id'] ?? '').toString(),
        name: (json['name'] ?? '').toString(),
        targetAmount: (json['targetAmount'] ?? 0).toDouble(),
        savedAmount: (json['savedAmount'] ?? 0).toDouble(),
        isCompleted: json['isCompleted'] == true,
        icon: (json['icon'] ?? 'target').toString(),
        color: (json['color'] ?? '#4CAF8A').toString(),
        deadline: json['deadline'] == null
            ? null
            : DateTime.tryParse(json['deadline'].toString())?.toLocal(),
      );
}

class SavingsPayload {
  const SavingsPayload({
    required this.goals,
    required this.totalSaved,
    required this.totalTarget,
    required this.currency,
  });

  final List<SavingsGoal> goals;
  final double totalSaved;
  final double totalTarget;
  final String currency;

  double get progress => totalTarget == 0 ? 0 : totalSaved / totalTarget;
  int get progressPercent => (progress * 100).round();
}
