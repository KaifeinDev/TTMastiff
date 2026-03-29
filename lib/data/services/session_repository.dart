import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../../core/utils/util.dart';
import '../models/session_model.dart';
import 'credit_repository.dart';
import 'package:flutter/material.dart';
import 'package:ttmastiff/main.dart';

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
  final DateTime Function() _clock;

  SessionRepository(
    this._supabase,
    this._creditRepo, {
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

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
    } catch (e, st) {
      logError(e, st);
      return [];
    }
  }

  // 批次建立 Sessions (支援衝突檢查 + 租桌自動預約/記帳)
  Future<void> batchCreateSessions({
    required String courseId,
    required List<Map<String, dynamic>> sessionsData,
  }) async {
    if (sessionsData.isEmpty) return;

    // -----------------------------------------------------------------------
    // A. 預先檢查每一筆資料是否有衝突 (保持不變)
    // -----------------------------------------------------------------------
    for (var data in sessionsData) {
      // 1. 解析資料
      final startTime = DateTime.parse(data['start_time']);
      final endTime = DateTime.parse(data['end_time']);
      final tableIds = List<String>.from(data['table_ids'] ?? []);
      final coachIds = List<String>.from(data['coach_ids'] ?? []);

      // 2. 呼叫檢查
      final conflict = await checkDetailConflict(
        startTime: startTime,
        endTime: endTime,
        tableIds: tableIds,
        coachIds: coachIds,
        courseId: courseId,
      );

      // 3. 若有衝突，直接拋出錯誤，整批都不會建立
      if (conflict.hasConflict) {
        throw Exception(
          '衝突錯誤 (${DateFormat('MM/dd HH:mm').format(startTime)})：${conflict.message}',
        );
      }
    }

    // -----------------------------------------------------------------------
    // B. 建立 Sessions (只專注做這件事)
    // -----------------------------------------------------------------------

    // 1. 準備乾淨的 Session 資料
    final List<Map<String, dynamic>> cleanSessionsPayload = sessionsData.map((
      data,
    ) {
      final Map<String, dynamic> cleanData = Map.from(data);
      // 移除所有不屬於 Session 的擴充欄位
      cleanData.removeWhere(
        (key, value) => [
          'is_rental',
          'renter_id',
          'target_user_id',
          'payment_method',
          'guest_info',
          'price',
        ].contains(key),
      );

      cleanData['course_id'] = courseId;
      return cleanData;
    }).toList();

    // 2. 插入並取回 ID
    final List<dynamic> createdSessions = await _supabase
        .from('sessions')
        .insert(cleanSessionsPayload)
        .select();

    final List<String> createdSessionIds = createdSessions
        .map((s) => s['id'] as String)
        .toList();

    // -----------------------------------------------------------------------
    // C. 呼叫 BookingRepository 處理預約與金流
    // -----------------------------------------------------------------------
    try {
      // 組裝要交給 BookingRepo 的資料
      List<Map<String, dynamic>> rentalRequests = [];

      for (int i = 0; i < createdSessions.length; i++) {
        final originalData = sessionsData[i];
        final String sessionId = createdSessions[i]['id'];
        debugPrint(
          'student_id: ${originalData['renter_id']}\ntarget_user_id: ${originalData['target_user_id']}',
        );

        // 如果是租桌 (有 renter_id)
        if (originalData['renter_id'] != null) {
          rentalRequests.add({
            'session_id': sessionId,
            'student_id': originalData['renter_id'],
            'target_user_id': originalData['target_user_id'], // 前端傳來的 parent_id
            'price': originalData['price'] ?? 0,
            'payment_method': originalData['payment_method'] ?? 'credit',
            'guest_info': originalData['guest_info'],
          });
        }
      }

      // 🔥 直接呼叫 BookingRepository 的新功能！
      if (rentalRequests.isNotEmpty) {
        // 假設您可以存取 bookingRepository (視您的 Dependency Injection 方式而定)
        // 可能是 global 的 bookingRepository，或是透過建構子注入的
        await bookingRepository.createRentalBookings(
          rentalDataList: rentalRequests,
        );
      }
    } catch (e, st) {
      logError('建立預約失敗，回滾 Sessions...: $e', st);
      // Rollback 機制保持不變
      if (createdSessionIds.isNotEmpty) {
        await _supabase
            .from('sessions')
            .delete()
            .filter('id', 'in', createdSessionIds);
      }
      rethrow;
    }
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
    // A. 必須先抓取「目前的資料」，因為 update 可能只改時間沒改桌子
    // 我們需要完整的資料才能判斷衝突
    final currentData = await _supabase
        .from('sessions')
        .select()
        .eq('id', sessionId)
        .single();

    // B. 合併資料：如果有傳新值就用新的，否則用舊的
    final finalStartTime =
        startTime ?? DateTime.parse(currentData['start_time']);
    final finalEndTime = endTime ?? DateTime.parse(currentData['end_time']);
    final finalTableIds =
        tableIds ?? List<String>.from(currentData['table_ids'] ?? []);
    final finalCoachIds =
        coachIds ?? List<String>.from(currentData['coach_ids'] ?? []);
    final currentCourseId = currentData['course_id'];

    // C. 檢查衝突 (記得排除自己)
    final conflict = await checkDetailConflict(
      startTime: finalStartTime,
      endTime: finalEndTime,
      tableIds: finalTableIds,
      coachIds: finalCoachIds,
      courseId: currentCourseId,
      excludeSessionId: sessionId, // 🔥 關鍵：排除自己
    );

    if (conflict.hasConflict) {
      throw Exception(conflict.message);
    }

    // D. 準備更新 payload
    final Map<String, dynamic> updates = {};
    if (coachIds != null) updates['coach_ids'] = coachIds;
    if (location != null) updates['location'] = location;
    if (tableIds != null) updates['table_ids'] = tableIds;
    if (maxCapacity != null) updates['max_capacity'] = maxCapacity;
    if (startTime != null) updates['start_time'] = startTime.toIso8601String();
    if (endTime != null) updates['end_time'] = endTime.toIso8601String();

    if (updates.isNotEmpty) {
      await _supabase.from('sessions').update(updates).eq('id', sessionId);
    }
  }

  // 批次更新 Sessions
  // 用途：例如一次把選取的 5 堂課都改成「教練A」或都改成「桌號3」
  Future<void> batchUpdateSessions({
    required List<String> sessionIds, // 要更新的 IDs
    List<String>? coachIds,
    String? location,
    List<String>? tableIds,
    int? maxCapacity,
    // 通常批次更新不會改時間(因為每堂課時間不同)，但如果要改也可以傳
  }) async {
    if (sessionIds.isEmpty) return;

    // A. 抓出所有要修改的 Sessions 原本資料
    final List<dynamic> currentSessions = await _supabase
        .from('sessions')
        .select()
        .filter('id', 'in', sessionIds);

    // B. 逐筆檢查衝突
    for (var session in currentSessions) {
      final String id = session['id'];

      // 合併資料
      final DateTime currentStart = DateTime.parse(session['start_time']);
      final DateTime currentEnd = DateTime.parse(session['end_time']);

      final finalTableIds =
          tableIds ?? List<String>.from(session['table_ids'] ?? []);
      final finalCoachIds =
          coachIds ?? List<String>.from(session['coach_ids'] ?? []);
      final String courseId = session['course_id'];

      // 呼叫檢查
      final conflict = await checkDetailConflict(
        startTime: currentStart, // 時間通常維持原樣
        endTime: currentEnd,
        tableIds: finalTableIds, // 用新的桌子 (如果有的話)
        coachIds: finalCoachIds, // 用新的教練 (如果有的話)
        courseId: courseId,
        excludeSessionId: id, // 排除自己
      );

      if (conflict.hasConflict) {
        // 為了讓使用者知道是哪一堂出錯，可以格式化時間
        final timeStr = DateFormat('MM/dd HH:mm').format(currentStart);
        throw Exception('批次更新失敗：$timeStr 的課程發生衝突 (${conflict.message})');
      }
    }

    // C. 全部檢查通過，執行批次更新
    // 因為 Supabase 的 .update().in_() 會把所有選取的 rows 更新成一樣的值
    // 這剛好符合「批次修改屬性」的需求
    final Map<String, dynamic> updates = {};
    if (coachIds != null) updates['coach_ids'] = coachIds;
    if (location != null) updates['location'] = location;
    if (tableIds != null) updates['table_ids'] = tableIds;
    if (maxCapacity != null) updates['max_capacity'] = maxCapacity;

    if (updates.isNotEmpty) {
      await _supabase
          .from('sessions')
          .update(updates)
          .filter('id', 'in', sessionIds);
    }
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
    final DateTime now = _clock();

    // ⛔ [新增保護] 如果是歷史場次 (已結束)，禁止刪除
    if (endTime.isBefore(now)) {
      throw Exception('無法刪除歷史場次！\n已結束的課程屬於公司營運歷史，禁止刪除。');
    }

    // 判斷是否需要退款
    // 邏輯：如果課程還沒結束 (endTime 在現在之後)，則視為「取消」，需要退款
    final bool shouldRefund = endTime.isAfter(now);

    if (shouldRefund) {
      // 找出所有「已確認 (confirmed)」的預約，並關聯學生資料
      final List<dynamic> bookings = await _supabase
          .from('bookings')
          .select('*, students(id, name)')
          .eq('session_id', sessionId)
          .eq('status', 'confirmed'); // 只退款有效訂單

      if (bookings.isNotEmpty) {
        debugPrint('正在為 Session $sessionId 執行退款，共 ${bookings.length} 筆...');

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
            } catch (e, st) {
              logError('退款失敗 (User: $userId): $e', st);
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
    required List<String> tableIds,
    required List<String> coachIds,
    required String courseId,
    String? excludeSessionId,
  }) async {
    // 1. 查詢時間重疊的 Session
    final response = await _supabase
        .from('sessions')
        .select('''
          id, start_time, end_time, 
          course_id, table_ids, coach_ids,
          courses(title)
        ''')
        .lt('start_time', endTime.toIso8601String())
        .gt('end_time', startTime.toIso8601String());

    final List<dynamic> existingSessions = response;

    // 🔥 準備一個清單來收集所有錯誤
    List<String> conflictDetails = [];

    for (final session in existingSessions) {
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

      // 為了讓訊息更清楚，我們把時間也抓出來
      final sTime = DateTime.parse(session['start_time']).toLocal();
      final eTime = DateTime.parse(session['end_time']).toLocal();
      final timeStr =
          "${DateFormat('HH:mm').format(sTime)}~${DateFormat('HH:mm').format(eTime)}";

      // 檢查 1 : 同課程重複
      if (existingCourseId == courseId) {
        conflictDetails.add('❌ [課程重複] $timeStr "$courseName"');
      }

      // 檢查 2: 桌次衝突
      final overlappingTableIds = tableIds
          .where((id) => existingTableIds.contains(id))
          .toList();
      if (overlappingTableIds.isNotEmpty) {
        // 查詢桌名 (非同步操作)
        final List<dynamic> tablesRes = await _supabase
            .from('tables')
            .select('name')
            .filter('id', 'in', overlappingTableIds);

        final String occupiedTableNames = tablesRes
            .map((t) => t['name'] as String)
            .join('、');

        conflictDetails.add(
          '❌ [桌次佔用] $timeStr "$courseName" (桌次: $occupiedTableNames)',
        );
      }

      // 檢查 3: 教練衝突
      final overlappingCoachIds = coachIds
          .where((id) => existingCoachIds.contains(id))
          .toList();
      if (overlappingCoachIds.isNotEmpty) {
        final List<dynamic> coachesRes = await _supabase
            .from('profiles')
            .select('full_name')
            .filter('id', 'in', overlappingCoachIds);

        final String busyCoachNames = coachesRes
            .map((c) => c['full_name'] as String? ?? '未知教練')
            .join('、');

        conflictDetails.add(
          '❌ [教練撞期] $timeStr "$courseName" (教練: $busyCoachNames)',
        );
      }
    }

    // 🔥 判斷是否收集到錯誤
    if (conflictDetails.isNotEmpty) {
      // 將所有錯誤組合成一個長字串，中間用換行符號隔開
      final fullMessage = conflictDetails.join('\n');

      return ConflictResult(
        type: ConflictType.tableOccupied, // 這裡 Type 其實沒那麼重要了，主要是 Message
        message: '發現 ${conflictDetails.length} 個衝突：\n$fullMessage',
      );
    }

    return ConflictResult(type: ConflictType.none);
  }

  /// 一次抓取一段時間範圍內的課程 (用於週曆視圖)
  Future<List<SessionModel>> fetchSessionsByRange(
    DateTime start,
    DateTime end,
  ) async {
    final response = await _supabase
        .from('sessions')
        .select('*, courses(*)') // 根據您的 DB 結構調整
        .gte('start_time', start.toIso8601String())
        .lte('end_time', end.toIso8601String());

    final data = response as List<dynamic>;
    return data.map((json) => SessionModel.fromJson(json)).toList();
  }
}
