import 'package:supabase_flutter/supabase_flutter.dart';

class AuthRepository {
  final SupabaseClient _supabase;

  AuthRepository(this._supabase);

  // 取得目前的使用者 (如果是 null 代表未登入)
  User? get currentUser => _supabase.auth.currentUser;

  // 登入
  Future<void> signIn({required String email, required String password}) async {
    try {
      await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      // 這裡可以針對 Supabase 的錯誤代碼做更細緻的處理
      // 但 MVP 先直接把錯誤拋出去
      throw Exception('登入失敗: ${e.toString()}');
    }
  }

  // 註冊 
  Future<void> signUp({
    required String email, 
    required String password,
    required String fullName, 
    required String phone, 
  }) async {
    try {
      final defaultAvatarUrl = 'https://ui-avatars.com/api/?name=$fullName&background=random&size=128';
      await _supabase.auth.signUp(
        email: email,
        password: password,
        data: {
          'full_name': fullName,
          'phone': phone,
          'avatar_url': defaultAvatarUrl,
        }, 
      );
    } catch (e) {
      throw Exception('註冊失敗: ${e.toString()}');
    }
  }

  // 登出
  Future<void> signOut() async {
    await _supabase.auth.signOut();
  }

}
