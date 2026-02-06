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

  // 更新學員點數
  Future<void> updateStudentPoints(String id, int points) async {
    await _supabase.from('students').update({'points': points}).eq('id', id);
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
        final profilesResponse = await _supabase
            .from('profiles')
            .select('id')
            .ilike('phone', '%${phone.trim()}%');

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
        final bookingsData = await _supabase
            .from('bookings')
            .select('students(*)')
            .eq('session_id', sessionId)
            .eq('status', 'confirmed')
            .then((response) => List<Map<String, dynamic>>.from(response));

        // 提取學員數據
        for (var booking in bookingsData) {
          if (booking['students'] != null) {
            studentsData.add(booking['students'] as Map<String, dynamic>);
          }
        }
      } else if (courseId != null) {
        // 指定課程：先獲取該課程的所有場次 ID
        final sessionsResponse = await _supabase
            .from('sessions')
            .select('id')
            .eq('course_id', courseId);

        final sessionIds = (sessionsResponse as List)
            .map((s) => s['id'] as String)
            .toList();

        if (sessionIds.isEmpty) {
          return [];
        }

        // 查詢這些場次的所有報名
        final bookingsData = await _supabase
            .from('bookings')
            .select('students(*)')
            .filter('session_id', 'in', sessionIds)
            .eq('status', 'confirmed')
            .then((response) => List<Map<String, dynamic>>.from(response));

        // 提取學員數據
        for (var booking in bookingsData) {
          if (booking['students'] != null) {
            studentsData.add(booking['students'] as Map<String, dynamic>);
          }
        }
      } else {
        // 沒有指定課程或場次：直接從 students 表查詢
        final response = await _supabase
            .from('students')
            .select('*')
            .order('created_at', ascending: true)
            .then((data) => List<Map<String, dynamic>>.from(data));

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
          final profilesResponse = await _supabase
              .from('profiles')
              .select('id, phone, full_name')
              .inFilter('id', parentIds);

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
          final bookingsResponse = await _supabase
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

          for (var booking in bookingsResponse) {
            final bookingStudentId = booking['student_id'] as String;
            if (!studentsBookings.containsKey(bookingStudentId)) {
              studentsBookings[bookingStudentId] = [];
            }
            studentsBookings[bookingStudentId]!.add(booking);
          }
        } catch (e) {
          print('⚠️ 查詢報名課程失敗: $e');
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
    final response = await _supabase
        .from('students')
        .select('''
        *,
        profiles (
          full_name,
          phone,
        )
      ''')
        .eq('id', studentId)
        .single(); // 只抓一筆

    // 整理回傳格式
    // 這裡回傳一個 Map 包含 StudentModel 和 家長資訊
    return {
      'student': StudentModel.fromJson(response),
      'parentName': response['profiles']?['full_name'] ?? '無資料',
      'parentPhone': response['profiles']?['phone'] ?? '無資料',
    };
  }

  // 在 StudentRepository 類別裡新增這個方法
  Future<String?> getMemberLevel(String userId) async {
    try {
      final client = Supabase.instance.client; 
      final data =
          await client 
              .from('profiles')
              .select('membership')
              .eq('id', userId)
              .single();

      return data['membership'] as String?;
    } catch (e) {
      print('查詢會員等級失敗: $e');
      return null;
    }
  }
}
