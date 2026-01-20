class TableModel {
  final String id;
  final String name;
  final int capacity;
  final bool isActive;
  final int sortOrder;
  final String? remarks;

  TableModel({
    required this.id,
    required this.name,
    this.capacity = 4,
    this.isActive = true,
    this.sortOrder = 0,
    this.remarks,
  });

  factory TableModel.fromJson(Map<String, dynamic> json) {
    return TableModel(
      id: json['id'],
      name: json['name'] ?? '未命名桌次',
      capacity: json['capacity'] ?? 2,
      isActive: json['is_active'] ?? true,
      sortOrder: json['sort_order'] ?? 0,
      remarks: json['remarks'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'capacity': capacity,
      'is_active': isActive,
      'sort_order': sortOrder,
      'remarks': remarks,
    };
  }

  TableModel copyWith({
    String? id,
    String? name,
    int? capacity,
    bool? isActive,
    int? sortOrder,
    String? remarks,
  }) {
    return TableModel(
      id: id ?? this.id,
      name: name ?? this.name,
      capacity: capacity ?? this.capacity,
      isActive: isActive ?? this.isActive,
      sortOrder: sortOrder ?? this.sortOrder,
      remarks: remarks ?? this.remarks,
    );
  }
}
