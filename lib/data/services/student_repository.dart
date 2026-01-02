import 'package:supabase_flutter/supabase_flutter.dart';

class StudentModel {
  final String id;
  final String parentId;
  final String name;
  final String? avatarUrl;
  final bool isPrimary; // 🌟 新增：用來判斷是否為「本人」
  final String level;   // 🌟 新增：程度 (對應 DB V3)
  final DateTime birthDate; // 🌟 新增：生日
  final String? medical_note; // 🌟 新增：醫療備註

  StudentModel({
    required this.id, 
    required this.parentId, 
    required this.name, 
    this.avatarUrl,
    required this.isPrimary,
    this.level = 'beginner',
    this.medical_note,
    required this.birthDate,
  });

  factory StudentModel.fromJson(Map<String, dynamic> json) {
    return StudentModel(
      id: json['id'],
      parentId: json['parent_id'],
      name: json['name'],
      avatarUrl: json['avatar_url'],
      // 資料庫欄位是 is_primary，若為 null 預設 false
      isPrimary: json['is_primary'] ?? false, 
      level: json['level'] ?? 'beginner',
      birthDate: DateTime.parse(json['birth_date'] as String), 
      medical_note: json['medical_note'],
    );
  }
}

class StudentRepository {
  final SupabaseClient _supabase;

  StudentRepository(this._supabase);

  // 取得當前帳號底下的所有學員
  Future<List<StudentModel>> getMyStudents() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return [];

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
    final avatarUrl = 'https://ui-avatars.com/api/?name=$encodedName&background=random&size=128&format=png';

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
    final newAvatarUrl = 'https://ui-avatars.com/api/?name=$encodedName&background=random&size=128&format=png';

    await _supabase.from('students').update({
      'name': newName,
      'avatar_url': newAvatarUrl,
      'medical_note': note,
    }).eq('id', id);
  }
}
