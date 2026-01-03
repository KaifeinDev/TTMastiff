import 'package:supabase_flutter/supabase_flutter.dart';

// 🔥 請確保您的路徑正確，並引入 Models
import '../models/course_model.dart';
import '../models/session_model.dart';
import '../../core/utils/time_extensions.dart';

class AdminRepository {
  final SupabaseClient _supabase;

  AdminRepository(this._supabase);

  // --- 1. 教練相關 ---

  // 取得教練列表 (給下拉選單用)
  // 註：這裡維持回傳 Map 是因為可能還沒有 "CoachModel"，且只是簡單顯示名字用
  Future<List<Map<String, dynamic>>> getCoaches() async {
    final data = await _supabase
        .from('profiles')
        .select('id, full_name')
        .eq('role', 'coach');
    return List<Map<String, dynamic>>.from(data);
  }

  // --- 2. 課程模板 (Course) 相關 ---

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
  }

  // --- 3. 場次 (Session) 相關 ---

  // 批次建立 Sessions (維持原樣，建立時通常還是傳 Map 比較方便)
  Future<void> batchCreateSessions({
    required String courseId,
    required List<Map<String, dynamic>> sessionsData,
  }) async {
    if (sessionsData.isEmpty) return;

    final List<Map<String, dynamic>> payload = sessionsData.map((data) {
      return {'course_id': courseId, ...data};
    }).toList();

    await _supabase.from('sessions').insert(payload);
  }

  // 🔥 [修改] 取得指定 Course 的所有 Sessions -> 回傳 List<SessionModel>
  Future<List<SessionModel>> getSessionsByCourse(String courseId) async {
    final data = await _supabase
        .from('sessions')
        .select('*')
        .eq('course_id', courseId)
        .order('start_time');

    return (data as List).map((e) => SessionModel.fromJson(e)).toList();
  }

  // 更新單一場次
  Future<void> updateSession({
    required String sessionId,
    List<String>? coachIds,
    String? location,
    int? maxCapacity,
    DateTime? startTime,
    DateTime? endTime,
  }) async {
    final Map<String, dynamic> updates = {};
    if (coachIds != null) updates['coach_ids'] = coachIds;
    if (location != null) updates['location'] = location;
    if (maxCapacity != null) updates['max_capacity'] = maxCapacity;
    if (startTime != null) updates['start_time'] = startTime.toIso8601String();
    if (endTime != null) updates['end_time'] = endTime.toIso8601String();

    await _supabase.from('sessions').update(updates).eq('id', sessionId);
  }

  // 刪除單一場次
  Future<void> deleteSession(String sessionId) async {
    await _supabase.from('sessions').delete().eq('id', sessionId);
  }

  /// 刪除課程模板
  Future<void> deleteCourse(String courseId) async {
    try {
      await _supabase.from('courses').delete().eq('id', courseId);
    } catch (e) {
      // 這裡可能會捕捉到 Foreign Key Constraint 錯誤
      // 實際專案中，可能需要先檢查是否有現存 Session，或者由資料庫 CASCADE 處理
      throw Exception('刪除課程失敗: $e');
    }
  }
}
