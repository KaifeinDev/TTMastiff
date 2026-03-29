import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ttmastiff/main.dart' as app;

void main() {
  // 初始化整合測試
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('完整使用者預約課程流程', (WidgetTester tester) async {
    // 1. 啟動整個 App
    app.main();
    await tester.pumpAndSettle(); // 等待所有動畫與非同步操作完成

    // 2. 模擬登入流程
    await tester.enterText(
      find.byKey(const Key('email_input')),
      'user@test.com',
    );
    await tester.enterText(find.byKey(const Key('password_input')), '123456');
    await tester.tap(find.text('登入'));
    await tester.pumpAndSettle(); // 等待換頁與 API 回傳

    // 3. 尋找課程並點擊預約
    expect(find.text('首頁'), findsOneWidget); // 確認成功進到首頁
    await tester.tap(find.text('報名課程'));
    await tester.pumpAndSettle();

    // ... 繼續模擬點擊直到預約成功
  });
}
