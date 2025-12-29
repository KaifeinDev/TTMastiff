import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class RegisterScreen extends StatelessWidget {
  const RegisterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('註冊帳號')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('這是註冊頁 (待實作)'),
            TextButton(
              onPressed: () => context.go('/login'),
              child: const Text('已有帳號？登入'),
            ),
          ],
        ),
      ),
    );
  }
}
