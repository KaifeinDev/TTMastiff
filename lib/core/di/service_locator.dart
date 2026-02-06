// lib/core/di/service_locator.dart
import 'package:get_it/get_it.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ttmastiff/data/services/coach_repository.dart';
// Import Repository
import '../../data/services/auth_manager.dart';
import '../../data/services/auth_repository.dart';
import '../../data/services/coach_repository.dart';
import '../../data/services/course_repository.dart';
import '../../data/services/credit_repository.dart';
import '../../data/services/session_repository.dart';
import '../../data/services/transaction_repository.dart';
import '../../data/services/booking_repository.dart';
import '../../data/services/student_repository.dart';
import '../../data/services/table_repository.dart';
import '../../data/services/salary_repository.dart';

final getIt = GetIt.instance;

void setupLocator() {
  // =========================================================
  // 1. 外部服務 (External Services)
  // =========================================================
  // 註冊 Supabase Client，這樣所有 Repo 都可以直接取得 client
  getIt.registerLazySingleton<SupabaseClient>(() => Supabase.instance.client);
  getIt.registerLazySingleton<SupabaseClient>(() => Supabase.instance.client);

  // =========================================================
  // 基礎層 Repositories (只依賴 SupabaseClient)
  // =========================================================
  getIt.registerLazySingleton<AuthRepository>(
    () => AuthRepository(getIt<SupabaseClient>()),
  );

  getIt.registerLazySingleton<CoachRepository>(
    () => CoachRepository(getIt<SupabaseClient>()),
  );

  getIt.registerLazySingleton<CourseRepository>(
    () => CourseRepository(getIt<SupabaseClient>()),
  );

  // CreditRepo 被 SessionRepo 和 BookingRepo 依賴，必須先註冊
  getIt.registerLazySingleton<CreditRepository>(
    () => CreditRepository(getIt<SupabaseClient>()),
  );

  // TransactionRepo 被 BookingRepo 依賴，必須先註冊
  getIt.registerLazySingleton<TransactionRepository>(
    () => TransactionRepository(getIt<SupabaseClient>()),
  );

  getIt.registerLazySingleton<StudentRepository>(
    () => StudentRepository(getIt<SupabaseClient>()),
  );

  getIt.registerLazySingleton<TableRepository>(
    () => TableRepository(getIt<SupabaseClient>()),
  );

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
      getIt<CreditRepository>(), // 自動注入已註冊的 CreditRepo
      getIt<TransactionRepository>(), // 自動注入已註冊的 TransactionRepo
    ),
  );

  // SessionRepository: 依賴 Client, CreditRepo
  // (註：如果您上一輪重構已經移除 CreditRepo 依賴並改用 BookingRepo，請自行調整這裡的參數)
  getIt.registerLazySingleton<SessionRepository>(
    () => SessionRepository(
      getIt<SupabaseClient>(),
      getIt<CreditRepository>(),
      // 若您已完成上一輪重構，這裡可能要多加一個: getIt<BookingRepository>(),
    ),
  );

  // =========================================================
  // 4. 狀態管理層 Managers (Logic / State)
  // =========================================================
  // AuthManager: 依賴 AuthRepository
  getIt.registerLazySingleton<AuthManager>(
    () => AuthManager(getIt<AuthRepository>()),
  );

  // ... 把 main.dart 裡初始化的東西都搬來這裡
}
