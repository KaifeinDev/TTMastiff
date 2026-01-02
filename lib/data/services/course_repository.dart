import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/session_model.dart';

class CourseRepository {
  final SupabaseClient _supabase;

  CourseRepository(this._supabase);

  /// 取得所有未來即將開始的課程場次
  ///
  /// 會關聯查詢 (Join) 取得對應的 Course 資訊
  Future<List<SessionModel>> fetchUpcomingSessions() async {
    try {
      final response = await _supabase
          .from('sessions')
          .select('*, courses(*)') // Join courses 表格
          .gte('start_time', DateTime.now().toIso8601String()) // 只抓未來的
          .order('start_time', ascending: true); // 依照時間排序

      return (response as List)
          .map((data) => SessionModel.fromJson(data))
          .toList();
    } catch (e) {
      throw Exception('載入課程列表失敗: $e');
    }
  }

  /// 取得單一場次詳情
  ///
  /// 包含：
  /// 1. Session 本體資料
  /// 2. 關聯的 Course 資料
  /// 3. 即時計算的已報名人數 (bookings count)
  /// 4. 解析 coach_ids 並查詢對應的教練姓名 (Profiles)
  Future<SessionModel> fetchSessionDetail(String sessionId) async {
    try {
      // 步驟 1: 抓取 Session 本體與 Course 資料
      final sessionResponse = await _supabase
          .from('sessions')
          .select('*, courses(*)')
          .eq('id', sessionId)
          .single();

      // 步驟 2: 抓取目前已確認的報名人數
      // 使用 count(CountOption.exact) 避免拉取所有資料，節省流量
      final bookingsCount = await _supabase
          .from('bookings')
          .count(CountOption.exact)
          .eq('session_id', sessionId)
          .eq('status', 'confirmed');

      // 先將資料轉換為基本的 Model
      var session = SessionModel.fromJson(sessionResponse);

      // 步驟 3: 處理教練資訊 (若 coach_ids 不為空)
      if (session.coachIds.isNotEmpty) {
        // 二次查詢：根據 ID 列表去 profiles 表抓取名字
        final coachesData = await _supabase
            .from('profiles')
            .select('id, full_name, avatar_url') // 只抓需要的欄位
            .filter('id', 'in', session.coachIds); 
        
        // 轉換為 Coach 物件列表
        final coachesList = (coachesData as List)
            .map((c) => CoachModel.fromJson(c)) 
            .toList();

        // 將教練資料填入 session 物件
        session = session.copyWith(coaches: coachesList);
      }

      // 步驟 4: 將人數與最終結果回傳
      return session.copyWith(bookingsCount: bookingsCount);

    } catch (e) {
      // 建議在實際專案中記錄詳細 Log
      throw Exception('載入課程詳情失敗: $e');
    }
  }
}
