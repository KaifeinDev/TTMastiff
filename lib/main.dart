import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/di/service_locator.dart';
import 'package:ttmastiff/features/auth/data/repositories/auth_manager.dart';
import 'router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await initializeDateFormatting('zh_TW', null);
    await dotenv.load(fileName: ".env");
    await Supabase.initialize(
      url: dotenv.env['SUPABASE_URL']!,
      anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
    );
    setupLocator();
    getIt<AuthManager>().init();
    runApp(const MyApp());
  } catch (e) {
    debugPrint('初始化失敗: $e');
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'TTMastiff 球館系統',
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: Colors.grey.shade50,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Color(0xFFD32D26),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        // 全局 Card 主題設定
        cardTheme: CardThemeData(
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        // 全局 Dialog 主題設定
        dialogTheme: DialogThemeData(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          titleTextStyle: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        // 全局 DatePicker 主題設定
        datePickerTheme: DatePickerThemeData(backgroundColor: Colors.white),
        // 全局 按鈕文字設定
        textTheme: const TextTheme(
          labelLarge: TextStyle(fontWeight: FontWeight.bold),
        ),
        tabBarTheme: const TabBarThemeData(
          labelStyle: TextStyle(fontWeight: FontWeight.bold),
        ),
        // 全局 Menu 主題設定（包含 DropdownButton 的下拉清單）
        menuTheme: MenuThemeData(
          style: MenuStyle(
            backgroundColor: WidgetStateProperty.all(Colors.white),
            surfaceTintColor: WidgetStateProperty.all(Colors.transparent),
          ),
        ),
      ),
      // 🔥 新增：深色主題
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        // 深色模式下的背景色通常不是純黑，而是深灰
        scaffoldBackgroundColor: const Color(0xFF121212),
        cardColor: const Color(0xFF1E1E1E),
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blueAccent,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      themeMode: ThemeMode.system,

      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('zh', 'TW'), Locale('en', 'US')],
      // 使用我們抽離出來的 router 設定
      routerConfig: appRouter,
    );
  }
}
