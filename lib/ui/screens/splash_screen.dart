// lib/ui/screens/splash_screen.dart
import 'package:flutter/material.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/images/logo.png',
              width: 120,
              height: 120,
              fit: BoxFit.contain,
            ), // 暫時用 Icon 代替
            const SizedBox(height: 24),
            const Text(
              '天生好手',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 48),
            // 載入指示器
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            const Text('身分驗證中...', style: TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}
