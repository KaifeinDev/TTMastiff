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

    try {
      // 1. 先抓取 Sessions (不直接 Join tables，因為 array join 支援度不好)
      final response = await _supabase
          .from('sessions')
          .select('''
            *,
            courses:course_id (*),
            bookings:bookings (
              id,
              status,
              students:student_id (name)
            )
          ''')
          .gte('start_time', startOfDay.toIso8601String())
          .lte('end_time', endOfDay.toIso8601String())
          .order('start_time', ascending: true);

      final List<dynamic> sessionsData = List<Map<String, dynamic>>.from(
        response,
      );

      // 2. 收集所有出現過的 table_ids
      final Set<String> allTableIds = {};
      for (var session in sessionsData) {
        if (session['table_ids'] != null) {
          final ids = List<String>.from(session['table_ids']);
          allTableIds.addAll(ids);
        }
      }

      // 3. 如果有桌子，手動抓取 Table 資料 (Manual Join)
      if (allTableIds.isNotEmpty) {
        final tablesResponse = await _supabase
            .from('tables')
            .select()
            .inFilter('id', allTableIds.toList());

        // 建立 ID -> Table 物件的 Map 方便查找
        final tableMap = {for (var t in tablesResponse) t['id'] as String: t};

        // 4. 將 Table 資料塞回 Session JSON 中，讓 Model 解析
        for (var session in sessionsData) {
          final ids = session['table_ids'] != null
              ? List<String>.from(session['table_ids'])
              : <String>[];

          // 找出對應的 table 物件列表
          final tableObjects = ids
              .map((id) => tableMap[id])
              .where((t) => t != null)
              .toList();

          // 塞入 'tables' 欄位 (模擬 Supabase Join 的格式)
          session['tables'] = tableObjects;
        }
      }

      return sessionsData.map((json) => SessionModel.fromJson(json)).toList();
    } catch (e) {
      debugPrint('Error fetching sessions: $e');
      return [];
    }
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
    final response = await _supabase
        .from('sessions')
        .select('''
          *,
          courses (*),
          bookings (
             status,
             students (name) 
          )
        ''')
        .eq('course_id', courseId)
        .order('start_time');
    final List<dynamic> sessionsData = List<Map<String, dynamic>>.from(
      response,
    );

    // 2. 收集所有出現過的 table_ids
    final Set<String> allTableIds = {};
    for (var session in sessionsData) {
      if (session['table_ids'] != null) {
        final ids = List<String>.from(session['table_ids']);
        allTableIds.addAll(ids);
      }
    }

    // 3. 如果有桌子，手動抓取 Table 資料 (Manual Join)
    if (allTableIds.isNotEmpty) {
      final tablesResponse = await _supabase
          .from('tables')
          .select()
          .inFilter('id', allTableIds.toList());
      final tableMap = {for (var t in tablesResponse) t['id'] as String: t};

      // 4. 將 Table 資料塞回 Session JSON 中
      for (var session in sessionsData) {
        final ids = session['table_ids'] != null
            ? List<String>.from(session['table_ids'])
            : <String>[];

        // 找出對應的 table 物件列表
        final tableObjects = ids
            .map((id) => tableMap[id])
            .where((t) => t != null)
            .toList();

        // 塞入 'tables' 欄位
        session['tables'] = tableObjects;
      }
    }

    // 5. 轉換為 Model
    return sessionsData.map((e) => SessionModel.fromJson(e)).toList();
  }

  // 更新單一場次
  Future<void> updateSession({
    required String sessionId,
    List<String>? coachIds,
    String? location,
    List<String>? tableIds,
    int? maxCapacity,
    DateTime? startTime,
    DateTime? endTime,
  }) async {
    final Map<String, dynamic> updates = {};
    if (coachIds != null) updates['coach_ids'] = coachIds;
    if (location != null) updates['location'] = location;
    if (tableIds != null) updates['table_ids'] = tableIds;
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
    required List<String> tableIds, // 🔥 改為 List
    required List<String> coachIds,
    required String courseId,
    String? excludeSessionId,
  }) async {
    // 取得當天範圍內的 sessions 來比對
    // 這裡為了保險，我們把搜尋範圍擴大一點 (例如前後 1 天)，或精準搜尋該時段重疊
    // 簡單起見，我們用 "該時段有重疊" 的條件查詢 DB

    // Supabase 查詢：時間重疊 (StartA < EndB) AND (EndA > StartB)
    final response = await _supabase
        .from('sessions')
        .select('''
          id, course_id, table_ids, coach_ids,
          courses(title)
        ''')
        // 時間重疊邏輯: session.start < request.end AND session.end > request.start
        .lt('start_time', endTime.toIso8601String())
        .gt('end_time', startTime.toIso8601String());

    final List<dynamic> existingSessions = response;

    for (final session in existingSessions) {
      // 排除自己
      if (excludeSessionId != null && session['id'] == excludeSessionId) {
        continue;
      }

      final List<String> existingTableIds = List<String>.from(
        session['table_ids'] ?? [],
      );
      final existingCourseId = session['course_id'];
      final List<String> existingCoachIds = List<String>.from(
        session['coach_ids'] ?? [],
      );

      final courseName = session['courses']?['title'] ?? '未知課程';

      // 檢查 1 : 同課程重複 (同一門課不能同時開兩班)
      if (existingCourseId == courseId) {
        return ConflictResult(
          type: ConflictType.courseDuplicate,
          message: '課程 "$courseName" 於該時段已有其他場次',
          conflictSessionId: session['id'],
        );
      }

      // 檢查 2: 桌次衝突 (陣列交集檢查)
      // 如果新選的桌子裡，有任何一張已經被別人用了，就是衝突
      final overlappingTables = tableIds.where(
        (id) => existingTableIds.contains(id),
      );
      if (overlappingTables.isNotEmpty) {
        return ConflictResult(
          type: ConflictType.tableOccupied,
          message: '所選桌次已被 "$courseName" 佔用', // 簡化訊息，不列出具體哪一張
          conflictSessionId: session['id'],
        );
      }

      // 檢查 3: 教練衝突
      final overlappingCoaches = coachIds.where(
        (id) => existingCoachIds.contains(id),
      );
      if (overlappingCoaches.isNotEmpty) {
        // ... 可選擇要不要去抓教練名字來顯示
        return ConflictResult(
          type: ConflictType.coachBusy,
          message: '指定教練該時段已有安排課程 "$courseName"',
          conflictSessionId: session['id'],
        );
      }
    }

    return ConflictResult(type: ConflictType.none);
  }
}
