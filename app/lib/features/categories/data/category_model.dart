class Category {
  const Category({
    required this.id,
    required this.name,
    required this.type,
    required this.icon,
    required this.color,
    required this.isDefault,
  });

  final String id;
  final String name;
  final String type;
  final String icon;
  final String color;
  final bool isDefault;

  factory Category.fromJson(Map<String, dynamic> json) => Category(
        id: (json['_id'] ?? json['id'] ?? '').toString(),
        name: (json['name'] ?? '').toString(),
        type: (json['type'] ?? 'expense').toString(),
        icon: (json['icon'] ?? 'category').toString(),
        color: (json['color'] ?? '#16A34A').toString(),
        isDefault: json['isDefault'] == true,
      );
}
