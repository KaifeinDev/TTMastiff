import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:meta/meta.dart';

class AuthRepository {
  final SupabaseClient _supabase;
  final String? Function(String displayName)? _avatarUrlGenerator;

  /// avatarUrlGenerator: 可注入產生頭像 URL 的方法，避免硬編碼外部服務與便於測試/設定
  /// 若為 null，將不寫入 avatar_url 欄位
  AuthRepository(this._supabase, {String? Function(String displayName)? avatarUrlGenerator})
      : _avatarUrlGenerator = avatarUrlGenerator ?? _defaultAvatarUrlFromEnv;

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
      await insertProfile({
        'id': user.id,
        'full_name': fullName,
        'phone': phone,
        'referral_source': referralSource,
        'credits': 0,
        'role': 'user',
        'membership': 'beginner', // 預設會員等級
      });

      // 3. 建立 Primary Student (由程式碼完全控制，包含所有細節)
      // 生成顯示名稱（預設取最後兩字）
      String avatarName = fullName.trim();
      if (fullName.length > 2) {
        avatarName = fullName.substring(fullName.length - 2);
      }
      final avatarUrl = _avatarUrlGenerator?.call(avatarName);

      final studentRow = <String, dynamic>{
        'parent_id': user.id,
        'name': fullName,
        // 優化：只取 YYYY-MM-DD，避免時區導致日期跑掉
        'birth_date': birthDate.toIso8601String().substring(0, 10),
        'gender': gender,
        'medical_note': medicalNote,
        'is_primary': true,
      };
      if (avatarUrl != null && avatarUrl.isNotEmpty) {
        studentRow['avatar_url'] = avatarUrl;
      }
      await insertStudent(studentRow);
    } catch (e) {
      throw Exception('註冊流程失敗: $e');
    }
  }

  // 可覆寫：提供測試用攔截點，避免直接依賴 Postgrest builder 型別鏈
  @protected
  Future<void> insertProfile(Map<String, dynamic> row) async {
    await _supabase.from('profiles').insert(row);
  }

  @protected
  Future<void> insertStudent(Map<String, dynamic> row) async {
    await _supabase.from('students').insert(row);
  }

  /// 預設的頭像 URL 產生器：從編譯期環境變數讀取 AVATAR_BASE_URL（dart-define）
  /// - 若未設定或不合法，回傳 null（不寫入 avatar_url）
  /// - 僅允許 http/https，並對 name 進行 URL encode
  static String? _defaultAvatarUrlFromEnv(String displayName) {
    const base = String.fromEnvironment('AVATAR_BASE_URL', defaultValue: '');
    if (base.isEmpty) return null;
    final uri = Uri.tryParse(base);
    if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) {
      return null;
    }
    final encoded = Uri.encodeComponent(displayName);
    // 規範化：若 base 不以 / 結尾則補上
    final normalized = base.endsWith('/') ? base : '$base/';
    return '$normalized?name=$encoded';
  }

  // 登出
  Future<void> signOut() async {
    await _supabase.auth.signOut();
  }

  // 忘記密碼：寄送 6 碼 OTP 到 Email
  Future<void> sendPasswordResetOtp(String email) async {
    try {
      // 使用 recovery 流程寄送重設密碼驗證碼（由 Reset Password template 控制內容）
      await _supabase.auth.resetPasswordForEmail(email);
    } catch (e) {
      throw Exception('寄送驗證碼失敗: $e');
    }
  }

  // 驗證 Email OTP（成功後會建立 session，才能更新密碼）
  Future<void> verifyPasswordResetOtp({
    required String email,
    required String otp,
  }) async {
    try {
      await _supabase.auth.verifyOTP(
        email: email,
        token: otp,
        type: OtpType.recovery,
      );
    } catch (e) {
      throw Exception('驗證碼錯誤或已失效: $e');
    }
  }

  // 使用者透過 reset link 進來後，更新新密碼
  Future<void> updatePassword(String newPassword) async {
    try {
      await _supabase.auth.updateUser(UserAttributes(password: newPassword));
    } catch (e) {
      throw Exception('更新密碼失敗: $e');
    }
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
