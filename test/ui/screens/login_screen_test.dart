import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ttmastiff/ui/screens/login_screen.dart';

// import 你的 LoginScreen

void main() {
  testWidgets('登入畫面應該要有 Email 輸入框與登入按鈕', (WidgetTester tester) async {
    // 1. 把畫面渲染出來 (Pump)
    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));

    // 2. 尋找畫面上的元件
    final emailField = find.byType(TextField).first;
    final loginButton = find.text('登入');

    // 3. 驗證元件確實存在
    expect(emailField, findsOneWidget);
    expect(loginButton, findsOneWidget);

    // 4. 模擬使用者輸入與點擊
    await tester.enterText(emailField, 'test@example.com');
    await tester.tap(loginButton);
    await tester.pump(); // 點擊後重新渲染畫面
  });
}
