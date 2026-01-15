import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../models/session_model.dart';
import 'credit_repository.dart';

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
        .select('*')
        .eq('course_id', courseId)
        .order('start_time');

    return (data as List).map((e) => SessionModel.fromJson(e)).toList();
  }

  // 更新單一場次
  Future<void> updateSession({
    required String sessionId,
    List<String>? coachIds,
    String? location,
    int? maxCapacity,
    DateTime? startTime,
    DateTime? endTime,
  }) async {
    final Map<String, dynamic> updates = {};
    if (coachIds != null) updates['coach_ids'] = coachIds;
    if (location != null) updates['location'] = location;
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

    // 2. 判斷是否需要退款
    // 邏輯：如果課程還沒結束 (endTime 在現在之後)，則視為「取消」，需要退款
    final bool shouldRefund = endTime.isAfter(DateTime.now());

    if (shouldRefund) {
      // 3. 找出所有「已確認 (confirmed)」的預約，並關聯學生資料
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
    } else {
      print('課程已結束，僅刪除資料不執行退款。');
    }

    // 5. 最後執行物理刪除
    // DB 設定了 ON DELETE CASCADE，所以 bookings 會自動消失
    await _supabase.from('sessions').delete().eq('id', sessionId);
  }
}
