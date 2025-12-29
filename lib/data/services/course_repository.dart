import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/course_model.dart';

class CourseRepository {
  final SupabaseClient _supabase;

  // 建構子注入 SupabaseClient，方便之後測試
  CourseRepository(this._supabase);

  // 取得所有已發布的課程
  Future<List<Course>> getPublishedCourses() async {
    try {
      // 1. 向 Supabase 請求資料
      // select() 代表 SELECT *
      // order() 做排序，這裡依照開始時間排序
      final response = await _supabase
          .from('courses')
          .select()
          .eq('is_published', true) // 只抓已上架的
          .order('start_time', ascending: true);

      // 2. 將 List<Map> 轉換成 List<Course>
      // response 本身就是 List<dynamic> (Maps)
      final List<dynamic> data = response as List<dynamic>;
      
      return data.map((json) => Course.fromJson(json)).toList();
      
    } catch (e) {
      // 實際開發建議用 Logger 記錄錯誤
      print('Error fetching courses: $e');
      rethrow; // 把錯誤丟出去讓 UI 決定怎麼顯示 (例如跳 Alert)
    }
  }

  Future<Course?> getCourseById(String courseId) async {
    try {
      final response = await _supabase
          .from('courses')
          .select()
          .eq('id', courseId)
          .single(); // .single() 確保只回傳一筆物件

      return Course.fromJson(response);
    } catch (e) {
      print('Error fetching course details: $e');
      return null;
    }
  }

  Future<void> bookCourse({
    required String courseId, 
    required String userId, 
    required String studentId,
    required int maxCapacity
  }) async {
    try {
      // 1. 檢查目前的報名人數 (status = 'confirmed')
      // 使用 count() 來只抓取數量，節省流量
      final currentCount = await _supabase
          .from('bookings')
          .count(CountOption.exact) // 取得精確數量
          .eq('course_id', courseId)
          .eq('status', 'confirmed');
      
      // 2. 判斷是否額滿
      if (currentCount >= maxCapacity) {
        throw Exception('名額已滿');
      }

      // 3. 檢查是否已經報名過 (防止重複報名)
      // 這是一個選擇性的檢查，看你的商業邏輯是否允許重複報名
      final existingBooking = await _supabase
          .from('bookings')
          .select()
          .eq('course_id', courseId)
          .eq('user_id', userId)
          .eq('student_id', studentId)
          .maybeSingle(); // 如果沒資料回傳 null，不會報錯

      if (existingBooking != null) {
        throw Exception('該學員已經報名過此課程');
      }

      // 4. 寫入報名資料
      await _supabase.from('bookings').insert({
        'user_id': userId,
        'student_id': studentId,
        'course_id': courseId,
        'status': 'confirmed',
        'created_at': DateTime.now().toIso8601String(),
      });

    } catch (e) {
      print('Booking error: $e');
      rethrow; // 把錯誤丟回 UI 層處理
    }
  }
}
