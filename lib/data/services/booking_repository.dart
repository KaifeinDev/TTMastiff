import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/booking_model.dart';
import 'package:flutter/material.dart';

class BookingRepository {
  final SupabaseClient _supabase;
  static final RefreshSignal bookingRefreshSignal = RefreshSignal();
  BookingRepository(this._supabase);

  /// 批量建立預約 (支援多位學生 x 多個場次)
  /// 自動處理：若已取消則復活 (Update)，若無紀錄則新增 (Insert)
  Future<void> createBatchBooking({
    required List<String> sessionIds,
    required List<String> studentIds,
    required int price_snapshot, // 🔥 新增這個參數接收價格
  }) async {
    // 1. 在這裡直接取得 userId，UI 就不用傳了
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('未登入使用者');

    // 雙重迴圈：遍歷所有選中的學生
    for (final studentId in studentIds) {
      // 遍歷該學生選中的所有場次
      for (final sessionId in sessionIds) {
        // 檢查是否已存在紀錄
        final existing = await _supabase
            .from('bookings')
            .select()
            .eq('session_id', sessionId)
            .eq('student_id', studentId)
            .maybeSingle();

        if (existing != null) {
          // --- 情況 A: 資料已存在 ---
          final String currentStatus = existing['status'] ?? 'confirmed';

          // 如果是被取消的單，將其復活
          if (currentStatus == 'cancelled') {
            await _supabase
                .from('bookings')
                .update({
                  'status': 'confirmed',
                  'attendance_status': 'pending',
                  'price_snapshot': price_snapshot, // 🔥 更新為最新的價格
                  'updated_at': DateTime.now().toIso8601String(),
                })
                .eq('id', existing['id']);
          }
          bookingRefreshSignal.notify();

          // 如果已經是 confirmed，則跳過
        } else {
          // --- 情況 B: 全新報名 (Insert) ---
          await _supabase.from('bookings').insert({
            'user_id': userId,
            'student_id': studentId,
            'session_id': sessionId,
            'status': 'confirmed',
            'attendance_status': 'pending',
            'price_snapshot': price_snapshot, // 🔥 寫入價格快照
            'created_at': DateTime.now().toIso8601String(),
          });
          bookingRefreshSignal.notify();
        }
      }
    }
  }

  /// 取得當前用戶的所有預約 (包含 Session, Course, Student 詳細資料)
  Future<List<BookingModel>> fetchMyBookings() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('未登入');

    // 設定時間界線 (例如：只抓 90 天前的歷史 + 未來所有課程)
    final limitDate = DateTime.now().subtract(const Duration(days: 90));

    final response = await _supabase
        .from('bookings')
        .select('''
          *,
          sessions!inner (
            *,
            courses (*)
          ),
          students (*)
        ''')
        .eq('user_id', userId)
        .gte('sessions.end_time', limitDate.toIso8601String())
        .order('sessions(start_time)', ascending: false);
    final data = List<Map<String, dynamic>>.from(response);
    return data.map((e) => BookingModel.fromJson(e)).toList();
  }

  /// 取消預約 (邏輯刪除)
  Future<void> cancelBooking(String bookingId) async {
    try {
      // 將狀態更新為 'cancelled'
      await _supabase
          .from('bookings')
          .update({'status': 'cancelled'})
          .eq('id', bookingId);

      bookingRefreshSignal.notify();
      // 註：如果您的業務邏輯需要「物理刪除」(從資料庫移除)，請改用:
      // await _supabase.from('bookings').delete().eq('id', bookingId);
    } catch (e) {
      throw Exception('取消預約失敗: $e');
    }
  }

  // 請假
  Future<void> requestLeave(String bookingId) async {
    // 將 attendance_status 設為 'leave' (請假)
    await _supabase
        .from('bookings')
        .update({'attendance_status': 'leave'})
        .eq('id', bookingId);
    bookingRefreshSignal.notify();
  }
}

class RefreshSignal extends ChangeNotifier {
  // 把受保護的 notifyListeners 包裝成公開方法
  void notify() {
    notifyListeners();
  }
}
