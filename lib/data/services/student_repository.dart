import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:meta/meta.dart';
import '../models/student_model.dart';

class StudentRepository {
  final SupabaseClient _supabase;

  StudentRepository(this._supabase);

  // 取得當前帳號底下的所有學員
  Future<List<StudentModel>> getMyStudents() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('尚未登入');

    final response = await queryStudentsByParentId(userId);

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

    await insertStudentRow({
      'parent_id': userId,
      'name': name,
      'birth_date': birthDate.toIso8601String(),
      'medical_note': medicalNote,
      'avatar_url': avatarUrl,
      'is_primary': false, // 明確指定為子帳號
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

    await updateStudentRow(id, {
      'name': newName,
      'avatar_url': newAvatarUrl,
      'medical_note': note,
    });
  }

  // 更新學員點數
  Future<void> updateStudentPoints(String id, int points) async {
    await updatePointsRow(id, points);
  }

  /// 根據課程和場次篩選學員（管理員用）
  /// 如果 courseId 為 null，返回所有學員
  /// 如果 sessionId 為 null，返回該課程的所有學員
  /// 如果都提供，返回該場次的所有學員
  /// name 和 phone 用於模糊搜尋
  /// 返回的每個項目包含：student, parentPhone, parentName, bookings（如果 includeBookings = true）
  Future<List<Map<String, dynamic>>> fetchStudentsByFilter({
    String? courseId,
    String? sessionId,
    String? name,
    String? phone,
    bool includeBookings = false, // 是否包含報名課程資訊
  }) async {
    try {
      // 1. 統一處理電話篩選：先查詢符合電話的家長 ID
      List<String>? parentIdsForPhone;
      if (phone != null && phone.trim().isNotEmpty) {
        final profilesResponse =
            await queryProfilesByPhoneLike(phone.trim());

        parentIdsForPhone = (profilesResponse as List)
            .map((p) => p['id'] as String)
            .toList();

        if (parentIdsForPhone.isEmpty) {
          return []; // 沒有找到符合電話的家長，返回空列表
        }
      }

      // 2. 根據條件決定查詢路徑，獲取學員數據
      List<Map<String, dynamic>> studentsData = [];

      if (sessionId != null) {
        // 指定場次：查詢該場次的報名
        final bookingsData = await queryBookingsBySession(sessionId);

        // 提取學員數據
        for (var booking in bookingsData) {
          if (booking['students'] != null) {
            studentsData.add(booking['students'] as Map<String, dynamic>);
          }
        }
      } else if (courseId != null) {
        // 指定課程：先獲取該課程的所有場次 ID
        final sessionsResponse = await querySessionsByCourse(courseId);

        final sessionIds = (sessionsResponse as List)
            .map((s) => s['id'] as String)
            .toList();

        if (sessionIds.isEmpty) {
          return [];
        }

        // 查詢這些場次的所有報名
        final bookingsData = await queryBookingsBySessionIds(sessionIds);

        // 提取學員數據
        for (var booking in bookingsData) {
          if (booking['students'] != null) {
            studentsData.add(booking['students'] as Map<String, dynamic>);
          }
        }
      } else {
        // 沒有指定課程或場次：直接從 students 表查詢
        final response = await queryAllStudents();

        studentsData = response;
      }

      // 3. 統一應用名字和電話篩選（統一處理邏輯）
      final Map<String, StudentModel> uniqueStudents = {};
      final nameFilter = name?.trim().toLowerCase();

      for (var studentData in studentsData) {
        // 應用名字篩選
        if (nameFilter != null && nameFilter.isNotEmpty) {
          final studentName = (studentData['name'] as String? ?? '')
              .toLowerCase();
          if (!studentName.contains(nameFilter)) continue;
        }

        // 應用電話篩選（通過 parent_id）
        if (parentIdsForPhone != null) {
          final parentId = studentData['parent_id'] as String?;
          if (parentId == null || !parentIdsForPhone.contains(parentId)) {
            continue;
          }
        }

        // 解析並去重
        final student = StudentModel.fromJson(studentData);
        uniqueStudents[student.id] = student;
      }

      final studentsList = uniqueStudents.values.toList();

      // 4. 批量查詢家長電話和姓名
      Map<String, String?> parentPhones = {};
      Map<String, String?> parentNames = {};

      if (studentsList.isNotEmpty) {
        final parentIds = studentsList.map((s) => s.parentId).toSet().toList();
        try {
          final profilesResponse =
              await queryParentProfilesByIds(parentIds);

          // 建立 parentId -> phone/name 的映射
          final Map<String, Map<String, String?>> parentInfoMap = {};
          for (var profile in profilesResponse) {
            final parentId = profile['id'] as String;
            parentInfoMap[parentId] = {
              'phone': profile['phone'] as String?,
              'name': profile['full_name'] as String?,
            };
          }

          // 建立學員 ID -> 電話/姓名的映射
          for (var student in studentsList) {
            final parentInfo = parentInfoMap[student.parentId];
            parentPhones[student.id] = parentInfo?['phone'];
            parentNames[student.id] = parentInfo?['name'];
          }
        } catch (e) {
          // 如果查詢失敗，只記錄錯誤，不影響返回學員列表
          print('⚠️ 查詢家長資訊失敗: $e');
        }
      }

      // 5. 如果需要，批量查詢報名課程
      Map<String, List<Map<String, dynamic>>> studentsBookings = {};
      if (includeBookings && studentsList.isNotEmpty) {
        final studentIds = studentsList.map((s) => s.id).toList();
        try {
          final bookingsResponse =
              await queryBookingsDetailsByStudentIds(studentIds);

          for (var booking in bookingsResponse) {
            final bookingStudentId = booking['student_id'] as String;
            if (!studentsBookings.containsKey(bookingStudentId)) {
              studentsBookings[bookingStudentId] = [];
            }
            studentsBookings[bookingStudentId]!.add(booking);
          }
        } catch (e) {
          // ignore
        }
      }

      // 6. 組裝返回結果
      return studentsList.map((student) {
        return {
          'student': student,
          'parentPhone': parentPhones[student.id],
          'parentName': parentNames[student.id],
          'bookings': includeBookings ? studentsBookings[student.id] : null,
        };
      }).toList();
    } catch (e) {
      throw Exception('載入學員列表失敗: $e');
    }
  }

  Future<Map<String, dynamic>> fetchStudentAndParentProfile(
    String studentId,
  ) async {
    final response = await queryStudentWithProfile(studentId);

    // 整理回傳格式
    // 這裡回傳一個 Map 包含 StudentModel 和 家長資訊
    return {
      'student': StudentModel.fromJson(response),
      'parentName': response['profiles']?['full_name'] ?? '無資料',
      'parentPhone': response['profiles']?['phone'] ?? '無資料',
    };
  }
}

// ===== Hooks for testability =====
@protected
Future<List<Map<String, dynamic>>> queryStudentsByParentId(
    String userId, {
  SupabaseClient? client,
}) async {
  final c = client ?? Supabase.instance.client;
  final response = await c
      .from('students')
      .select()
      .eq('parent_id', userId)
      .order('is_primary', ascending: false)
      .order('created_at', ascending: true);
  return List<Map<String, dynamic>>.from(response);
}

@protected
Future<void> insertStudentRow(Map<String, dynamic> row,
    {SupabaseClient? client}) {
  final c = client ?? Supabase.instance.client;
  return c.from('students').insert(row);
}

@protected
Future<void> updateStudentRow(String id, Map<String, dynamic> row,
    {SupabaseClient? client}) {
  final c = client ?? Supabase.instance.client;
  return c.from('students').update(row).eq('id', id);
}

@protected
Future<void> updatePointsRow(String id, int points,
    {SupabaseClient? client}) {
  final c = client ?? Supabase.instance.client;
  return c.from('students').update({'points': points}).eq('id', id);
}

@protected
Future<List<Map<String, dynamic>>> queryBookingsBySession(String sessionId,
    {SupabaseClient? client}) async {
  final c = client ?? Supabase.instance.client;
  final response = await c
      .from('bookings')
      .select('students(*)')
      .eq('session_id', sessionId)
      .eq('status', 'confirmed');
  return List<Map<String, dynamic>>.from(response);
}

@protected
Future<List<Map<String, dynamic>>> querySessionsByCourse(String courseId,
    {SupabaseClient? client}) async {
  final c = client ?? Supabase.instance.client;
  final response = await c.from('sessions').select('id').eq('course_id', courseId);
  return List<Map<String, dynamic>>.from(response);
}

@protected
Future<List<Map<String, dynamic>>> queryBookingsBySessionIds(
    List<String> sessionIds,
    {SupabaseClient? client}) async {
  final c = client ?? Supabase.instance.client;
  final response = await c
      .from('bookings')
      .select('students(*)')
      .filter('session_id', 'in', sessionIds)
      .eq('status', 'confirmed');
  return List<Map<String, dynamic>>.from(response);
}

@protected
Future<List<Map<String, dynamic>>> queryAllStudents(
    {SupabaseClient? client}) async {
  final c = client ?? Supabase.instance.client;
  final response =
      await c.from('students').select('*').order('created_at', ascending: true);
  return List<Map<String, dynamic>>.from(response);
}

@protected
Future<List<Map<String, dynamic>>> queryProfilesByPhoneLike(String phoneLike,
    {SupabaseClient? client}) async {
  final c = client ?? Supabase.instance.client;
  final response =
      await c.from('profiles').select('id').ilike('phone', '%$phoneLike%');
  return List<Map<String, dynamic>>.from(response);
}

@protected
Future<List<Map<String, dynamic>>> queryParentProfilesByIds(
    List<String> parentIds,
    {SupabaseClient? client}) async {
  final c = client ?? Supabase.instance.client;
  final response =
      await c.from('profiles').select('id, phone, full_name').inFilter('id', parentIds);
  return List<Map<String, dynamic>>.from(response);
}

@protected
Future<List<Map<String, dynamic>>> queryBookingsDetailsByStudentIds(
    List<String> studentIds,
    {SupabaseClient? client}) async {
  final c = client ?? Supabase.instance.client;
  final response = await c
      .from('bookings')
      .select('''
                *,
                sessions (
                  *,
                  courses (*)
                )
              ''')
      .inFilter('student_id', studentIds)
      .eq('status', 'confirmed')
      .order('created_at', ascending: false);
  return List<Map<String, dynamic>>.from(response);
}

@protected
Future<Map<String, dynamic>> queryStudentWithProfile(String studentId,
    {SupabaseClient? client}) async {
  final c = client ?? Supabase.instance.client;
  final response = await c
      .from('students')
      .select('''
        *,
        profiles (
          full_name,
          phone,
        )
      ''')
      .eq('id', studentId)
      .single();
  return Map<String, dynamic>.from(response);
}
