import 'course_model.dart'; // 記得 import 剛剛改好的 CourseModel

/// 定義教練模型 (對應 public.profiles)
class CoachModel {
  final String id;
  final String name;
  final String? avatarUrl;

  CoachModel({required this.id, required this.name, this.avatarUrl});

  factory CoachModel.fromJson(Map<String, dynamic> json) {
    return CoachModel(
      id: json['id'],
      // DB 欄位是 full_name
      name: json['full_name'] ?? '教練',
      // 目前 DB profiles 表沒有 avatar_url，
      // 這裡預留欄位，若之後有 Join metadata 或用 UI 生成圖時可用
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

  /// Session 專屬價格 (若為 null 則繼承 Course 價格)
  final int? _sessionPrice;

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
    int? sessionPrice,
    this.coachIds = const [],
    this.coaches = const [],
    this.bookingsCount = 0,
  }) : _sessionPrice = sessionPrice;

  factory SessionModel.fromJson(Map<String, dynamic> json) {
    return SessionModel(
      id: json['id'],
      courseId: json['course_id'],
      // Session 的時間是 timestamptz (完整日期時間)，直接 parse 即可，不需要像 Course 那樣補日期
      // if the time is not right, check device time zone
      startTime: DateTime.parse(json['start_time']).toLocal(),
      endTime: DateTime.parse(json['end_time']).toLocal(),

      location: json['location'],
      maxCapacity: json['max_capacity'] ?? 4,

      // 關聯讀取 Course
      course: json['courses'] != null
          ? CourseModel.fromJson(json['courses'])
          : null,

      // 讀取 DB 的 uuid[] 陣列
      coachIds: List<String>.from(json['coach_ids'] ?? []),

      // 這裡先給空值，通常會在 Repository 層再另外 fetch 或 map 進來
      coaches: const [],

      // ⚠️ 關鍵修正：處理 Supabase 的 Count 回傳格式
      // 如果是用 .select('*, bookings(count)')，格式會是 { "bookings": [{"count": 5}] }
      bookingsCount: _parseCount(json['bookings']),

      sessionPrice: json['price'],
    );
  }

  // 🛠️ 輔助函式：解析 Supabase 的 Count
  static int _parseCount(dynamic bookingsData) {
    if (bookingsData is int) return bookingsData; // 如果是用 View
    if (bookingsData is List && bookingsData.isNotEmpty) {
      // 處理 .select('..., bookings(count)')
      return bookingsData.first['count'] as int? ?? 0;
    }
    return 0;
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
      sessionPrice: _sessionPrice,
      coachIds: coachIds ?? this.coachIds,
      coaches: coaches ?? this.coaches,
      bookingsCount: bookingsCount ?? this.bookingsCount,
    );
  }

  // Getters

  String get courseTitle => course?.title ?? '未命名課程';
  String? get description => course?.description;
  String? get imageUrl => course?.imageUrl;

  /// 💰 智慧價格：優先使用單堂定價，沒有則使用課程定價
  int get displayPrice {
    if (_sessionPrice != null) return _sessionPrice;
    return course?.price ?? 0;
  }

  /// 課程分類 (group/personal)
  String get category => course?.category ?? 'group';

  /// UI 顯示用的標籤文字
  String get categoryText {
    if (category == 'personal') return '一對一';
    return '團體課';
  }

  /// 顯示教練名單
  String get coachesText {
    if (coaches.isEmpty) return '教練待定';
    return coaches.map((c) => c.name).join(', ');
  }

  /// 判斷是否額滿
  bool get isFull => bookingsCount >= maxCapacity;
}
