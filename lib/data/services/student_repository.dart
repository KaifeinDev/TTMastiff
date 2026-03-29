import 'package:flutter/foundation.dart';
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
    final encodedName = Uri.encodeComponent(avatarName);
    final avatarUrl =
        'https://ui-avatars.com/api/?name=$encodedName&background=random&size=128&format=png';

    await _supabase.from('students').insert({
      'parent_id': userId,
      'name': name,
      'birth_date': birthDate.toIso8601String(),
      'medical_note': medicalNote,
      'avatar_url': avatarUrl,
      'is_primary': false,
    });
  }

  // 更新學員
  Future<void> updateStudent(String id, String newName, String? note) async {
    String avatarName = newName.trim();
    if (newName.length > 2) {
      avatarName = newName.substring(newName.length - 2);
    }
    final encodedName = Uri.encodeComponent(avatarName);
    final newAvatarUrl =
        'https://ui-avatars.com/api/?name=$encodedName&background=random&size=128&format=png';

    await _supabase.from('students').update({
      'name': newName,
      'avatar_url': newAvatarUrl,
      'medical_note': note,
    }).eq('id', id);
  }

  // 更新學員點數
  Future<void> updateStudentPoints(String id, int points) async {
    await _supabase.from('students').update({'points': points}).eq('id', id);
  }

  /// 根據課程和場次篩選學員（管理員用）
  Future<List<Map<String, dynamic>>> fetchStudentsByFilter({
    String? courseId,
    String? sessionId,
    String? name,
    String? phone,
    bool includeBookings = false,
  }) async {
    try {
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
          return [];
        }
      }

      List<Map<String, dynamic>> studentsData = [];

      if (sessionId != null) {
        final bookingsData = await _supabase
            .from('bookings')
            .select('students(*)')
            .eq('session_id', sessionId)
            .eq('status', 'confirmed');

        for (var booking in bookingsData as List) {
          if (booking['students'] != null) {
            studentsData.add(booking['students'] as Map<String, dynamic>);
          }
        }
      } else if (courseId != null) {
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

        final bookingsData = await _supabase
            .from('bookings')
            .select('students(*)')
            .filter('session_id', 'in', sessionIds)
            .eq('status', 'confirmed');

        for (var booking in bookingsData as List) {
          if (booking['students'] != null) {
            studentsData.add(booking['students'] as Map<String, dynamic>);
          }
        }
      } else {
        final response = await _supabase
            .from('students')
            .select('*')
            .order('created_at', ascending: true);
        studentsData = List<Map<String, dynamic>>.from(response as List);
      }

      final Map<String, StudentModel> uniqueStudents = {};
      final nameFilter = name?.trim().toLowerCase();

      for (var studentData in studentsData) {
        if (nameFilter != null && nameFilter.isNotEmpty) {
          final studentName = (studentData['name'] as String? ?? '')
              .toLowerCase();
          if (!studentName.contains(nameFilter)) continue;
        }

        if (parentIdsForPhone != null) {
          final parentId = studentData['parent_id'] as String?;
          if (parentId == null || !parentIdsForPhone.contains(parentId)) {
            continue;
          }
        }

        final student = StudentModel.fromJson(studentData);
        uniqueStudents[student.id] = student;
      }

      final studentsList = uniqueStudents.values.toList();

      Map<String, String?> parentPhones = {};
      Map<String, String?> parentNames = {};

      if (studentsList.isNotEmpty) {
        final parentIds = studentsList.map((s) => s.parentId).toSet().toList();
        try {
          final profilesResponse = await _supabase
              .from('profiles')
              .select('id, phone, full_name')
              .inFilter('id', parentIds);

          final Map<String, Map<String, String?>> parentInfoMap = {};
          for (var profile in profilesResponse as List) {
            final parentId = profile['id'] as String;
            parentInfoMap[parentId] = {
              'phone': profile['phone'] as String?,
              'name': profile['full_name'] as String?,
            };
          }

          for (var student in studentsList) {
            final parentInfo = parentInfoMap[student.parentId];
            parentPhones[student.id] = parentInfo?['phone'];
            parentNames[student.id] = parentInfo?['name'];
          }
        } catch (e) {
          // 如果查詢失敗，只記錄錯誤，不影響返回學員列表
          debugPrint('⚠️ 查詢家長資訊失敗: $e');
        }
      }

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

          for (var booking in bookingsResponse as List) {
            final bookingStudentId = booking['student_id'] as String;
            if (!studentsBookings.containsKey(bookingStudentId)) {
              studentsBookings[bookingStudentId] = [];
            }
            studentsBookings[bookingStudentId]!.add(
              Map<String, dynamic>.from(booking as Map),
            );
          }
        } catch (e) {
          // ignore
        }
      }

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
        .single();

    return {
      'student': StudentModel.fromJson(response),
      'parentName': response['profiles']?['full_name'] ?? '無資料',
      'parentPhone': response['profiles']?['phone'] ?? '無資料',
    };
  }
}
