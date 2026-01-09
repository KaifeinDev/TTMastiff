import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/booking_model.dart';
import 'credit_repository.dart';
import 'package:flutter/material.dart';

class BookingRepository {
  final SupabaseClient _supabase;
  final CreditRepository _creditRepo;
  static final RefreshSignal bookingRefreshSignal = RefreshSignal();
  BookingRepository(this._supabase, this._creditRepo);

  ///// 批量建立預約 (支援多位學生 x 多個場次)
  /// 邏輯：建立預約 -> 嘗試扣款 -> 若扣款失敗則回滾(刪除預約)
  Future<void> createBatchBooking({
    required List<String> sessionIds,
    required List<String> studentIds,
    required int price_snapshot, // 課程價格
  }) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('未登入使用者');

    // --- 步驟 1: 預先查詢課程名稱 (用於扣款明細) ---
    // 修正：使用 filter 替代 in_，並對應 courses 表的 title 欄位
    final List<dynamic> sessionsData = await _supabase
        .from('sessions')
        .select('id, courses(title)') // 課程名稱欄位是 title
        .filter('id', 'in', sessionIds); // 修正語法錯誤

    // 建立 Map: { sessionId: courseTitle }
    final Map<String, String> sessionCourseMap = {
      for (var s in sessionsData)
        s['id'] as String: (s['courses']?['title'] as String?) ?? '未知課程',
    };

    // --- 步驟 2: 開始報名迴圈 ---
    for (final studentId in studentIds) {
      for (final sessionId in sessionIds) {
        final courseName = sessionCourseMap[sessionId] ?? '課程';

        // 檢查是否已存在紀錄
        final existing = await _supabase
            .from('bookings')
            .select()
            .eq('session_id', sessionId)
            .eq('student_id', studentId)
            .maybeSingle();

        if (existing != null) {
          // [情況 A] 資料已存在 (可能是之前取消的)
          final String currentStatus = existing['status'] ?? 'confirmed';
          final String bookingId = existing['id'];

          // 如果是被取消的單，將其復活並扣款
          if (currentStatus == 'cancelled') {
            // A-1. 先更新狀態為 confirmed (復活)
            await _supabase
                .from('bookings')
                .update({
                  'status': 'confirmed',
                  'attendance_status': 'pending',
                  'price_snapshot': price_snapshot, //
                  'updated_at': DateTime.now().toIso8601String(),
                })
                .eq('id', bookingId);

            // 🔥 A-2. 嘗試扣款
            try {
              await _creditRepo.payForBooking(
                userId: userId,
                cost: price_snapshot,
                bookingId: bookingId,
                courseName: courseName,
              );
            } catch (e) {
              // 💥 扣款失敗 (餘額不足)，回滾 (Rollback)
              // 把狀態改回 cancelled，當作沒報名過
              await _supabase
                  .from('bookings')
                  .update({'status': 'cancelled'})
                  .eq('id', bookingId);

              throw Exception(
                '扣款失敗，報名已取消: ${e.toString().replaceAll('Exception:', '')}',
              );
            }
          }
          // 如果已經是 confirmed，則跳過 (不重複扣款)
        } else {
          // [情況 B] 全新報名 (Insert)

          // B-1. 建立預約並「立即回傳資料」以取得 ID
          final newBooking = await _supabase
              .from('bookings')
              .insert({
                'user_id': userId,
                'student_id': studentId,
                'session_id': sessionId,
                'status': 'confirmed',
                'attendance_status': 'pending',
                'price_snapshot': price_snapshot, //
                'created_at': DateTime.now().toIso8601String(),
              })
              .select()
              .single();

          final String newBookingId = newBooking['id'];

          // 🔥 B-2. 嘗試扣款
          try {
            await _creditRepo.payForBooking(
              userId: userId,
              cost: price_snapshot,
              bookingId: newBookingId,
              courseName: courseName,
            );
          } catch (e) {
            // 💥 扣款失敗，物理刪除剛剛建立的預約 (Rollback)
            await _supabase.from('bookings').delete().eq('id', newBookingId);

            throw Exception('點數不足，報名失敗');
          }
        }
      }
    }
    bookingRefreshSignal.notify();
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

  /// 1. 取得指定場次 (Session) 的所有預約名單
  Future<List<BookingModel>> fetchBookingsBySessionId(String sessionId) async {
    final response = await _supabase
        .from('bookings')
        .select('''
          *,
          students (*),
          sessions (
            *,
            courses (*)
          )
        ''')
        .eq('session_id', sessionId)
        // 排除已取消的嗎？通常管理員還是想看到取消的人，所以全抓，在 UI 判斷顏色
        .order('created_at', ascending: true);

    final data = List<Map<String, dynamic>>.from(response);
    return data.map((e) => BookingModel.fromJson(e)).toList();
  }

  /// 2. 更新預約狀態 (簽到、請假、取消)
  Future<void> updateBookingStatus({
    required String bookingId,
    required String status, // 'confirmed', 'cancelled'
    required String
    attendanceStatus, // 'pending', 'attended', 'leave', 'absent'
  }) async {
    await _supabase
        .from('bookings')
        .update({'status': status, 'attendance_status': attendanceStatus})
        .eq('id', bookingId);
  }

  /// 3. 幫學生新增預約 (管理員手動加入)
  Future<void> createBooking({
    required String sessionId,
    required String studentId,
    required String userId, // 家長/User ID
    required int priceSnapshot, // 當下的價格
  }) async {
    await _supabase.from('bookings').insert({
      'session_id': sessionId,
      'student_id': studentId,
      'user_id': userId,
      'status': 'confirmed',
      'attendance_status': 'pending', // 預設為待上課
      'price_snapshot': priceSnapshot,
    });
  }
}

class RefreshSignal extends ChangeNotifier {
  // 把受保護的 notifyListeners 包裝成公開方法
  void notify() {
    notifyListeners();
  }
}
