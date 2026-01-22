import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/session_model.dart';
import '../models/course_model.dart';
import 'package:flutter/material.dart';

import '../../core/utils/time_extensions.dart';

class CourseRepository {
  static final RefreshSignal courseRefreshSignal = RefreshSignal();
  final SupabaseClient _supabase;

  CourseRepository(this._supabase);

  // ==========================================
  // 核心私有方法：標準化查詢字串
  // ==========================================
  // 統一查詢欄位：包含 Session 本體、關聯的 Course、以及計算確認的報名人數
  // 注意：這裡使用 count 語法 'bookings(count)' 會回傳 { "bookings": [{"count": 3}] }

  // ==========================================
  // 公開方法
  // ==========================================

  /// 取得特定星期幾有開課的「課程列表」
  /// 邏輯：抓未來 45 天的場次 -> 過濾星期幾 -> 取出不重複課程
  Future<List<CourseModel>> fetchCoursesByWeekday(int weekday) async {
    final start = DateTime.now();
    final end = start.add(const Duration(days: 45));

    try {
      final response = await _supabase
          .from('sessions')
          .select('*, courses!inner(*)') // 這裡只需要 course 資訊
          .gte('start_time', start.toIso8601String())
          .lte('start_time', end.toIso8601String())
          .eq('courses.is_published', true);

      final sessions = (response as List)
          .map((e) => SessionModel.fromJson(e))
          .toList();

      // 1. 過濾出指定星期幾 (Dart 層過濾)
      final filteredSessions = sessions.where(
        (s) => s.startTime.weekday == weekday,
      );

      // 2. 取出 Course 並去重
      final Map<String, CourseModel> uniqueCourses = {};
      for (var s in filteredSessions) {
        if (s.course != null) {
          // 使用 Map key 自動去重
          uniqueCourses[s.course!.id] = s.course!;
        }
      }

      return uniqueCourses.values.toList();
    } catch (e) {
      throw Exception('載入週間課程失敗: $e');
    }
  }

  /// 取得所有未來即將開始的課程場次
  Future<List<SessionModel>> fetchUpcomingSessions() async {
    try {
      final response = await _supabase
          .from('sessions')
          // 直接在 Select 裡過濾已確認的報名數
          .select('*, courses(*), bookings(count)')
          .eq('bookings.status', 'confirmed') // 只計算 status='confirmed' 的
          .gte('start_time', DateTime.now().toIso8601String())
          .order('start_time', ascending: true);

      // 注意：這裡不需要再做二次查詢，因為基本的 SessionModel.fromJson
      // 已經可以處理 bookings(count) 了
      return (response as List)
          .map((data) => SessionModel.fromJson(data))
          .toList();
    } catch (e) {
      throw Exception('載入課程列表失敗: $e');
    }
  }

  /// 取得單一場次詳情 (完整版)
  /// 包含：Course 資訊、報名人數、教練詳細資料
  Future<SessionModel> fetchSessionDetail(String sessionId) async {
    try {
      // 1. 一次查完 Session + Course + Bookings Count
      final response = await _supabase
          .from('sessions')
          .select('*, courses(*), bookings(count)')
          .eq('bookings.status', 'confirmed') // 過濾條件
          .eq('id', sessionId)
          .single();

      var session = SessionModel.fromJson(response);

      // 2. 處理教練名單 (二次查詢)
      // 因為 PostgREST 目前不支援直接 JOIN uuid[] 陣列，所以必須分開查
      if (session.coachIds.isNotEmpty) {
        final coachesData = await _supabase
            .from('profiles')
            .select('id, full_name, role') // 雖然 model 沒有 role，但可以順便檢查
            .inFilter('id', session.coachIds); // 使用 inFilter 更簡潔

        final coachNames = (coachesData as List)
            .map((c) => c['full_name'] as String? ?? '教練')
            .where((name) => name.isNotEmpty)
            .toList();

        session = session.copyWith(
          coachName: coachNames.isEmpty ? null : coachNames.join(', '),
        );
      }

      return session;
    } catch (e) {
      throw Exception('載入課程詳情失敗: $e');
    }
  }

  Future<CourseModel> fetchCourseById(String courseId) async {
    try {
      final response = await _supabase
          .from('courses')
          .select()
          .eq('id', courseId)
          .single();

      return CourseModel.fromJson(response);
    } catch (e) {
      throw Exception('找不到課程資訊: $e');
    }
  }

  /// 取得特定課程 ID 的未來所有場次
  Future<List<SessionModel>> fetchUpcomingSessionsByCourseId(
    String courseId,
  ) async {
    final now = DateTime.now().toIso8601String();

    try {
      final response = await _supabase
          .from('sessions')
          .select('*, courses(*), bookings(count)') // 記得加 bookings(count)
          .eq('bookings.status', 'confirmed')
          .eq('course_id', courseId)
          .gte('start_time', now)
          .order('start_time', ascending: true);

      return (response as List).map((e) => SessionModel.fromJson(e)).toList();
    } catch (e) {
      throw Exception('載入課程場次失敗: $e');
    }
  }

