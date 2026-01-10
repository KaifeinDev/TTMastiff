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
    required int price_snapshot,
  }) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('未登入使用者');

    // 1. 查詢課程資訊 (包含 max_capacity)
    final List<dynamic> sessionsData = await _supabase
        .from('sessions')
        .select('id, max_capacity, courses(title)') // 記得抓取 max_capacity
        .filter('id', 'in', sessionIds);

    // 建立 Map 方便查找: { sessionId: SessionData }
    final Map<String, dynamic> sessionInfoMap = {
      for (var s in sessionsData) s['id'] as String: s,
    };

    // 雙重迴圈：遍歷所有選中的學生
    for (final studentId in studentIds) {
      for (final sessionId in sessionIds) {
        final sessionData = sessionInfoMap[sessionId];
        final String courseName = sessionData['courses']['title'] ?? '課程';
        final int maxCapacity = sessionData['max_capacity'] ?? 0;

        // 🔥 [新增] 滿班檢查 (Capacity Check)
        // 檢查目前該場次 "已確認 (confirmed)" 的報名人數
        final int currentCount = await _supabase
            .from('bookings')
            .count(CountOption.exact)
            .eq('session_id', sessionId)
            .eq('status', 'confirmed');

        // 如果目前人數已經 >= 最大容量，拋出錯誤
        if (currentCount >= maxCapacity) {
          throw Exception(
            '報名失敗："$courseName" 該場次已額滿 ($currentCount/$maxCapacity)',
          );
        }

        // --- 檢查是否已存在紀錄 ---
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

          if (currentStatus == 'cancelled') {
            // A-1. 復活訂單
            await _supabase
                .from('bookings')
                .update({
                  'status': 'confirmed',
                  'attendance_status': 'pending',
                  'price_snapshot': price_snapshot,
                  'updated_at': DateTime.now().toIso8601String(),
                })
                .eq('id', bookingId);

            // A-2. 扣款 (使用 RPC)
            try {
              await _creditRepo.payForBooking(
                userId: userId,
                cost: price_snapshot,
                bookingId: bookingId,
                courseName: courseName,
              );
            } catch (e) {
              // 💥 扣款失敗，狀態改回 cancelled (Rollback)
              await _supabase
                  .from('bookings')
                  .update({'status': 'cancelled'})
                  .eq('id', bookingId);
              throw Exception('扣款失敗：餘額不足');
            }
          }
          // 如果已經是 confirmed，跳過
        } else {
          // [情況 B] 全新報名

          // B-1. 建立預約
          final newBooking = await _supabase
              .from('bookings')
              .insert({
                'user_id': userId,
                'student_id': studentId,
                'session_id': sessionId,
                'status': 'confirmed',
                'attendance_status': 'pending',
                'price_snapshot': price_snapshot,
                'created_at': DateTime.now().toIso8601String(),
              })
              .select()
              .single();

          final String newBookingId = newBooking['id'];

          // B-2. 扣款
          try {
            await _creditRepo.payForBooking(
              userId: userId,
              cost: price_snapshot,
              bookingId: newBookingId,
              courseName: courseName,
            );
          } catch (e) {
            // 💥 扣款失敗，物理刪除預約 (Rollback)
            await _supabase.from('bookings').delete().eq('id', newBookingId);
            throw Exception('扣款失敗：餘額不足');
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

  /// 取消預約 (並執行退費)
  Future<void> cancelBooking(String bookingId) async {
    try {
      // 1. 查詢預約資訊
      final booking = await _supabase
          .from('bookings')
          .select('user_id, price_snapshot, status, sessions(courses(title))')
          .eq('id', bookingId)
          .single();

      final String currentStatus = booking['status'];
      final int paidAmount = booking['price_snapshot'] ?? 0;
      final String userId = booking['user_id'];
      final String courseTitle =
          booking['sessions']?['courses']?['title'] ?? '課程';

      if (currentStatus == 'cancelled') return;

      // 2. 更新狀態
      await _supabase
          .from('bookings')
          .update({'status': 'cancelled'})
          .eq('id', bookingId);

      // 3. 🔥 執行退費 (傳入 bookingId)
      if (paidAmount > 0) {
        await _creditRepo.processRefund(
          userId: userId,
          amount: paidAmount,
          description: '取消報名退費: $courseTitle',
          bookingId: bookingId, // 傳入 ID 以建立關聯
        );
      }

      bookingRefreshSignal.notify();
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

  /// 2. 更新預約狀態 (出席、請假、曠課)
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
  /// 3. 幫學生新增預約 (管理員手動加入)
  /// 🔥 修改：加入滿班檢查、復活舊單邏輯、以及自動扣款
  Future<void> createBooking({
    required String sessionId,
    required String studentId,
    required String userId, // 這是要被扣款的家長 ID
    required int priceSnapshot,
  }) async {
    // 1. 查詢課程資訊 (為了拿到 課程名稱 和 最大容量)
    final sessionData = await _supabase
        .from('sessions')
        .select('id, max_capacity, courses(title)')
        .eq('id', sessionId)
        .single();

    final String courseName = sessionData['courses']['title'] ?? '課程';
    final int maxCapacity = sessionData['max_capacity'] ?? 0;

    // 2. 滿班檢查
    final int currentCount = await _supabase
        .from('bookings')
        .count(CountOption.exact)
        .eq('session_id', sessionId)
        .eq('status', 'confirmed');

    if (currentCount >= maxCapacity) {
      throw Exception('新增失敗：該場次已額滿 ($currentCount/$maxCapacity)');
    }

    // 3. 檢查是否已存在紀錄 (避免重複 ID 或需要復活舊單)
    final existing = await _supabase
        .from('bookings')
        .select()
        .eq('session_id', sessionId)
        .eq('student_id', studentId)
        .maybeSingle();

    if (existing != null) {
      // [情況 A] 資料已存在
      final String currentStatus = existing['status'] ?? 'confirmed';
      final String bookingId = existing['id'];

      if (currentStatus == 'confirmed') {
        throw Exception('該學生已經報名過此課程');
      }

      if (currentStatus == 'cancelled') {
        // A-1. 復活訂單 (Update)
        await _supabase
            .from('bookings')
            .update({
              'status': 'confirmed',
              'attendance_status': 'pending',
              'price_snapshot': priceSnapshot,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', bookingId);

        // A-2. 執行扣款
        try {
          await _creditRepo.payForBooking(
            userId: userId,
            cost: priceSnapshot,
            bookingId: bookingId,
            courseName: courseName,
          );
        } catch (e) {
          // 💥 扣款失敗，狀態改回 cancelled (Rollback)
          await _supabase
              .from('bookings')
              .update({'status': 'cancelled'})
              .eq('id', bookingId);
          throw Exception('扣款失敗：${e.toString()}'); // 拋出錯誤讓 UI 顯示
        }
      }
    } else {
      // [情況 B] 全新報名 (Insert)

      // B-1. 建立預約
      final newBooking = await _supabase
          .from('bookings')
          .insert({
            'session_id': sessionId,
            'student_id': studentId,
            'user_id': userId,
            'status': 'confirmed',
            'attendance_status': 'pending',
            'price_snapshot': priceSnapshot,
            'created_at': DateTime.now().toIso8601String(),
          })
          .select()
          .single();

      final String newBookingId = newBooking['id'];

      // B-2. 執行扣款
      try {
        await _creditRepo.payForBooking(
          userId: userId,
          cost: priceSnapshot,
          bookingId: newBookingId,
          courseName: courseName,
        );
      } catch (e) {
        // 💥 扣款失敗，物理刪除剛建立的預約 (Rollback)
        await _supabase.from('bookings').delete().eq('id', newBookingId);
        throw Exception('扣款失敗：${e.toString()}');
      }
    }

    // 通知 UI 更新
    bookingRefreshSignal.notify();
  }
}

class RefreshSignal extends ChangeNotifier {
  // 把受保護的 notifyListeners 包裝成公開方法
  void notify() {
    notifyListeners();
  }
}
