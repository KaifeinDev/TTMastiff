import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/booking_model.dart';

class BookingRepository {
  final SupabaseClient _supabase;

  BookingRepository(this._supabase);

  /// 建立預約
  ///
  /// [sessionId]: 課程場次 ID
  /// [studentId]: 指定上課的學員 ID
  /// [priceSnapshot]: 當下的課程價格 (紀錄快照，避免未來漲價影響歷史紀錄)
  Future<void> createBooking({
    required String sessionId,
    required String studentId,
    required int priceSnapshot,
  }) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('用戶未登入');

    try {
      // 1. 雙重確認：檢查該學員是否已報名此課程 (雖然 DB 有 unique constraint，但先檢查可以給出更友善的錯誤)
      final isBooked = await checkIfBooked(sessionId, studentId);
      if (isBooked) throw Exception('該學員已報名過此課程');

      // 2. 寫入資料
      await _supabase.from('bookings').insert({
        'user_id': userId,        // 父母 (帳號持有者)
        'student_id': studentId,  // 上課學員
        'session_id': sessionId,  // 課程場次
        'status': 'confirmed',    // 初始狀態
        'price_snapshot': priceSnapshot, // 紀錄當下價格
        'attendance_status': 'pending',  // 初始出席狀態
      });
    } catch (e) {
      // 捕捉資料庫層級的 Unique Constraint 錯誤 (作為最後一道防線)
      if (e.toString().contains('unique_student_session')) {
        throw Exception('該學員已報名過此課程，無需重複報名。');
      }
      throw Exception('報名失敗: $e');
    }
  }

  /// 檢查是否已報名 (回傳 true 代表已報名)
  Future<bool> checkIfBooked(String sessionId, String studentId) async {
    final count = await _supabase
        .from('bookings')
        .count(CountOption.exact)
        .eq('session_id', sessionId)
        .eq('student_id', studentId)
        .eq('status', 'confirmed'); // 只檢查已確認的狀態
    
    return count > 0;
  }

  /// 取得當前用戶的所有預約 (包含 Session, Course, Student 詳細資料)
  Future<List<BookingModel>> fetchMyBookings() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('用戶未登入');

    try {
      // 使用 Supabase 的 Nested Select 語法抓取關聯資料
      // sessions(*, courses(*)) -> 抓取場次，並同時抓取該場次的課程
      // students(*) -> 抓取學員資料
      final response = await _supabase
          .from('bookings')
          .select('*, sessions(*, courses(*)), students(*)')
          .eq('user_id', userId)
          .neq('status', 'cancelled') // 不顯示已取消的預約
          .order('created_at', ascending: false); // 最新的排前面

      // 將回傳的 List<dynamic> (Map) 轉換成 List<BookingModel>
      return (response as List)
          .map((data) => BookingModel.fromJson(data))
          .toList();
          
    } catch (e) {
      throw Exception('讀取預約紀錄失敗: $e');
    }
  }

  /// 取消預約 (邏輯刪除)
  Future<void> cancelBooking(String bookingId) async {
    try {
      // 將狀態更新為 'cancelled'
      await _supabase
          .from('bookings')
          .update({'status': 'cancelled'})
          .eq('id', bookingId);
      
      // 註：如果您的業務邏輯需要「物理刪除」(從資料庫移除)，請改用:
      // await _supabase.from('bookings').delete().eq('id', bookingId);
    } catch (e) {
      throw Exception('取消預約失敗: $e');
    }
  }
}
