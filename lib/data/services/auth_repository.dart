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
    String? medicalNote,
    String referralSource = 'app_signup', // 預設來源
  }) async {
    try {
      // 1. 建立 Supabase Auth 帳號 (Email/Password)
      final AuthResponse res = await _supabase.auth.signUp(
        email: email,
        password: password,
        // 雖然我們有 profiles 表，但將基本資料也存在 metadata 是個好習慣 (方便 Supabase 後台查看)
        data: {'full_name': fullName, 'phone': phone},
      );

      final User? user = res.user;
      if (user == null) {
        throw Exception('註冊失敗，無法取得使用者 ID');
      }

      // 2. 寫入 public.profiles 表
      // 關鍵：這一步會觸發 DB 的 Trigger，自動建立 "students" 表的本人資料
      await _supabase.from('profiles').insert({
        'id': user.id, // 強制連結 Auth ID
        'full_name': fullName,
        'phone': phone,
        'referral_source': referralSource,
        'credits': 0, // 初始點數
        'role': 'user', // 初始身份
      });

      // 3. 建立 Primary Student (實體層：包含頭像、生日、備註)
      // 生成頭像 URL
      String avatarName = fullName.trim();
      if (fullName.length > 2)
        avatarName = fullName.substring(fullName.length - 2);
      final encodedName = Uri.encodeComponent(avatarName);
      final avatarUrl =
          'https://ui-avatars.com/api/?name=$encodedName&background=random&size=128&format=png';

      await _supabase.from('students').insert({
        'parent_id': user.id,
        'name': fullName,
        'birth_date': birthDate.toIso8601String(), // 轉成字串存入 DB
        'medical_note': medicalNote,
        'avatar_url': avatarUrl,
        'is_primary': true, // ⚠️ 標記為本人
        'level': 'beginner',
      });
    } catch (e) {
      // 若是 Profile 寫入失敗，實務上可能需要考慮是否 rollback 刪除 auth user
      // 但 MVP 階段先拋出錯誤讓 UI 顯示即可
      throw Exception('註冊流程失敗: $e');
    }
  }

  // 登出
  Future<void> signOut() async {
    await _supabase.auth.signOut();
  }
}
