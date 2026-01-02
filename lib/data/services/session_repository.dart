import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/session_model.dart';


class SessionRepository {
  final SupabaseClient _client;
  SessionRepository(this._client);

  // 📅 抓取特定日期的所有課程
  Future<List<SessionModel>> fetchSessionsByDate(DateTime date) async {
    // 設定當天的 00:00:00 到 23:59:59
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1)).subtract(const Duration(seconds: 1));

    final response = await _client
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

  // 📝 執行預約
  Future<void> createBooking({required String sessionId, required String studentId}) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('未登入');

    await _client.from('bookings').insert({
      'user_id': user.id,
      'student_id': studentId,
      'session_id': sessionId,
      'status': 'confirmed',
    });
  }
}
