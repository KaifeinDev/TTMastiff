import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_repository.dart'; // 引入你的 Repo

class AuthManager extends ChangeNotifier {
  final AuthRepository _authRepository;

  // 內部狀態
  String? _userRole;
  bool _isLoading = true; // 增加載入狀態，避免路由太快跳轉

  AuthManager(this._authRepository);

  // 給外部讀取的屬性
  User? get currentUser => _authRepository.currentUser;
  bool get isAdmin => _userRole == 'admin';
  bool get isLoading => _isLoading;

  // 初始化：啟動監聽
  Future<void> init() async {
    // 監聽 Supabase Auth 變化
    _authRepository.authStateChanges.listen((AuthState data) async {
      final AuthChangeEvent event = data.event;
      final Session? session = data.session;

      if (event == AuthChangeEvent.signedIn ||
          event == AuthChangeEvent.initialSession) {
        if (session != null) {
          // 已登入 -> 去查 Role
          await _updateUserRole(session.user.id);
        }
      } else if (event == AuthChangeEvent.signedOut) {
        // 已登出 -> 清空 Role
        _userRole = null;
      }

      _isLoading = false;
      notifyListeners(); // 🔥 通知 GoRouter 刷新
    });

    // 如果啟動時已經有 User (沒觸發監聽)，手動查一次
    if (currentUser != null) {
      await _updateUserRole(currentUser!.id);
      _isLoading = false;
      notifyListeners();
    } else {
      _isLoading = false;
    }
  }

  Future<void> _updateUserRole(String userId) async {
    // 呼叫 Repository 查資料
    _userRole = await _authRepository.fetchUserRole(userId);
    notifyListeners();
  }

  // 登出封裝
  Future<void> signOut() async {
    await _authRepository.signOut();
  }
}
