import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/student_model.dart';

class StudentRepository {
  final SupabaseClient _supabase;

  StudentRepository(this._supabase);

  // 取得當前帳號底下的所有學員
  Future<List<StudentModel>> getMyStudents() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('尚未登入');

    final response = await _supabase
        .from('students')
        .select()
        .eq('parent_id', userId)
        // 🌟 排序重點：讓 is_primary = true (本人) 排在最前面，其他依建立時間排
        .order('is_primary', ascending: false)
        .order('created_at', ascending: true);

    return (response as List).map((e) => StudentModel.fromJson(e)).toList();
  }

  // 新增學員 (子帳號，預設 is_primary = false)
  Future<void> addStudent({
    required String name,
    required DateTime birthDate,
    String? medicalNote,
  }) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('尚未登入');

    String avatarName = name.trim();
    if (name.length > 2) {
      avatarName = name.substring(name.length - 2);
    }
    // 生成大頭貼
    final encodedName = Uri.encodeComponent(avatarName);
    final avatarUrl =
        'https://ui-avatars.com/api/?name=$encodedName&background=random&size=128&format=png';

    await _supabase.from('students').insert({
      'parent_id': userId,
      'name': name,
      'birth_date': birthDate.toIso8601String(),
      'medical_note': medicalNote,
      'avatar_url': avatarUrl,
      'is_primary': false, // 明確指定為子帳號
      'level': 'beginner', // 預設程度
    });
  }

  // 更新學員
  Future<void> updateStudent(String id, String newName, String? note) async {
    String avatarName = newName.trim();
    if (newName.length > 2) {
      avatarName = newName.substring(newName.length - 2);
    }
    // 重新生成大頭貼以符合新名字
    final encodedName = Uri.encodeComponent(avatarName);
    final newAvatarUrl =
        'https://ui-avatars.com/api/?name=$encodedName&background=random&size=128&format=png';

    await _supabase
        .from('students')
        .update({
          'name': newName,
          'avatar_url': newAvatarUrl,
          'medical_note': note,
        })
        .eq('id', id);
  }

  /// 根據課程和場次篩選學員（管理員用）
  /// 如果 courseId 為 null，返回所有學員
  /// 如果 sessionId 為 null，返回該課程的所有學員
  /// 如果都提供，返回該場次的所有學員
  Future<List<StudentModel>> fetchStudentsByFilter({
    String? courseId,
    String? sessionId,
  }) async {
    try {
      if (sessionId != null) {
        // 如果指定了場次，從 bookings 表查詢該場次的學員
        final response = await _supabase
            .from('bookings')
            .select('students(*)')
            .eq('session_id', sessionId)
            .eq('status', 'confirmed'); // 只查已確認的報名

        // 提取學員資料並去重
        final Map<String, StudentModel> uniqueStudents = {};
        for (var booking in response) {
          if (booking['students'] != null) {
            final student = StudentModel.fromJson(booking['students']);
            uniqueStudents[student.id] = student;
          }
        }
        return uniqueStudents.values.toList();
      } else if (courseId != null) {
        // 如果只指定了課程，查詢該課程所有場次的學員
        // 先獲取該課程的所有場次
        final sessionsResponse = await _supabase
            .from('sessions')
            .select('id')
            .eq('course_id', courseId);

        final sessionIds = (sessionsResponse as List)
            .map((s) => s['id'] as String)
            .toList();

        if (sessionIds.isEmpty) return [];

        // 查詢這些場次的所有報名
        final response = await _supabase
            .from('bookings')
            .select('students(*)')
            .filter('session_id', 'in', sessionIds)
            .eq('status', 'confirmed');

        // 提取學員資料並去重
        final Map<String, StudentModel> uniqueStudents = {};
        for (var booking in response) {
          if (booking['students'] != null) {
            final student = StudentModel.fromJson(booking['students']);
            uniqueStudents[student.id] = student;
          }
        }
        return uniqueStudents.values.toList();
      } else {
        // 如果都沒指定，返回所有學員
        final response = await _supabase
            .from('students')
            .select()
            .order('created_at', ascending: true);

        return (response as List)
            .map((e) => StudentModel.fromJson(e))
            .toList();
      }
    } catch (e) {
      throw Exception('載入學員列表失敗: $e');
    }
  }

  /// 獲取學員的完整資訊（包含家長資訊和報名課程）
  Future<Map<String, dynamic>> fetchStudentDetail(String studentId) async {
    try {
      // 1. 獲取學員基本資訊
      final studentResponse = await _supabase
          .from('students')
          .select()
          .eq('id', studentId)
          .single();

      final student = StudentModel.fromJson(studentResponse);

      // 2. 獲取家長資訊（從 profiles 表）
      final profileResponse = await _supabase
          .from('profiles')
          .select('phone, full_name')
          .eq('id', student.parentId)
          .maybeSingle();

      // 3. 獲取該學員的所有報名（包含課程資訊）
      final bookingsResponse = await _supabase
          .from('bookings')
          .select('''
            *,
            sessions (
              *,
              courses (*)
            )
          ''')
          .eq('student_id', studentId)
          .eq('status', 'confirmed')
          .order('created_at', ascending: false);

      return {
        'student': student,
        'parentPhone': profileResponse?['phone'],
        'parentName': profileResponse?['full_name'],
        'bookings': bookingsResponse,
      };
    } catch (e) {
      throw Exception('載入學員詳情失敗: $e');
    }
  }
}
