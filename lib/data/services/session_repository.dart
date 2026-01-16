import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../models/session_model.dart';
import 'credit_repository.dart';
import 'package:flutter/material.dart';

enum ConflictType {
  none, // 無衝突
  tableOccupied, // 桌次已被佔用
  coachBusy, // 教練該時段已有課
  courseDuplicate, // 同課程同時間重複 (選用)
}

class ConflictResult {
  final ConflictType type;
  final String? message; // 顯示給使用者的詳細訊息
  final String? conflictSessionId; // 撞到哪一堂課

  ConflictResult({
    this.type = ConflictType.none,
    this.message,
    this.conflictSessionId,
  });

  bool get hasConflict => type != ConflictType.none;
}

class SessionRepository {
  final SupabaseClient _supabase;
  final CreditRepository _creditRepo;
  SessionRepository(this._supabase, this._creditRepo);

  // 📅 抓取特定日期的所有課程
  Future<List<SessionModel>> fetchSessionsByDate(DateTime date) async {
    // 設定當天的 00:00:00 到 23:59:59
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay
        .add(const Duration(days: 1))
        .subtract(const Duration(seconds: 1));

    final response = await _supabase
        .from('sessions')
        .select('''
          *,
          course:courses(*)
        ''')
        .gte('start_time', startOfDay.toIso8601String())
        .lte('start_time', endOfDay.toIso8601String())
        .order('start_time', ascending: true);

    final data = response as List<dynamic>;
    return data.map((e) => SessionModel.fromJson(e)).toList();
  }

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
        .select('''
          *,
          courses (*),
          bookings (
             status,
             students (name) 
          ),
          tables (*)
        ''')
        .eq('course_id', courseId)
        .order('start_time');

