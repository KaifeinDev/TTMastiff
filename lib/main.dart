import 'package:flutter/foundation.dart' show kDebugMode;
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
import 'package:ttmastiff/data/services/salary_repository.dart';

import 'core/utils/util.dart';
import 'router.dart';
import 'ui/screens/splash_screen.dart';

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
late final SalaryRepository salaryRepository;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('zh_TW', null);
  runApp(const AppRoot());
}

/// 啟動殼：先顯示 Splash，再在背景初始化 Supabase / Repositories / AuthManager。
class AppRoot extends StatefulWidget {
  const AppRoot({super.key});

  @override
  State<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<AppRoot> {
  bool _ready = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    try {
      await dotenv.load(fileName: "env.prod");
      final supabaseUrl = dotenv.env['SUPABASE_URL'];
      final supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'];

      if (supabaseUrl == null || supabaseUrl.isEmpty) {
        throw Exception('Missing SUPABASE_URL in .env');
      }
      if (supabaseAnonKey == null || supabaseAnonKey.isEmpty) {
        throw Exception('Missing SUPABASE_ANON_KEY in .env');
      }

      await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
      if (kDebugMode) {
        debugPrint('[main] Supabase initialized');
      }

      final client = Supabase.instance.client;
      authRepository = AuthRepository(client);
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
      salaryRepository = SalaryRepository(client);

      await authManager.init();
      if (kDebugMode) {
        debugPrint(
          '[main] AuthManager ready (admin=${authManager.isAdmin})',
        );
      }

      if (!mounted) return;
      setState(() {
        _ready = true;
      });
    } catch (e, st) {
      logError(e, st);
      if (!mounted) return;
      setState(() {
        _error = e;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      // 啟動失敗時，顯示簡單錯誤畫面，避免白屏。
      return MaterialApp(
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    '無法啟動應用程式',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _error.toString(),
                    style: const TextStyle(fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    if (!_ready) {
      // 初始化期間，先顯示 Splash 畫面（Logo + 轉圈）。
      return const MaterialApp(
        home: SplashScreen(),
      );
    }

    return const MyApp();
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: '天生好手',
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
        datePickerTheme: DatePickerThemeData(backgroundColor: Colors.white),
        // 全局 按鈕文字設定
        textTheme: const TextTheme(
          labelLarge: TextStyle(fontWeight: FontWeight.bold),
        ),
        tabBarTheme: const TabBarThemeData(
          labelStyle: TextStyle(fontWeight: FontWeight.bold),
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
