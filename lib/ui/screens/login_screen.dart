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

  final _formKey = GlobalKey<FormState>();

  // 初始化 AuthRepository
  // 控制輸入框
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  // UI 狀態
  bool _isLoading = false;
  bool _obscurePassword = true; // 控制密碼是否隱藏
  String? _emailErrorText;
  String? _passwordErrorText;

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

    setState(() {
      _emailErrorText = null;
      _passwordErrorText = null;
    });

    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) return;

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
      setState(() {
        // 統一顯示單一錯誤訊息，避免暴露是帳號或密碼錯誤
        _emailErrorText = null;
        _passwordErrorText = '帳號或密碼錯誤';
      });

      // 觸發 validator 讓錯誤字串出現在輸入框下方
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _formKey.currentState?.validate();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleForgotPassword() async {
    final inputController = TextEditingController(
      text: _emailController.text.trim(),
    );
    String? dialogErrorText;

    final String? email = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('忘記密碼'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('請輸入要接收重設連結的 Email'),
                  const SizedBox(height: 12),
                  TextField(
                    controller: inputController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: 'Email',
                      border: const OutlineInputBorder(),
                      errorText: dialogErrorText,
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('取消'),
                ),
                FilledButton(
                  onPressed: () {
                    final value = inputController.text.trim();
                    if (value.isEmpty || !value.contains('@')) {
                      setStateDialog(() {
                        dialogErrorText = '請輸入有效的 Email';
                      });
                      return;
                    }
                    Navigator.pop(dialogContext, value);
                  },
                  child: const Text('送出重設連結'),
                ),
              ],
            );
          },
        );
      },
    );
    inputController.dispose();

    if (!mounted || email == null) return;

    try {
      await _auth.sendPasswordResetOtp(email);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('已寄送 6 碼驗證碼到信箱')));
      context.push('/reset-password?email=${Uri.encodeComponent(email)}');
    } catch (e) {
      if (!mounted) return;
      showErrorSnackBar(context, e, prefix: '寄送失敗：');
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _auth,
      builder: (context, child) {
        return Scaffold(
          appBar: AppBar(
            title: const Text(
              '登入',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
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
                  const SizedBox(height: 32),

                  Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        // Email 輸入框
                        TextFormField(
                          controller: _emailController,
                          decoration: const InputDecoration(
                            labelText: 'Email',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.email),
                          ),
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          validator: (val) {
                            if (_emailErrorText != null) {
                              return _emailErrorText;
                            }
                            if (val == null || val.trim().isEmpty) {
                              return '請輸入 Email';
                            }
                            if (!val.contains('@')) {
                              return '請輸入有效的 Email';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // 密碼輸入框
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          onFieldSubmitted: (_) => _handleLogin(),
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
                          validator: (val) {
                            if (_passwordErrorText != null) {
                              return _passwordErrorText;
                            }
                            if (val == null || val.isEmpty) {
                              return '請輸入密碼';
                            }
                            // 對齊註冊：至少 8 碼
                            if (val.length < 6) {
                              return '密碼長度至少需 6 碼';
                            }
                            return null;
                          },
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: _isLoading
                                ? null
                                : _handleForgotPassword,
                            child: const Text('忘記密碼？'),
                          ),
                        ),
                      ],
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
