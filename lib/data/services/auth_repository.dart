import 'package:supabase_flutter/supabase_flutter.dart';

class AuthRepository {
  final SupabaseClient _supabase;

  AuthRepository(this._supabase);

  // 取得目前的使用者
  User? get currentUser => _supabase.auth.currentUser;

  // 監聽登入狀態變化 (選用，但建議加上，UI 可以即時反應)
  Stream<AuthState> get authStateChanges => _supabase.auth.onAuthStateChange;

  // 登入
  Future<void> signIn({required String email, required String password}) async {
    try {
      await _supabase.auth.signInWithPassword(email: email, password: password);
    } catch (e) {
      throw Exception('登入失敗: $e');
    }
  }

  // 註冊 (配合 DB V2)
  Future<void> signUp({
    required String email,
    required String password,
    required String fullName,
    required String phone,
    required DateTime birthDate,
    String? gender,
    String? medicalNote,
    String referralSource = 'app_signup',
  }) async {
    try {
      // 1. 建立 Supabase Auth 帳號
      final AuthResponse res = await _supabase.auth.signUp(
        email: email,
        password: password,
        data: {'full_name': fullName, 'phone': phone},
      );

      final User? user = res.user;
      if (user == null) {
        throw Exception('註冊失敗，無法取得使用者 ID');
      }

      // 2. 寫入 public.profiles 表
      // 因為我們剛剛刪除了 Trigger，這裡寫入後，"不會" 自動產生 student
      await _supabase.from('profiles').insert({
        'id': user.id,
        'full_name': fullName,
        'phone': phone,
        'referral_source': referralSource,
        'credits': 0,
        'role': 'user',
        'membership': 'beginner', // 預設會員等級
      });

      // 3. 建立 Primary Student (由程式碼完全控制，包含所有細節)
      // 生成頭像 URL
      String avatarName = fullName.trim();
      if (fullName.length > 2) {
        avatarName = fullName.substring(fullName.length - 2);
      }
      final encodedName = Uri.encodeComponent(avatarName);
      final avatarUrl =
          'https://ui-avatars.com/api/?name=$encodedName&background=random&size=128&format=png';

      await _supabase.from('students').insert({
        'parent_id': user.id,
        'name': fullName,
        // 優化：只取 YYYY-MM-DD，避免時區導致日期跑掉
        'birth_date': birthDate.toIso8601String().substring(0, 10),
        'gender': gender,
        'medical_note': medicalNote,
        'avatar_url': avatarUrl,
        'is_primary': true,
      });
    } catch (e) {
      // 這裡可以印出詳細錯誤，方便除錯
      print('註冊流程詳細錯誤: $e');
      throw Exception('註冊流程失敗: $e');
    }
  }

  // 登出
  Future<void> signOut() async {
    await _supabase.auth.signOut();
  }

  // 取得使用者的角色權限
  Future<String> fetchUserRole(String userId) async {
    try {
      final data = await _supabase
          .from('profiles')
          .select('role')
          .eq('id', userId)
          .single();

      return data['role'] as String? ?? 'user'; // 若沒設定則預設為 user
    } catch (e) {
      // 若發生錯誤 (例如 profile 還沒建立)，預設回傳 user 以策安全
      return 'user';
    }
  }
}
