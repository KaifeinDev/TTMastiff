class CourseModel {
  final String id;
  final String title;
  final String? description;  
  final int price;
  final int durationMinutes;
  final String? imageUrl;
  final String category; // group or personal


  CourseModel({
    required this.id,
    required this.title,
    this.description,
    required this.price,
    required this.durationMinutes,
    this.imageUrl,
    required this.category,
  });

  // 🏭 Factory Constructor: 負責把 Supabase 傳回來的 Map (JSON) 轉成 Course 物件
  // 這裡要注意：資料庫是用 snake_case (start_time)，Dart 是用 camelCase (startTime)
  factory CourseModel.fromJson(Map<String, dynamic> json) {
    return CourseModel(
      id: json['id'],
      title: json['title'] ?? '未命名課程',
      description: json['description'],
      price: json['price'] ?? 0,
      durationMinutes: json['duration_minutes'] ?? 60,
      imageUrl: json['image_url'],
      category: json['category'] ?? 'group',
    );
  }
}