  /// 取得特定日期的所有場次
  Future<List<SessionModel>> fetchSessionsByDate(DateTime date) async {
    final startOfDay = DateTime(date.year, date.month, date.day);
    // 結束時間設為當天 23:59:59.999
    final endOfDay = startOfDay
        .add(const Duration(days: 1))
        .subtract(const Duration(milliseconds: 1));

    try {
      final response = await _supabase
          .from('sessions')
          .select('*, courses(*), bookings(count)') // 統一加上 count
          .eq('bookings.status', 'confirmed')
          .gte('start_time', startOfDay.toIso8601String())
          .lte('start_time', endOfDay.toIso8601String())
          .order('start_time', ascending: true);

      // 這裡如果為了效能，可以選擇「不」去查教練名字，
      // 只有在進入詳情頁 (Detail Page) 時才查。
      // 所以這裡只回傳基本資料。
      return (response as List)
          .map((data) => SessionModel.fromJson(data))
          .toList();
    } catch (e) {
      throw Exception('載入當日課程失敗: $e');
    }
  }

  // 🔥 [修改] 取得所有課程模板 -> 回傳 List<CourseModel>
  Future<List<CourseModel>> getCourses() async {
    final data = await _supabase
        .from('courses')
        .select('*')
        .order('created_at', ascending: false);

    // 將資料庫的 Map 轉換成 CourseModel 物件
    return (data as List).map((e) => CourseModel.fromJson(e)).toList();
  }

  // 🔥 [修改] 取得單一課程資訊 -> 回傳 CourseModel
  Future<CourseModel> getCourseById(String courseId) async {
    final data = await _supabase
        .from('courses')
        .select('*')
        .eq('id', courseId)
        .single();

    return CourseModel.fromJson(data);
  }

  // 建立課程模板 (回傳 ID，維持原樣)
  Future<String> createCourse({
    required String title,
    required String category,
    required int price,
    String? description,
    required DateTime defaultStartTime,
    required DateTime defaultEndTime,
  }) async {
    final res = await _supabase
        .from('courses')
        .insert({
          'title': title,
          'category': category,
          'price': price,
          'description': description,
          'default_start_time': defaultStartTime.toPostgresTimeString(),
          'default_end_time': defaultEndTime.toPostgresTimeString(),
          'is_published': true,
        })
        .select()
        .single();
    courseRefreshSignal.notify();
    return res['id'];
  }

  // 更新課程模板 (維持原樣，參數傳入比較彈性)
  Future<void> updateCourse({
    required String courseId,
    required String title,
    required String category,
    required int price,
    String? description,
    required DateTime defaultStartTime,
    required DateTime defaultEndTime,
  }) async {
    await _supabase
        .from('courses')
        .update({
          'title': title,
          'category': category,
          'price': price,
          'description': description,
          'default_start_time': defaultStartTime.toPostgresTimeString(),
          'default_end_time': defaultEndTime.toPostgresTimeString(),
        })
        .eq('id', courseId);
    courseRefreshSignal.notify();
  }

  // 切換課程的 上架/下架 (封存) 狀態
  Future<void> toggleCoursePublishStatus(
    String courseId,
    bool currentStatus,
  ) async {
    try {
      await _supabase
          .from('courses')
          .update({'is_published': !currentStatus}) // 反轉狀態
          .eq('id', courseId);

      // 通知 UI 刷新
      courseRefreshSignal.notify();
    } catch (e) {
      throw Exception('更新課程狀態失敗: $e');
    }
  }

  // 刪除課程模板
  Future<void> deleteCourse(String courseId) async {
    // 1. 檢查是否有任何場次 (包含過去與未來)
    final int totalSessions = await _supabase
        .from('sessions')
        .count(CountOption.exact)
        .eq('course_id', courseId);

    // ⛔ 只要有任何紀錄，就禁止物理刪除，引導使用者去「下架」
    if (totalSessions > 0) {
      throw Exception(
        '無法刪除課程！\n'
        '此課程包含 $totalSessions 筆場次資料 (含歷史紀錄)。\n\n'
        '為了保留帳務與出席歷史，請使用「下架 (封存)」功能來隱藏此課程，\n'
        '而非直接刪除。',
      );
    }

    // 2. 只有完全乾淨的空殼課程，才允許物理刪除
    try {
      await _supabase.from('courses').delete().eq('id', courseId);
      courseRefreshSignal.notify();
    } catch (e) {
      throw Exception('刪除失敗: $e');
    }
  }
}

class RefreshSignal extends ChangeNotifier {
  // 把受保護的 notifyListeners 包裝成公開方法
  void notify() {
    notifyListeners();
  }
}
