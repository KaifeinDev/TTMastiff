class SessionModel {
  final String id;
  final DateTime startTime;
  final DateTime endTime;
  final List<String> coaches;
  final int maxCapacity;
  
  // 來自 Course 的資訊
  final String courseTitle;
  final String category; // 'group' or 'personal'
  final int price;
  final String? imageUrl;

  SessionModel({
    required this.id,
    required this.startTime,
    required this.endTime,
    required this.coaches,
    required this.maxCapacity,
    required this.courseTitle,
    required this.category,
    required this.price,
    this.imageUrl,
  });

  factory SessionModel.fromJson(Map<String, dynamic> json) {
    final course = json['course'] ?? {};
    
    return SessionModel(
      id: json['id'],
      startTime: DateTime.parse(json['start_time']).toLocal(),
      endTime: DateTime.parse(json['end_time']).toLocal(),
      coaches: List<String>.from(json['coaches'] ?? []),
      maxCapacity: json['max_capacity'] ?? 10,
      
      courseTitle: course['title'] ?? '未命名課程',
      category: course['category'] ?? 'group',
      price: course['price'] ?? 0,
      imageUrl: course['image_url'],
    );
  }

  // 方便 UI 顯示
  String get categoryText => category == 'personal' ? '1對1' : '團體班';
  String get coachesText => coaches.isEmpty ? '教練待定' : coaches.join('、');
}
