import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:ttmastiff/core/utils/util.dart';
import 'package:ttmastiff/data/services/auth_manager.dart';
import 'package:ttmastiff/main.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.authManager});

  /// 測試或自訂注入；為 null 時使用 [main] 的全域 [authManager]。
  final AuthManager? authManager;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  AuthManager get _auth => widget.authManager ?? authManager;

  // 初始化 AuthRepository
  // 控制輸入框
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  // UI 狀態
  bool _isLoading = false;
  bool _obscurePassword = true; // 控制密碼是否隱藏

  // 釋放記憶體
  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // 執行登入邏輯
  Future<void> _handleLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    // final email = "admin@admin.com";
    // final password = "test123";

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('請輸入 Email 和密碼')));
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // 呼叫 Repository 進行登入
      await _auth.signIn(email: email, password: password);

      if (!mounted) return;
      // 登入成功，跳轉到首頁（context.go 會直接替換堆疊）
      if (_auth.isAdmin) {
        context.go('/admin/dashboard');
      } else {
        context.go('/home');
      }
    } catch (e) {
      if (!mounted) return;
      showErrorSnackBar(context, e);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _auth,
      builder: (context, child) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('登入', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          body: Center(
            child: SingleChildScrollView(
              // 避免鍵盤跳出時擋住畫面
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch, // 讓按鈕跟輸入框同寬
                children: [
                  Image.asset(
                    'assets/images/logo.png',
                    width: 120,
                    height: 120,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    '歡迎回到 TTMastiff',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 32),

                  // Email 輸入框
                  TextField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.email),
                    ),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 16),

                  // 密碼輸入框
                  TextField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    onSubmitted: (value) {
                      _handleLogin();
                    },
                    decoration: InputDecoration(
                      labelText: '密碼',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.lock),
                      // 顯示/隱藏密碼的眼睛按鈕
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility
                              : Icons.visibility_off,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 登入按鈕
                  FilledButton(
                    onPressed: _isLoading ? null : _handleLogin,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text('登入', style: TextStyle(fontSize: 16)),
                  ),

                  const SizedBox(height: 16),

                  // 註冊連結
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('還沒有帳號嗎？'),
                      TextButton(
                        onPressed: () =>
                            context.push('/register'), // 使用 push 這樣可以按上一頁回來
                        child: const Text('立即註冊'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
