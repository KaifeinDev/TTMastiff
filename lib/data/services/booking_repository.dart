import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/booking_model.dart';
import '../../core/utils/util.dart';
import 'credit_repository.dart';
import 'transaction_repository.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class BookingRepository {
  final SupabaseClient _supabase;
  final CreditRepository _creditRepo;
  final TransactionRepository _transactionRepo;
  static final RefreshSignal bookingRefreshSignal = RefreshSignal();
  BookingRepository(this._supabase, this._creditRepo, this._transactionRepo);

  /// 檢查同一學生在目標場次時間區間內，是否已經有其他「confirmed」課程（衝堂）。
  Future<bool> _hasTimeConflict({
    required String studentId,
    required String sessionId,
  }) async {
    // 先取得目標場次的時間區間
    final session = await _supabase
        .from('sessions')
        .select('start_time, end_time')
        .eq('id', sessionId)
        .maybeSingle();
    if (session == null) return false;

    final String startIso = session['start_time'] as String;
    final String endIso = session['end_time'] as String;

    // 查詢同一學生在此時間範圍內，是否有其他 confirmed booking
    final List<dynamic> rows = await _supabase
        .from('bookings')
        .select('id, session_id, sessions!inner(start_time, end_time)')
        .eq('student_id', studentId)
        .eq('status', 'confirmed')
        .neq('session_id', sessionId)
        // 時間重疊條件：已存在的課程 start_time < 目標 end_time 且 end_time > 目標 start_time
        .lt('sessions.start_time', endIso)
        .gt('sessions.end_time', startIso)
        .limit(1);

    return rows.isNotEmpty;
  }

  /// 提供給 UI / 其他層使用的公開衝堂檢查介面。
  Future<bool> hasTimeConflictForStudent({
    required String studentId,
    required String sessionId,
  }) {
    return _hasTimeConflict(studentId: studentId, sessionId: sessionId);
  }

  ///// 批量建立預約 (支援多位學生 x 多個場次)
  /// 邏輯：建立預約 -> 嘗試扣款 -> 若扣款失敗則回滾(刪除預約)
  Future<Map<String, dynamic>> createBatchBooking({
    required List<String> sessionIds,
    required List<String> studentIds,
    required int priceSnapshot,
    /// 單元測試用：有值時略過 [SupabaseClient.auth]，不依賴真實登入狀態。
    String? authUserIdOverride,
  }) async {
    final adminId = authUserIdOverride ?? _supabase.auth.currentUser?.id;
    if (adminId == null) throw Exception('未登入使用者');

    // 1. 查詢課程資訊 (包含 max_capacity)
    final List<dynamic> sessionsData = await _supabase
        .from('sessions')
        .select('id, max_capacity, start_time, courses(title)')
        .filter('id', 'in', sessionIds);

    final List<dynamic> studentsData = await _supabase
        .from('students')
        .select('id, name, parent_id')
        .filter('id', 'in', studentIds);

    // 建立 Map 加速查找
    final Map<String, String> studentOwnerMap = {};
    final Map<String, String> studentNameMap = {};

    for (var s in studentsData) {
      final sId = s['id'] as String;
      studentNameMap[sId] = s['name'] as String;
      // 確保資料庫有 user_id，如果沒有可能是孤兒資料
      if (s['parent_id'] != null) {
        studentOwnerMap[sId] = s['parent_id'] as String;
      }
    }

    final Map<String, dynamic> sessionInfoMap = {
      for (var s in sessionsData) s['id'] as String: s,
    };

    // 準備統計變數
    int successCount = 0;
    int skippedCount = 0;
    int totalDeducted = 0;
    final Set<String> alreadyBookedStudentIds = {};
    final Set<String> conflictedStudentIds = {};

    // 2. 雙重迴圈處理
    for (final studentId in studentIds) {
      final String studentName = studentNameMap[studentId] ?? '未知學生';
      final String? targetUserId = studentOwnerMap[studentId];
      if (targetUserId == null) {
        logError(
          Exception(
            '批量報名：學生 $studentName ($studentId) 無 user_id，已略過',
          ),
        );
        continue;
      }

      for (final sessionId in sessionIds) {
        final sessionData = sessionInfoMap[sessionId];
        final String courseName = sessionData['courses']['title'] ?? '課程';
        final int maxCapacity = sessionData['max_capacity'] ?? 0;
        final DateTime startTime = DateTime.parse(sessionData['start_time']);
        final String sessionTimeStr = DateFormat(
          'MM/dd HH:mm',
        ).format(startTime.toLocal());

        // 🔥 [檢查 1] 滿班檢查
        final int currentCount = await _supabase
            .from('bookings')
            .count(CountOption.exact)
            .eq('session_id', sessionId)
            .eq('status', 'confirmed');

        if (currentCount >= maxCapacity) {
          // 遇到滿班直接報錯中斷 (或是你可以選擇 continue 並記錄失敗，視需求而定)
          throw Exception(
            '報名失敗："$courseName" 該場次已額滿 ($currentCount/$maxCapacity)',
          );
        }

        // 🔥 [檢查 2] 衝堂檢查：同一學生在此時間區間內是否已有其他 confirmed 課程
        final hasConflict = await _hasTimeConflict(
          studentId: studentId,
          sessionId: sessionId,
        );
        if (hasConflict) {
          skippedCount++;
          conflictedStudentIds.add(studentId);
          logError(
            Exception(
              '批量報名：學生 $studentName ($studentId) 與 "$courseName" ($sessionTimeStr) 衝堂，已略過',
            ),
          );
          continue;
        }

        // 🔥 [檢查 3] 是否已存在紀錄
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
            // A-1. 已經報名成功 -> 略過
            skippedCount++;
            alreadyBookedStudentIds.add(studentId);
            continue;
          } else if (currentStatus == 'cancelled') {
            // A-2. 曾經報名但取消 -> 復活訂單 (Revive)

            // 1. 先更新狀態
            await _supabase
                .from('bookings')
                .update({
                  'status': 'confirmed',
                  'attendance_status': 'pending',
                  'price_snapshot': priceSnapshot,
                  'updated_at': DateTime.now().toIso8601String(), // 補上更新時間
                })
                .eq('id', bookingId);

            // 2. 嘗試扣款
            try {
              await _creditRepo.payForBooking(
                userId: targetUserId,
                cost: priceSnapshot,
                bookingId: bookingId,
                courseName: courseName,
                sessionInfo: sessionTimeStr,
                studentName: studentName,
                studentId: studentId,
              );

              // 成功統計
              successCount++;
              totalDeducted += priceSnapshot;
            } catch (e) {
              // 💥 扣款失敗，狀態改回 cancelled (Rollback)
              await _supabase
                  .from('bookings')
                  .update({'status': 'cancelled'})
                  .eq('id', bookingId);
              throw Exception('扣款失敗 (餘額不足或系統錯誤)');
            }
          }
        } else {
          // [情況 B] 全新報名 (New Booking)

          // 1. 建立預約
          final newBooking = await _supabase
              .from('bookings')
              .insert({
                'session_id': sessionId,
                'student_id': studentId,
                'user_id': targetUserId,
                'status': 'confirmed',
                'attendance_status': 'pending',
                'price_snapshot': priceSnapshot,
                'created_at': DateTime.now().toIso8601String(),
                // 'updated_at': DateTime.now().toIso8601String(),
              })
              .select()
              .single();

          final String newBookingId = newBooking['id'];

          // 2. 執行扣款
          try {
            await _creditRepo.payForBooking(
              userId: targetUserId,
              cost: priceSnapshot,
              bookingId: newBookingId,
              courseName: courseName,
              sessionInfo: sessionTimeStr,
              studentName: studentName,
              studentId: studentId,
            );

            // 成功統計
            successCount++;
            totalDeducted += priceSnapshot;
          } catch (e) {
            // 💥 扣款失敗，物理刪除預約 (Rollback)
            await _supabase.from('bookings').delete().eq('id', newBookingId);
            throw Exception('扣款失敗 (餘額不足或系統錯誤)');
          }
        }
      }
    }

    // 3. 通知 UI 刷新
    bookingRefreshSignal.notify();

    // 4. 回傳統計數據與略過原因
    return {
      'success': successCount,
      'skipped': skippedCount,
      'totalCost': totalDeducted,
      'alreadyBooked': alreadyBookedStudentIds.toList(),
      'conflicted': conflictedStudentIds.toList(),
    };
  }

  /// 🔥 [新增] 專門處理租桌/批次建立的預約與交易
  Future<void> createRentalBookings({
    required List<Map<String, dynamic>> rentalDataList,
  }) async {
    if (rentalDataList.isEmpty) return;

    List<Map<String, dynamic>> bookingsPayload = [];
    List<Map<String, dynamic>> transactionsPayload = [];

    for (var data in rentalDataList) {
      final String sessionId = data['session_id'];
      final String studentId = data['student_id'];
      final String? targetUserId = data['target_user_id']; // 從前端傳來的 Parent ID
      final int price = data['price'];
      final String paymentMethod = data['payment_method'];
      final Map<String, dynamic>? guestInfo = data['guest_info'];

      // 邏輯判斷：User ID (散客為 null，會員為 targetUserId)
      final bool isGuest = guestInfo != null;

      // 1. 準備 Booking
      bookingsPayload.add({
        'session_id': sessionId,
        'user_id': targetUserId,
        'student_id': studentId,
        'status': 'confirmed',
        'price_snapshot': price,
        'guest_name': guestInfo?['name'],
        'guest_phone': guestInfo?['phone'],
        'created_at': DateTime.now().toIso8601String(),
      });

      // 2. 準備 Transaction
      final bool isCash = paymentMethod == 'cash';
      transactionsPayload.add({
        'user_id': targetUserId,
        'type': isCash ? 'income' : 'spending',
        'amount': isCash ? price : -price,
        'payment_method': paymentMethod,
        'is_reconciled': !isCash,
        'status': 'valid',
        'created_at': DateTime.now().toIso8601String(),
        'description': isCash
            ? '現場租桌 (現金)${isGuest ? " - ${guestInfo['name']}" : ""}'
            : '租桌扣點',
      });
    }

    // 3. 執行批次寫入
    if (bookingsPayload.isNotEmpty) {
      await _supabase.from('bookings').insert(bookingsPayload);
    }
    if (transactionsPayload.isNotEmpty) {
      await _supabase.from('transactions').insert(transactionsPayload);
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

    // 收集所有 session 的 coach_ids 和 table_ids
    final Set<String> allCoachIds = {};
    final Set<String> allTableIds = {};
    for (var booking in data) {
      final session = booking['sessions'];
      if (session != null) {
        // 收集 coach_ids
        if (session['coach_ids'] != null) {
          final coachIds = List<String>.from(session['coach_ids'] ?? []);
          allCoachIds.addAll(coachIds);
        }
        // 收集 table_ids
        if (session['table_ids'] != null) {
          final tableIds = List<String>.from(session['table_ids'] ?? []);
          allTableIds.addAll(tableIds);
        }
      }
    }

    // 批量查詢教練資料
    Map<String, Map<String, dynamic>> coachMap = {};
    if (allCoachIds.isNotEmpty) {
      final coachesData = await _supabase
          .from('profiles')
          .select('id, full_name')
          .inFilter('id', allCoachIds.toList());

      coachMap = {for (var coach in coachesData) coach['id'] as String: coach};
    }

    // 批量查詢桌子資料
    Map<String, Map<String, dynamic>> tableMap = {};
    if (allTableIds.isNotEmpty) {
      final tablesData = await _supabase
          .from('tables')
          .select('id, name')
          .inFilter('id', allTableIds.toList());

      tableMap = {for (var table in tablesData) table['id'] as String: table};
    }

    // 將教練名稱和桌子名稱填入對應的 session
    for (var booking in data) {
      final session = booking['sessions'];
      if (session != null) {
        // 填入教練名稱
        if (session['coach_ids'] != null) {
          final coachIds = List<String>.from(session['coach_ids'] ?? []);
          final coachNames = coachIds
              .map((id) => coachMap[id]?['full_name'] as String?)
              .where((name) => name != null && name.isNotEmpty)
              .map((name) => name!)
              .toList();
          session['coach_name'] = coachNames.isEmpty
              ? null
              : coachNames.join(', ');
        }

        // 填入桌子名稱
        if (session['table_ids'] != null) {
          final tableIds = List<String>.from(session['table_ids'] ?? []);
          final tableNames = tableIds
              .map((id) => tableMap[id]?['name'] as String?)
              .where((name) => name != null && name.isNotEmpty)
              .map((name) => name!)
              .toList();
          session['table_names'] = tableNames.isEmpty
              ? null
              : tableNames.join('、');
        }
      }
    }

    return data.map((e) => BookingModel.fromJson(e)).toList();
  }

  /// 取得當前學生的所有預約 (包含 Session, Course, Student 詳細資料)
  Future<List<BookingModel>> fetchBookingsByStudentId(String studentId) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('未登入');

    // 設定時間界線 (今天以前)
    final limitDate = DateTime.now();

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
        .eq('student_id', studentId)
        .gte('sessions.end_time', limitDate.toIso8601String())
        .eq('status', 'confirmed')
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
          .select(
            'user_id, student_id, price_snapshot, status, sessions(courses(title), start_time), students(name)',
          )
          .eq('id', bookingId)
          .single();

      final String currentStatus = booking['status'];
      final int paidAmount = booking['price_snapshot'] ?? 0;
      final String userId = booking['user_id'];
      final String studentId = booking['student_id'];

      final String studentName = booking['students'] != null
          ? booking['students']['name']
          : '未知學生';

      final String courseTitle =
          booking['sessions']?['courses']?['title'] ?? '課程';
      final DateTime startTime = DateTime.parse(
        booking['sessions']?['start_time'],
      );
      final String sessionTimeStr = DateFormat(
        'MM/dd HH:mm',
      ).format(startTime.toLocal());

      if (currentStatus == 'cancelled') return;

      // 2. 更新狀態
      await _supabase
          .from('bookings')
          .update({'status': 'cancelled'})
          .eq('id', bookingId);

      // 3. 執行退費 (傳入 bookingId)
      if (paidAmount > 0) {
        await _transactionRepo.processRefund(
          userId: userId,
          amount: paidAmount,
          studentName: studentName,
          sessionInfo: sessionTimeStr,
          courseName: courseTitle,
          studentId: studentId,
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
  /// 修改：加入滿班檢查、復活舊單邏輯、以及自動扣款
  Future<void> createBooking({
    required String sessionId,
    required String studentId,
    required String userId, // 這是要被扣款的家長 ID
    required int priceSnapshot,
  }) async {
    // 1. 查詢課程資訊 (為了拿到 課程名稱 和 最大容量)
    final sessionData = await _supabase
        .from('sessions')
        .select('id, max_capacity, start_time,courses(title)')
        .eq('id', sessionId)
        .single();

    final studentData = await _supabase
        .from('students')
        .select('name')
        .eq('id', studentId)
        .single();
    final String studentName = studentData['name'] ?? '未知學生';

    final String courseName = sessionData['courses']['title'] ?? '課程';
    final int maxCapacity = sessionData['max_capacity'] ?? 0;
    final DateTime startTime = DateTime.parse(sessionData['start_time']);
    final String sessionTimeStr = DateFormat(
      'MM/dd HH:mm',
    ).format(startTime.toLocal());

    // 2. 滿班檢查
    final int currentCount = await _supabase
        .from('bookings')
        .count(CountOption.exact)
        .eq('session_id', sessionId)
        .eq('status', 'confirmed');

    if (currentCount >= maxCapacity) {
      throw Exception('新增失敗：該場次已額滿 ($currentCount/$maxCapacity)');
    }

    // 3. 衝堂檢查：同一學生在此時間區間內是否已有其他 confirmed 課程
    final hasConflict = await _hasTimeConflict(
      studentId: studentId,
      sessionId: sessionId,
    );
    if (hasConflict) {
      throw Exception('該學員同時段已有其他課程');
    }

    // 4. 檢查是否已存在紀錄 (避免重複 ID 或需要復活舊單)
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
            sessionInfo: sessionTimeStr,
            studentName: studentName,
            studentId: studentId,
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
          sessionInfo: sessionTimeStr,
          studentName: studentName,
          studentId: studentId,
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
