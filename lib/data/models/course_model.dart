class Course {
  final String id;
  final String title;
  final String description;  
  final DateTime startTime;
  final DateTime endTime;
  final String? location;
  final String? instructor;
  final int maxCapacity;
  final int price;
  final bool isPublished;

  Course({
    required this.id,
    required this.title,
    required this.description,
    required this.startTime,
    required this.endTime,
    this.location,
    this.instructor,
    required this.maxCapacity,
    required this.price,
    required this.isPublished,
  });

  // 🏭 Factory Constructor: 負責把 Supabase 傳回來的 Map (JSON) 轉成 Course 物件
  // 這裡要注意：資料庫是用 snake_case (start_time)，Dart 是用 camelCase (startTime)
  factory Course.fromJson(Map<String, dynamic> json) {
    return Course(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String? ?? '',
      // DateTime 需要 parse
      startTime: DateTime.parse(json['start_time'] as String),
      endTime: DateTime.parse(json['end_time'] as String),
      location: json['location'] as String?,
      instructor: json['instructor'] as String?,
      maxCapacity: json['max_capacity'] as int? ?? 10, // 預設值保護 price: json['price'] as int? ?? 0,
      isPublished: json['is_published'] as bool? ?? false,
    );
  }

  // 如果之後要更新資料回傳給 Supabase，會需要這個方法
  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'description': description,
      'start_time': startTime.toIso8601String(),
      'end_time': endTime.toIso8601String(),
      'location': location,
      'instructor': instructor,
      'max_capacity': maxCapacity,
      'price': price,
      'is_published': isPublished,
    };
  }
}
