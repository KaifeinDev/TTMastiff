import 'course_model.dart';

/// 定義教練模型
class CoachModel {
  final String id;
  final String name;
  final String? avatarUrl;

  CoachModel({
    required this.id, 
    required this.name, 
    this.avatarUrl,
  });

  factory CoachModel.fromJson(Map<String, dynamic> json) {
    return CoachModel(
      id: json['id'],
      name: json['full_name'] ?? '教練',
      avatarUrl: json['avatar_url'], 
    );
  }
}

class SessionModel {
  final String id;
  final String courseId;
  final DateTime startTime;
  final DateTime endTime;
  final String? location;
  final int maxCapacity;
  final CourseModel? course;
  
  // 1. 統一使用複數命名，對應資料庫欄位
  final List<String> coachIds; 
  final List<CoachModel> coaches;   
  final int bookingsCount;

  SessionModel({
    required this.id,
    required this.courseId,
    required this.startTime,
    required this.endTime,
    this.location,
    required this.maxCapacity,
    this.course,
    // 2. 設定預設值 (注意這裡的語法)
    this.coachIds = const [], 
    this.coaches = const [],  
    this.bookingsCount = 0,   
  });

  factory SessionModel.fromJson(Map<String, dynamic> json) {
    return SessionModel(
      id: json['id'],
      courseId: json['course_id'],
      startTime: DateTime.parse(json['start_time']).toLocal(),
      endTime: DateTime.parse(json['end_time']).toLocal(),
      location: json['location'],
      maxCapacity: json['max_capacity'] ?? 10,
      course: json['courses'] != null ? CourseModel.fromJson(json['courses']) : null,
      
      // 3. 確保這裡的參數名稱是 coachIds (複數)，且從 'coach_ids' 讀取
      coachIds: List<String>.from(json['coach_ids'] ?? []),
      
      // 預設為空，等待 Repository 填入
      coaches: const [], 
      
      bookingsCount: json['bookings_count'] ?? 0,
    );
  }

  // copyWith 方法
  SessionModel copyWith({
    List<CoachModel>? coaches, 
    int? bookingsCount,
    List<String>? coachIds,
  }) {
    return SessionModel(
      id: id,
      courseId: courseId,
      startTime: startTime,
      endTime: endTime,
      location: location,
      maxCapacity: maxCapacity,
      course: course,
      // 4. 這裡也要確保名稱對應正確
      coachIds: coachIds ?? this.coachIds,
      coaches: coaches ?? this.coaches, 
      bookingsCount: bookingsCount ?? this.bookingsCount,
    );
  }

  String get courseTitle => course?.title ?? '未命名課程';

  // 2. 取得價格
  int get price => course?.price ?? 0;

  // 3. 取得分類 (group/personal)
  String get category => course?.category ?? 'group';

  // 4. 取得分類顯示文字 (UI 用的 Tag)
  String get categoryText => category == 'personal' ? '一對一' : '團體課';

  // 5. 取得教練名單字串
  String get coachesText {
    if (coaches.isEmpty) return '教練待定';
    return coaches.map((c) => c.name).join(', ');
  }

  String? get description => course?.description;
}
