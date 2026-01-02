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
            .select('id, full_name') // 只抓需要的欄位
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

  Future<List<SessionModel>> fetchSessionsByDate(DateTime date) async {
    // 設定當天的起始與結束時間 (例如 2024-01-01 00:00:00 ~ 23:59:59)
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1)).subtract(const Duration(milliseconds: 1));

    try {
      final response = await _supabase
          .from('sessions')
          .select('*, courses(*)') // Join 課程資料
          .gte('start_time', startOfDay.toIso8601String())
          .lte('start_time', endOfDay.toIso8601String())
          .order('start_time', ascending: true);

      // 轉換資料 (注意：這裡暫時沒包含 fetchSessionDetail 裡的教練二次查詢邏輯以保持列表讀取速度)
      // 如果需要在列表顯示教練名字，建議在此處加上類似 fetchSessionDetail 的二次查詢邏輯
      // 或者依賴 Supabase Function 簡化查詢。
      // 這裡先回傳基本資料：
      
      var sessions = (response as List)
          .map((data) => SessionModel.fromJson(data))
          .toList();

      // (選擇性) 如果列表一定要顯示教練名字，需在此處補上教練查詢邏輯
      // 若無此需求，上述程式碼即可運作
      return sessions;

    } catch (e) {
      throw Exception('載入當日課程失敗: $e');
    }
  }
}