    return (data as List).map((e) => SessionModel.fromJson(e)).toList();
  }

  // 更新單一場次
  Future<void> updateSession({
    required String sessionId,
    List<String>? coachIds,
    String? location,
    String? tableId,
    int? maxCapacity,
    DateTime? startTime,
    DateTime? endTime,
  }) async {
    final Map<String, dynamic> updates = {};
    if (coachIds != null) updates['coach_ids'] = coachIds;
    if (location != null) updates['location'] = location;
    if (tableId != null) updates['table_id'] = tableId;
    if (maxCapacity != null) updates['max_capacity'] = maxCapacity;
    if (startTime != null) updates['start_time'] = startTime.toIso8601String();
    if (endTime != null) updates['end_time'] = endTime.toIso8601String();

    await _supabase.from('sessions').update(updates).eq('id', sessionId);
  }

  // 刪除單一場次
  Future<void> deleteSession(String sessionId) async {
    final sessionData = await _supabase
        .from('sessions')
        .select('*, courses(title)')
        .eq('id', sessionId)
        .single();
    final DateTime endTime = DateTime.parse(sessionData['end_time']).toLocal();
    final DateTime startTime = DateTime.parse(
      sessionData['start_time'],
    ).toLocal();
    final String courseTitle = sessionData['courses']['title'] ?? '未知課程';
    final String sessionTimeStr = DateFormat('MM/dd HH:mm').format(startTime);
    final DateTime now = DateTime.now();

    // ⛔ [新增保護] 如果是歷史場次 (已結束)，禁止刪除
    if (endTime.isBefore(now)) {
      throw Exception('無法刪除歷史場次！\n已結束的課程屬於公司營運歷史，禁止刪除。');
    }

    // 判斷是否需要退款
    // 邏輯：如果課程還沒結束 (endTime 在現在之後)，則視為「取消」，需要退款
    final bool shouldRefund = endTime.isAfter(DateTime.now());

    if (shouldRefund) {
      // 找出所有「已確認 (confirmed)」的預約，並關聯學生資料
      final List<dynamic> bookings = await _supabase
          .from('bookings')
          .select('*, students(id, name)')
          .eq('session_id', sessionId)
          .eq('status', 'confirmed'); // 只退款有效訂單

      if (bookings.isNotEmpty) {
        print('正在為 Session $sessionId 執行退款，共 ${bookings.length} 筆...');

        // 4. 逐筆退款
        // 雖然是迴圈，但 processRefund 是 RPC 交易，安全性足夠。
        // 量大時可考慮寫新的 Batch Refund RPC，但目前單堂課人數少，這樣做 OK。
        for (final booking in bookings) {
          final int amount = booking['price_snapshot'] ?? 0;
          final String userId = booking['user_id'];
          final String bookingId = booking['id'];
          final studentData = booking['students'];
          final String studentName = studentData?['name'] ?? '未知學生';
          final String studentId = studentData?['id'] ?? '';

          if (amount > 0) {
            try {
              await _creditRepo.processRefund(
                userId: userId,
                amount: amount,
                bookingId: bookingId,
                courseName: courseTitle,
                sessionInfo: sessionTimeStr,
                studentName: studentName,
                studentId: studentId,
                reason: '課程取消',
              );
            } catch (e) {
              print('退款失敗 (User: $userId): $e');
              // 這裡可以選擇是否中斷，或是繼續退別人的
              // 建議 log 下來，繼續執行，以免卡住刪除流程
            }
          }
        }
      }
    }
    // 執行物理刪除 (僅限未來場次)
    // DB 設定了 ON DELETE CASCADE，所以 bookings 會自動消失
    await _supabase.from('sessions').delete().eq('id', sessionId);
  }

  /// 詳細檢查撞期邏輯
  Future<ConflictResult> checkDetailConflict({
    required DateTime startTime,
    required DateTime endTime,
    required String? tableId, // 欲排的桌次
    required List<String> coachIds, // 欲排的教練 ID 列表
    required String courseId,
    String? excludeSessionId, // 排除自己 (編輯模式用)
  }) async {
    // 1. 強制轉 UTC，確保與資料庫標準一致
    // 邏輯：搜尋「所有」與此時段重疊的 Session
    // Overlap: (Existing.Start < New.End) AND (Existing.End > New.Start)
    final startStr = startTime.toUtc().toIso8601String();
    final endStr = endTime.toUtc().toIso8601String();

    debugPrint('🔍 檢查區間(UTC): $startStr ~ $endStr');

    var query = _supabase.from('sessions').select('''
      id, 
      table_id, 
      coach_ids, 
      start_time, 
      end_time,
      tables(name),
      courses(title)
    ''');

    // 2. 時間重疊查詢 (先抓大範圍，再過濾)
    final List<dynamic> candidates = await query
        .lt('start_time', endStr)
        .gt('end_time', startStr);

    // 3. 在 Dart 端逐筆檢查衝突原因
    for (var session in candidates) {
      // 排除自己
      if (excludeSessionId != null && session['id'] == excludeSessionId) {
        continue;
      }

      final existingTableId = session['table_id'];
      final existingCourseId = session['course_id'];
      final List<dynamic> existingCoachIds = session['coach_ids'] ?? [];
      final courseName = session['courses']?['title'] ?? '未知課程';
      final tableName = session['tables']?['name'] ?? '未知桌次';

      // 檢查 1 : 同課程重複
      // 只要是同一門課 (courseId 相同)，不管在哪一桌，都不能重疊
      if (existingCourseId == courseId) {
        return ConflictResult(
          type: ConflictType.courseDuplicate,
          message: '課程 "$courseName" 於該時段已有其他場次 (不可同時開兩場)',
          conflictSessionId: session['id'],
        );
      }

      // 檢查 2: 桌次衝突
      if (tableId != null && existingTableId == tableId) {
        return ConflictResult(
          type: ConflictType.tableOccupied,
          message: '該時段 "$tableName" 已有安排 "$courseName"',
          conflictSessionId: session['id'],
        );
      }

      // 檢查 3: 教練衝突 (如果有指定教練)
      // 檢查新舊教練名單是否有交集
      final hasCommonCoach = coachIds.any(
        (id) => existingCoachIds.contains(id),
      );
      if (hasCommonCoach) {
        return ConflictResult(
          type: ConflictType.coachBusy,
          message: '教練於該時段已有其他課程 ($courseName)',
          conflictSessionId: session['id'],
        );
      }
    }

    // ✅ 通過所有檢查
    return ConflictResult(type: ConflictType.none);
  }
}
