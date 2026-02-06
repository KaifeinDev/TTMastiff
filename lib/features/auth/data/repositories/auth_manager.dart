import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_repository.dart'; 
import 'package:ttmastiff/core/utils/util.dart';

class AuthManager extends ChangeNotifier {
  final AuthRepository _authRepository;

  // 內部狀態
  String? _userRole;
  bool _isLoading = true; // 增加載入狀態，避免路由太快跳轉

  AuthManager(this._authRepository);

  // 給外部讀取的屬性
  User? get currentUser => _authRepository.currentUser;
  bool get isAdmin => _userRole == 'admin';
  bool get isCoach => _userRole == 'coach';
  bool get isLoading => _isLoading;
  bool _manualLoginInProgress = false;

  // 初始化：啟動監聽
  Future<void> init() async {
    // 監聽 Supabase Auth 變化
    _authRepository.authStateChanges.listen((AuthState data) async {
      final AuthChangeEvent event = data.event;
      final Session? session = data.session;

      if (event == AuthChangeEvent.signedIn ||
          event == AuthChangeEvent.initialSession ||
          event == AuthChangeEvent.tokenRefreshed) {
        if (session != null) {
          // 已登入 -> 去查 Role
          await _updateUserRole(session.user.id);
        }
      } else if (event == AuthChangeEvent.signedOut) {
        // 已登出 -> 清空 Role
        _userRole = null;
      }

      if (!_manualLoginInProgress) {
        _isLoading = false;
        notifyListeners();
      }
    });
    final session = Supabase.instance.client.auth.currentSession;

    // 如果啟動時已經有 User (沒觸發監聽)，手動查一次
    if (session != null) {
      if (session.isExpired) {
        // ⚠️ 關鍵：Token 過期了！
        // 我們 "不要" 在這裡設 isLoading = false。
        // 保持 isLoading = true，讓上面的 listen 去等待 'tokenRefreshed' 或 'signedOut' 事件。
        logger.i("⏳ Token 已過期，正在等待背景刷新...");
        return;
      }

      await _updateUserRole(currentUser!.id);
      _isLoading = false;
      notifyListeners();
    } else {
      _isLoading = false;
      notifyListeners();
    }
  }

  // 登入
  Future<void> signIn({required String email, required String password}) async {
    try {
      _manualLoginInProgress = true; // 鎖住 loading 控制權
      _isLoading = true;
      notifyListeners();

      await _authRepository.signIn(email: email, password: password);
      final user = _authRepository.currentUser;
      if (user != null) {
        logger.i("✅ 登入成功，正在抓取身分資料 ID: ${user.id}...");
        await _updateUserRole(user.id);
        logger.i("✅ 身分資料抓取完畢，角色為: $_userRole");
      }
    } catch (e) {
      throw Exception('登入失敗: $e');
    } finally {
      _manualLoginInProgress = false;
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _updateUserRole(String userId) async {
    try {
      // 這裡建議加一個 log 確認 Repo 回傳什麼
      final role = await _authRepository.fetchUserRole(userId);
      _userRole = role;
    } catch (e) {
      _userRole = 'user'; // 失敗時預設為 user，避免卡死
    }
  }

  // 登出封裝
  Future<void> signOut() async {
    _userRole = null; // 先清空
    await _authRepository.signOut();
    notifyListeners();
  }
}
