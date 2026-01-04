import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/session_model.dart';

class SessionRepository {
  final SupabaseClient _supabase;
  SessionRepository(this._supabase);

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
    await _supabase.from('sessions').delete().eq('id', sessionId);
  }
}
