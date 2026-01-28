class ActivityModel {
  final String id;
  final String title;
  final String description;
  final DateTime startTime;
  final DateTime endTime;
  final String? image; // base64 編碼的圖片
  final String type; // 'carousel' 或 'recent'
  final int order; // 顯示順序
  final String status; // 'active' 或 'inactive'
  final DateTime createdAt;
  final DateTime? updatedAt;

  ActivityModel({
    required this.id,
    required this.title,
    required this.description,
    required this.startTime,
    required this.endTime,
    this.image,
    required this.type,
    required this.order,
    required this.status,
    required this.createdAt,
    this.updatedAt,
  });

  factory ActivityModel.fromJson(Map<String, dynamic> json) {
    return ActivityModel(
      id: json['id'],
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      startTime: DateTime.parse(json['start_time'] as String),
      endTime: DateTime.parse(json['end_time'] as String),
      image: json['image'],
      type: json['type'] ?? 'recent',
      order: json['order'] ?? 0,
      status: json['status'] ?? 'inactive',
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'description': description,
      'start_time': startTime.toIso8601String(),
      'end_time': endTime.toIso8601String(),
      'image': image,
      'type': type,
      'order': order,
      'status': status,
    };
  }

  ActivityModel copyWith({
    String? id,
    String? title,
    String? description,
    DateTime? startTime,
    DateTime? endTime,
    String? image,
    String? type,
    int? order,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ActivityModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      image: image ?? this.image,
      type: type ?? this.type,
      order: order ?? this.order,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
