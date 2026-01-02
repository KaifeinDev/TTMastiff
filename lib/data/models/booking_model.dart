class BookingModel {
  final String id;
  final String status;
  final String studentName;
  final String courseTitle;
  final String category;     // 🆕 新增分類
  final DateTime startTime;
  final DateTime endTime;
  final List<String> coaches; // 🆕 改為教練列表

  BookingModel({
    required this.id,
    required this.status,
    required this.studentName,
    required this.courseTitle,
    required this.category,
    required this.startTime,
    required this.endTime,
    required this.coaches,
  });

  factory BookingModel.fromJson(Map<String, dynamic> json) {
    final session = json['session'] ?? {};
    final course = session['course'] ?? {};
    final student = json['student'] ?? {};

    return BookingModel(
      id: json['id'],
      status: json['status'] ?? 'confirmed',
      studentName: student['name'] ?? '未知學員',
      
      courseTitle: course['title'] ?? '未命名課程',
      category: course['category'] ?? 'group',
      
      startTime: DateTime.parse(session['start_time']).toLocal(),
      endTime: DateTime.parse(session['end_time']).toLocal(),
      
      // 處理 Postgres 的陣列轉 Dart List
      coaches: List<String>.from(session['coaches'] ?? []), 
    );
  }
  
  // 方便 UI 顯示分類中文名
  String get categoryText => category == 'personal' ? '個人課' : '團體課';
}
