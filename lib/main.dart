import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:ttmastiff/data/services/auth_manager.dart';
import 'package:ttmastiff/data/services/auth_repository.dart';
import 'package:ttmastiff/data/services/session_repository.dart';
import 'package:ttmastiff/data/services/coach_repository.dart';
import 'package:ttmastiff/data/services/course_repository.dart';
import 'package:ttmastiff/data/services/booking_repository.dart';
import 'package:ttmastiff/data/services/credit_repository.dart';
import 'package:ttmastiff/data/services/transaction_repository.dart';
import 'package:ttmastiff/data/services/student_repository.dart';
import 'package:ttmastiff/data/services/table_repository.dart';

import 'router.dart';

late final AuthRepository authRepository;
late final AuthManager authManager;
late final SessionRepository sessionRepository;
late final CoachRepository coachRepository;
late final CourseRepository courseRepository;
late final BookingRepository bookingRepository;
late final CreditRepository creditRepository;
late final TransactionRepository transactionRepository;
late final StudentRepository studentRepository;
late final TableRepository tableRepository;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await initializeDateFormatting('zh_TW', null);
    await dotenv.load(fileName: ".env");
    await Supabase.initialize(
      url: dotenv.env['SUPABASE_URL']!,
      anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
    );
    print("✅ Supabase initialized successfully");

    final client = Supabase.instance.client;
    // 3. 🔥 初始化 AuthRepository (資料層)
    authRepository = AuthRepository(client);

    // 4. 🔥 初始化 AuthManager (狀態層)
    authManager = AuthManager(authRepository);

    coachRepository = CoachRepository(client);
    courseRepository = CourseRepository(client);
    creditRepository = CreditRepository(client);
    sessionRepository = SessionRepository(client, creditRepository);
    transactionRepository = TransactionRepository(client);
    bookingRepository = BookingRepository(
      client,
      creditRepository,
      transactionRepository,
    );
    studentRepository = StudentRepository(client);
    tableRepository = TableRepository(client);

    // 5. 🔥 啟動監聽並檢查權限 (這會決定使用者一進去是 Home 還是 Admin)
    await authManager.init();
    print(
      "✅ AuthManager initialized (Role: ${authManager.isAdmin ? 'Admin' : 'User'})",
    );
  } catch (e) {
    print("❌ ERROR STARTING APP: $e");
  }

  runApp(const MyApp());
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
            side: BorderSide(
              color: const Color.fromARGB(255, 242, 148, 136), // 你想要的顏色
              width: 1,
            ),
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
        datePickerTheme: DatePickerThemeData(
          backgroundColor: Colors.white,
        ),
        // 全局 按鈕文字設定
        textTheme: const TextTheme(
          labelLarge: TextStyle(fontWeight: FontWeight.bold),
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
