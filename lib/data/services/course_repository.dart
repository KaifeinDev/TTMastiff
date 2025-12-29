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
}
