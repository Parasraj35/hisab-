class Account {
  const Account({
    required this.id,
    required this.name,
    required this.type,
    required this.icon,
    required this.color,
    required this.currency,
    required this.initialBalance,
    required this.currentBalance,
    required this.isDefault,
    required this.isArchived,
  });

  final String id;
  final String name;
  final String type;
  final String icon;
  final String color;
  final String currency;
  final double initialBalance;
  final double currentBalance;
  final bool isDefault;
  final bool isArchived;

  factory Account.fromJson(Map<String, dynamic> json) => Account(
        id: (json['_id'] ?? json['id'] ?? '').toString(),
        name: (json['name'] ?? '').toString(),
        type: (json['type'] ?? 'cash').toString(),
        icon: (json['icon'] ?? 'payments').toString(),
        color: (json['color'] ?? '#16A34A').toString(),
        currency: (json['currency'] ?? 'PKR').toString(),
        initialBalance: (json['initialBalance'] ?? 0).toDouble(),
        currentBalance: (json['currentBalance'] ?? 0).toDouble(),
        isDefault: json['isDefault'] == true,
        isArchived: json['isArchived'] == true,
      );
}
