import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // 引入 services 以使用 input formatters
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/services/auth_repository.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  // 建議將 Supabase client 注入或使用 Provider/GetIt 管理，這裡先維持原樣
  final _repository = AuthRepository(Supabase.instance.client);
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _medicalNoteController = TextEditingController();
  DateTime? _selectedDate;

  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _medicalNoteController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2000, 1, 1), // 預設停在 2000 年
      firstDate: DateTime(1900),
      lastDate: now,
      locale: const Locale('zh', 'TW'), // 如果有設 localization
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _handleRegister() async {
    // 隱藏鍵盤
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('請選擇出生年月日')));
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // 呼叫更新後的 AuthRepository
      await _repository.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
        fullName: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        birthDate: _selectedDate!,
        medicalNote: _medicalNoteController.text.trim().isEmpty
            ? null
            : _medicalNoteController.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🎉 註冊成功！系統已自動建立您的學員檔案。'),
            backgroundColor: Colors.green,
          ),
        );
        // 註冊成功後通常跳轉首頁，或是驗證信頁面 (視 Supabase 設定而定)
        context.go('/home');
      }
    } catch (e) {
      if (mounted) {
        // 簡單處理錯誤訊息，去掉 Exception 前綴
        final msg = e.toString().replaceAll('Exception: ', '');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ 註冊失敗: $msg'),
            backgroundColor: Colors.red,
          ),
        );
      }
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
    return Scaffold(
      appBar: AppBar(title: const Text('註冊帳號')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  '加入 TTMastiff',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 32),

                // 1. 姓名
                TextFormField(
                  controller: _nameController,
                  textInputAction: TextInputAction.next, // 按 Enter 跳下一格
                  decoration: const InputDecoration(
                    labelText: '真實姓名',
                    hintText: '請輸入您的全名',
                    prefixIcon: Icon(Icons.badge_outlined),
                    border: OutlineInputBorder(),
                  ),
                  validator: (val) =>
                      (val == null || val.trim().isEmpty) ? '請輸入姓名' : null,
                ),
                const SizedBox(height: 16),

                // 2. 📱 手機號碼 (加強版)
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  // 限制只能輸入數字且最多 10 碼
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(10),
                  ],
                  decoration: const InputDecoration(
                    labelText: '手機號碼',
                    hintText: '09xxxxxxxx',
                    prefixIcon: Icon(Icons.phone_android),
                    border: OutlineInputBorder(),
                  ),
                  validator: (val) {
                    if (val == null || val.isEmpty) return '請輸入手機號碼';
                    // 台灣手機號碼 Regex 驗證
                    if (!RegExp(r'^09\d{8}$').hasMatch(val)) {
                      return '請輸入有效的台灣手機號碼 (09開頭)';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // 3. 生日
                InkWell(
                  onTap: _pickDate,
                  child: InputDecorator(
                    decoration: const InputDecoration(
                    labelText: '出生年月日',
                    prefixIcon: Icon(Icons.cake_outlined),
                    border: OutlineInputBorder(),
                    ),
                    child: Text(
                      _selectedDate == null
                          ? '點擊選擇日期'
                          : '${_selectedDate!.year} 年 ${_selectedDate!.month} 月 ${_selectedDate!.day} 日',
                      style: TextStyle(
                        color: _selectedDate == null
                            ? Colors.grey.shade600
                            : Colors.black,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),


                // 5. Email
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email_outlined),
                    border: OutlineInputBorder(),
                  ),
                  validator: (val) => (val == null || !val.contains('@'))
                      ? '請輸入有效的 Email'
                      : null,
                ),
                const SizedBox(height: 16),

                // 6. 密碼
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: '密碼',
                    prefixIcon: const Icon(Icons.lock_outline),
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined),
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                  validator: (val) =>
                      (val == null || val.length < 6) ? '密碼長度至少需 6 碼' : null,
                ),
                const SizedBox(height: 16),

                // 7. 確認密碼
                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: _obscurePassword,
                  textInputAction: TextInputAction.done, // 最後一格顯示完成
                  onFieldSubmitted: (_) => _handleRegister(), // 按 Enter 直接送出
                  decoration: const InputDecoration(
                    labelText: '再次確認密碼',
                    prefixIcon: Icon(Icons.lock_outline),
                    border: OutlineInputBorder(),
                  ),
                  validator: (val) =>
                      (val != _passwordController.text) ? '兩次輸入的密碼不一致' : null,
                ),
                const SizedBox(height: 24),

                // 4. 醫療備註
                TextFormField(
                  controller: _medicalNoteController,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: '身體狀況備註 (選填)',
                    hintText: '如：氣喘、舊傷、過敏...',
                    prefixIcon: Icon(Icons.medical_information_outlined),
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2, // 允許兩行
                ),

                const SizedBox(height: 16),

                // 8. 註冊按鈕
                FilledButton(
                  onPressed: _isLoading ? null : _handleRegister,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Text('立即註冊', style: TextStyle(fontSize: 16)),
                ),
                const SizedBox(height: 16),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('已經有帳號了嗎？'),
                    TextButton(
                      onPressed: () => context.go('/login'),
                      child: const Text('直接登入'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
