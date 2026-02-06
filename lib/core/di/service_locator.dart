import 'package:get_it/get_it.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// =========================================================
// Features Imports (請確認以下路徑與您搬移後的檔案位置相符)
// =========================================================

// Auth Feature
// (假設您將搬到 features/auth/data/repositories/)
import '../../features/auth/data/repositories/auth_repository.dart';
// (假設您將搬到 features/auth/presentation/manager/ 或 data/services/)
import '../../features/auth/data/repositories/auth_manager.dart'; 

// Student Feature
import '../../features/student/data/repositories/student_repository.dart';

// Course Feature
import '../../features/course/data/repositories/course_repository.dart';
import '../../features/course/data/repositories/session_repository.dart';

// Finance Feature
import '../../features/finance/data/repositories/credit_repository.dart';
import '../../features/finance/data/repositories/transaction_repository.dart';
import '../../features/finance/data/repositories/salary_repository.dart';

// Booking Feature
import '../../features/booking/data/repositories/booking_repository.dart';

// Coach (Staff) Feature
// (假設您將搬到 features/coach/data/repositories/)
import '../../features/coach/data/repositories/coach_repository.dart';

// Table Feature
// (假設您將搬到 features/table/data/repositories/)
import '../../features/table/data/repositories/table_repository.dart';


// 建立全域的 getIt 實體
final getIt = GetIt.instance;

void setupLocator() {
  // =========================================================
  // 1. 外部服務 (External Services)
  // =========================================================
  getIt.registerLazySingleton<SupabaseClient>(() => Supabase.instance.client);

  // =========================================================
  // 2. 基礎層 Repositories (只依賴 SupabaseClient)
  // =========================================================
  
  // Auth
  getIt.registerLazySingleton<AuthRepository>(
    () => AuthRepository(getIt<SupabaseClient>()),
  );

  // Coach
  getIt.registerLazySingleton<CoachRepository>(
    () => CoachRepository(getIt<SupabaseClient>()),
  );

  // Course
  getIt.registerLazySingleton<CourseRepository>(
    () => CourseRepository(getIt<SupabaseClient>()),
  );

  // Student
  getIt.registerLazySingleton<StudentRepository>(
    () => StudentRepository(getIt<SupabaseClient>()),
  );

  // Table
  getIt.registerLazySingleton<TableRepository>(
    () => TableRepository(getIt<SupabaseClient>()),
  );
  
  // Finance - Basic
  // 注意：CreditRepo 被 SessionRepo 和 BookingRepo 依賴，必須先註冊
  getIt.registerLazySingleton<CreditRepository>(
    () => CreditRepository(getIt<SupabaseClient>()),
  );
  
  // Finance - Transaction
  // 注意：TransactionRepo 被 BookingRepo 依賴，必須先註冊
  getIt.registerLazySingleton<TransactionRepository>(
    () => TransactionRepository(getIt<SupabaseClient>()),
  );

  // Finance - Salary
  getIt.registerLazySingleton<SalaryRepository>(
    () => SalaryRepository(getIt<SupabaseClient>()),
  );

  // =========================================================
  // 3. 複合層 Repositories (依賴其他 Repositories)
  // =========================================================
  
  // BookingRepository: 依賴 Client, CreditRepo, TransactionRepo
  getIt.registerLazySingleton<BookingRepository>(
    () => BookingRepository(
      getIt<SupabaseClient>(),
      getIt<CreditRepository>(),      
      getIt<TransactionRepository>(), 
    ),
  );

  // SessionRepository: 依賴 Client, CreditRepo
  getIt.registerLazySingleton<SessionRepository>(
    () => SessionRepository(
      getIt<SupabaseClient>(),
      getIt<CreditRepository>(), 
      // 若您之後有讓 Session 依賴 Booking，請在這裡補上 getIt<BookingRepository>()
    ),
  );

  // =========================================================
  // 4. 狀態管理層 Managers (Logic / State)
  // =========================================================
  
  // AuthManager: 依賴 AuthRepository
  getIt.registerLazySingleton<AuthManager>(
    () => AuthManager(getIt<AuthRepository>()),
  );
}