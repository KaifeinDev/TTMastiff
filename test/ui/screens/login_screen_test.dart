import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ttmastiff/data/services/auth_manager.dart';
import 'package:ttmastiff/ui/screens/login_screen.dart';

class _MockAuthManager extends Mock implements AuthManager {}

void main() {
  testWidgets('登入畫面應該要有 Email 輸入框與登入按鈕', (WidgetTester tester) async {
    final mockAuth = _MockAuthManager();
    when(() => mockAuth.addListener(any())).thenReturn(null);
    when(() => mockAuth.removeListener(any())).thenReturn(null);

    // 1. 把畫面渲染出來 (Pump)
    await tester.pumpWidget(
      MaterialApp(home: LoginScreen(authManager: mockAuth)),
    );

    // 2. 尋找畫面上的元件（標題與按鈕皆為「登入」文字，按鈕需用 FilledButton 區分）
    final emailField = find.byType(TextField).first;
    final loginButton = find.widgetWithText(FilledButton, '登入');

    // 3. 驗證元件確實存在
    expect(emailField, findsOneWidget);
    expect(loginButton, findsOneWidget);

    // 不觸發登入按鈕：成功登入會呼叫 context.go，測試環境未掛 GoRouter。
  });
}
