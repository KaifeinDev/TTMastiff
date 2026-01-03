import '../../core/utils/time_extensions.dart';

class CourseModel {
  final String id;
  final String title;
  final String? description;
  final int price;
  final String? imageUrl;
  final String category; // 'group' or 'personal'
  final DateTime defaultStartTime;
  final DateTime defaultEndTime;
  final bool isPublished; // ✨ 新增：對應 SQL 的 is_published

  CourseModel({
    required this.id,
    required this.title,
    this.description,
    required this.price,
    required this.defaultStartTime,
    required this.defaultEndTime,
    this.imageUrl,
    required this.category,
    required this.isPublished,
  });

  factory CourseModel.fromJson(Map<String, dynamic> json) {
    return CourseModel(
      id: json['id'],
      title: json['title'] ?? '未命名課程',
      description: json['description'],
      price: json['price'] ?? 0,
      defaultStartTime: (json['default_start_time'] as String)
          .toDateTimeFromTime(),
      defaultEndTime: (json['default_end_time'] as String).toDateTimeFromTime(),
      imageUrl: json['image_url'],
      category: json['category'] ?? 'group',
      isPublished: json['is_published'] ?? true,
    );
  }
}
