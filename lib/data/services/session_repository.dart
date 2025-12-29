import 'package:supabase_flutter/supabase_flutter.dart';

class SessionModel {
  final String id;
  final DateTime startTime;
  final DateTime endTime;
  final List<String> coaches;
  final int maxCapacity;
  
  // 來自 Course 的資訊
  final String courseTitle;
  final String category; // 'group' or 'personal'
  final int price;
  final String? imageUrl;

  SessionModel({
    required this.id,
    required this.startTime,
    required this.endTime,
    required this.coaches,
    required this.maxCapacity,
    required this.courseTitle,
    required this.category,
    required this.price,
    this.imageUrl,
  });

  factory SessionModel.fromJson(Map<String, dynamic> json) {
    final course = json['course'] ?? {};
    
    return SessionModel(
      id: json['id'],
      startTime: DateTime.parse(json['start_time']).toLocal(),
      endTime: DateTime.parse(json['end_time']).toLocal(),
      coaches: List<String>.from(json['coaches'] ?? []),
      maxCapacity: json['max_capacity'] ?? 10,
      
      courseTitle: course['title'] ?? '未命名課程',
      category: course['category'] ?? 'group',
      price: course['price'] ?? 0,
      imageUrl: course['image_url'],
    );
  }

  // 方便 UI 顯示
  String get categoryText => category == 'personal' ? '1對1' : '團體班';
  String get coachesText => coaches.isEmpty ? '教練待定' : coaches.join('、');
}

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
