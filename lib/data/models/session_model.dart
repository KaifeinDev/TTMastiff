import 'course_model.dart'; // 記得 import 剛剛改好的 CourseModel
import 'table_model.dart';

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
  final List<String> tableIds;
  final List<TableModel> tables;

  /// Session 專屬價格 (若為 null 則繼承 Course 價格)
  final int? _sessionPrice;

  final List<String> coachIds;
  final String? coachName; // 教練名稱（多個教練用逗號分隔）
  final int bookingsCount;
  final List<String> studentNames;

  SessionModel({
    required this.id,
    required this.courseId,
    required this.startTime,
    required this.endTime,
    this.location,
    required this.maxCapacity,
    this.course,
    this.tableIds = const [],
    this.tables = const [],
    int? sessionPrice,
    this.coachIds = const [],
    this.coachName,
    this.bookingsCount = 0,
    required this.studentNames,
  }) : _sessionPrice = sessionPrice;

  factory SessionModel.fromJson(Map<String, dynamic> json) {
    final bookingsData = json['bookings'];

    // 提取學生名字 (只抓 confirmed 的)
    List<String> names = [];

    // 判斷 bookingsData 是否為 List 且包含資料 (避免 null 或空)
    if (bookingsData is List) {
      names = bookingsData
          .where(
            (b) =>
                b is Map && b['status'] == 'confirmed' && b['students'] != null,
          )
          .map((b) => b['students']['name'] as String)
          .toList();
    }
    int count = 0;

    // 判斷是否為詳細資料模式 (檢查第一筆資料是否有 students 欄位)
    bool isDetailedList = false;
    if (bookingsData is List &&
        bookingsData.isNotEmpty &&
        bookingsData.first is Map) {
      if (bookingsData.first.containsKey('students')) {
        isDetailedList = true;
      }
    }

    if (isDetailedList) {
      count = names.length; // ✅ 詳細模式：人數 = 名單長度
    } else {
      count = _parseCount(bookingsData); // ✅ 列表模式：用 count 欄位
    }
    List<String> parsedTableIds = [];
    if (json['table_ids'] != null && json['table_ids'] is List) {
      parsedTableIds = (json['table_ids'] as List)
          .where((e) => e != null) // 關鍵：過濾掉 null 元素
          .map((e) => e.toString()) // 確保轉為 String
          .toList();
    }

    List<TableModel> parsedTables = [];
    if (json['tables'] != null && json['tables'] is List) {
      parsedTables = (json['tables'] as List)
          .map((t) => TableModel.fromJson(t))
          .toList();
    }

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
      tableIds: parsedTableIds,
      tables: parsedTables,

      // 讀取 DB 的 uuid[] 陣列
      coachIds: List<String>.from(json['coach_ids'] ?? []),

      // 讀取教練名稱（如果 Repository 層已經填入）
      coachName: json['coach_name'] as String?,

      // ⚠️ 關鍵修正：處理 Supabase 的 Count 回傳格式
      // 如果是用 .select('*, bookings(count)')，格式會是 { "bookings": [{"count": 5}] }
      bookingsCount: count,

      sessionPrice: json['price'],
      studentNames: names,
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
    String? id,
    String? courseId,
    DateTime? startTime,
    DateTime? endTime,
    String? location,
    int? maxCapacity,
    CourseModel? course,
    List<String>? tableIds,
    List<TableModel>? tables,
    int? sessionPrice,
    List<String>? coachIds,
    String? coachName,
    int? bookingsCount,
    List<String>? studentNames, // 參數名稱建議統一，原本叫 names 容易混淆
  }) {
    return SessionModel(
      id: id ?? this.id,
      courseId: courseId ?? this.courseId,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      location: location ?? this.location,
      maxCapacity: maxCapacity ?? this.maxCapacity,

      course: course ?? this.course,
      tableIds: tableIds ?? this.tableIds,
      tables: tables ?? this.tables,

      sessionPrice: sessionPrice ?? _sessionPrice,

      // 5. 列表與統計
      coachIds: coachIds ?? this.coachIds,
      coachName: coachName ?? this.coachName,
      bookingsCount: bookingsCount ?? this.bookingsCount,
      studentNames: studentNames ?? this.studentNames,
    );
  }

  // Getters
  int get remainingCapacity {
    final remaining = maxCapacity - bookingsCount;
    return remaining < 0 ? 0 : remaining; // 避免負數顯示
  }

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
    if (coachName == null || coachName!.isEmpty) return '教練待定';
    return coachName!;
  }

  /// 判斷是否額滿
  bool get isFull => bookingsCount >= maxCapacity;

  // 取得所有桌名的字串 (例如 "A桌、B桌")
  String get tableNames {
    if (tables.isEmpty) return '未指定';
    return tables.map((t) => t.name).join('、');
  }
}
