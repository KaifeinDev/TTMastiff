class TableModel {
  final String id;
  final String name;
  final int capacity;
  final bool isActive;
  final int sortOrder;

  TableModel({
    required this.id,
    required this.name,
    this.capacity = 2,
    this.isActive = true,
    this.sortOrder = 0,
  });

  factory TableModel.fromJson(Map<String, dynamic> json) {
    return TableModel(
      id: json['id'],
      name: json['name'] ?? '未命名桌次',
      capacity: json['capacity'] ?? 2,
      isActive: json['is_active'] ?? true,
      sortOrder: json['sort_order'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'capacity': capacity,
      'is_active': isActive,
      'sort_order': sortOrder,
    };
  }
}
