import 'package:supabase_flutter/supabase_flutter.dart';

class StudentModel {
  final String id;
  final String parentId;
  final String name;
  final String? avatarUrl;

  StudentModel({required this.id, required this.parentId, required this.name, this.avatarUrl});

  factory StudentModel.fromJson(Map<String, dynamic> json) {
    return StudentModel(
      id: json['id'],
      parentId: json['parent_id'],
      name: json['name'],
      avatarUrl: json['avatar_url'],
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
        .eq('parent_id', userId);

    return (response as List).map((e) => StudentModel.fromJson(e)).toList();
  }

  // 新增學員 (未來 Profile 頁面會用到)
  Future<void> addStudent(String name) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('尚未登入');

    String avatarName = name;
    if (name.length > 2) {
      avatarName = name.substring(name.length - 2);
    }
    // 生成大頭貼
    final avatarUrl = 'https://ui-avatars.com/api/?name=$avatarName&background=random&size=128';

    await _supabase.from('students').insert({
      'parent_id': userId,
      'name': name,
      'avatar_url': avatarUrl,
    });
  }
  Future<void> updateStudent(String id, String newName) async {
    String avatarName = newName;
    if (newName.length > 2) {
      avatarName = newName.substring(newName.length - 2);
    }
    // 生成大頭貼
    final newAvatarUrl = 'https://ui-avatars.com/api/?name=$avatarName&background=random&size=128';

    await _supabase.from('students').update({
      'name': newName,
      'avatar_url': newAvatarUrl, // 順便更新大頭貼
    }).eq('id', id);
  }
}
