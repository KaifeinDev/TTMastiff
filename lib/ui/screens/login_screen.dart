import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('登入')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('這是登入頁 (待實作)'),
            ElevatedButton(
              onPressed: () => context.go('/register'), // 測試跳轉
              child: const Text('去註冊'),
            ),
             TextButton(
              // 暫時用來繞過登入直接進首頁 (開發用)
              onPressed: () => context.go('/home'), 
              child: const Text('略過登入 (測試用)'),
            ),
          ],
        ),
      ),
    );
  }
}
