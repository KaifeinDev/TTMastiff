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

import 'router.dart';

late final AuthRepository authRepository;
late final AuthManager authManager;
late final SessionRepository sessionRepository;
late final CoachRepository coachRepository;
late final CourseRepository courseRepository;
late final BookingRepository bookingRepository;
late final CreditRepository creditRepository;
late final TransactionRepository transactionRepository;

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

    sessionRepository = SessionRepository(client);
    coachRepository = CoachRepository(client);
    courseRepository = CourseRepository(client);
    bookingRepository = BookingRepository(client);
    creditRepository = CreditRepository(client);
    transactionRepository = TransactionRepository(client);

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
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueAccent),
        useMaterial3: true,
      ),
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
