import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:ttmastiff/core/di/service_locator.dart';
import 'package:ttmastiff/features/auth/data/repositories/auth_manager.dart'; // 注意: AuthManager 路徑通常在 data/services 或 data/repositories

// --- 1. 一般頁面 (Client) ---
import 'features/auth/presentation/screens/login_screen.dart';
import 'features/auth/presentation/screens/register_screen.dart';
import 'features/auth/presentation/screens/splash_screen.dart';
import 'features/auth/presentation/screens/profile_screen.dart';
import 'features/home/presentation/screens/client_scaffold.dart';
import 'features/home/presentation/screens/client_home_screen.dart'; // 類別名通常是 ClientHomeScreen

// 使用 'as' 避免與 Admin 的 CourseDetailScreen 衝突
import 'features/course/presentation/screens/client/courses_screen.dart';
import 'features/course/presentation/screens/client/course_detail_screen.dart'
    as ClientCourse;

import 'features/booking/presentation/screens/my_bookings_screen.dart';
import 'features/finance/presentation/screens/client/transaction_history_screen.dart';
import 'features/activity/presentation/screens/client/notifications_screen.dart';
import 'features/activity/presentation/screens/client/notification_detail_screen.dart';
import 'features/activity/presentation/screens/client/activity_detail_screen.dart';

// --- 2. 管理後台頁面 (Admin) ---
import 'features/home/presentation/screens/admin_scaffold.dart';
import 'features/home/presentation/screens/admin_dashboard_screen.dart';
import 'features/student/presentation/screens/student_list_screen.dart';
import 'features/student/presentation/screens/student_detail_screen.dart';
import 'features/finance/presentation/screens/admin/salary_management_screen.dart';
import 'features/finance/presentation/screens/admin/salary_analytics_screen.dart';
import 'features/finance/presentation/screens/admin/admin_transaction_screen.dart';
import 'features/coach/presentation/screens/staff_list_screen.dart';
import 'features/coach/presentation/screens/coach_weekly_matrix_screen.dart';
import 'features/table/presentation/screens/table_management_screen.dart';
import 'features/activity/presentation/screens/admin/activity_management_screen.dart';

// 使用 'as' 避免衝突
import 'features/course/presentation/screens/admin/course_list_screen.dart';
import 'features/course/presentation/screens/admin/course_detail_screen.dart'
    as AdminCourse;

// --- 3. Models ---
import 'features/course/data/models/course_model.dart';
import 'features/student/data/models/student_model.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final authManager = getIt<AuthManager>();

final appRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/login',
  refreshListenable: authManager,

  // 路由守衛 (Redirect Logic)
  redirect: (context, state) {
    if (authManager.isLoading) {
      return '/splash';
    }
    final isSplash = state.matchedLocation == '/splash';
    final isLoggedIn = authManager.currentUser != null;
    final isAdmin = authManager.isAdmin;
    final isCoach = authManager.isCoach; // 假設 Coach 權限與 Admin 類似
    final location = state.matchedLocation;
    final isLoggingIn = location == '/login' || location == '/register';

    // 規則 1: 啟動檢查
    if (isSplash && !isLoggedIn) return '/login';

    // 規則 2: 未登入用戶嘗試訪問內部頁面 -> 踢回 /login
    if (!isLoggedIn && !isLoggingIn) return '/login';

    // 規則 3: 已登入用戶在登入頁或 Splash -> 根據身分分流
    if (isLoggedIn && (isLoggingIn || isSplash)) {
      return (isAdmin || isCoach) ? '/admin/dashboard' : '/homepage';
    }

    // 規則 4: 一般用戶嘗試訪問 /admin 開頭的頁面 -> 踢回首頁
    if (isLoggedIn && location.startsWith('/admin') && !isAdmin && !isCoach) {
      print('⛔ 權限不足：一般使用者嘗試進入後台');
      return '/homepage';
    }

    return null;
  },

  routes: [
    GoRoute(path: '/splash', builder: (context, state) => const SplashScreen()),

    // --- Auth 區域 ---
    GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
    GoRoute(
      path: '/register',
      builder: (context, state) => const RegisterScreen(),
    ),

    // --- App 前台主區域 (User) ---
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) {
        // 請確保 ClientScaffold 接受 navigationShell 參數
        return ClientScaffold(navigationShell: navigationShell);
      },
      branches: [
        // 分頁 1: 首頁
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/homepage',
              // 修正：類別名應對應 client_home_screen.dart
              builder: (context, state) => const ClientHomeScreen(),
            ),
          ],
        ),
        // 分頁 2: 課程列表
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/home', // 建議未來可以改為 /courses 比較語意化，目前先維持 /home
              builder: (context, state) => const CoursesScreen(),
              routes: [
                GoRoute(
                  path: 'course_detail/:courseId',
                  builder: (context, state) {
                    final courseId = state.pathParameters['courseId']!;
                    // 使用別名 ClientCourse 調用前台的 CourseDetailScreen
                    return ClientCourse.CourseDetailScreen(courseId: courseId);
                  },
                ),
              ],
            ),
          ],
        ),
        // 分頁 3: 我的課程/預約
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/bookings',
              // 修正：類別名應對應 my_bookings_screen.dart (通常有s)
              builder: (context, state) => const MyBookingsScreen(),
            ),
          ],
        ),
        // 分頁 4: 個人檔案
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/profile',
              builder: (context, state) => const ProfileScreen(),
              routes: [
                GoRoute(
                  path: 'transactions',
                  parentNavigatorKey: _rootNavigatorKey, // 蓋過 Bottom Bar
                  builder: (context, state) => const TransactionHistoryScreen(),
                ),
              ],
            ),
          ],
        ),
      ],
    ),

    // --- 獨立功能頁面 (User) ---
    GoRoute(
      path: '/notifications',
      builder: (context, state) => const NotificationsScreen(),
      routes: [
        GoRoute(
          path: ':notificationId',
          parentNavigatorKey: _rootNavigatorKey,
          builder: (context, state) {
            final notificationId = state.pathParameters['notificationId']!;
            return NotificationDetailScreen(notificationId: notificationId);
          },
        ),
      ],
    ),
    GoRoute(
      path: '/activity/:activityId',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        final activityId = state.pathParameters['activityId']!;
        return ActivityDetailScreen(activityId: activityId);
      },
    ),

    // --- Admin 後台區域 ---
    ShellRoute(
      builder: (context, state, child) {
        return AdminScaffold(child: child);
      },
      routes: [
        GoRoute(
          path: '/admin/dashboard',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: AdminDashboardScreen(),
          ), // 修正 Class 名稱
        ),

        // Admin 課程管理
        GoRoute(
          path: '/admin/courses',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: CourseListScreen()),
          routes: [
            GoRoute(
              path: ':courseId',
              pageBuilder: (context, state) {
                final courseId = state.pathParameters['courseId']!;
                final courseData = state.extra as CourseModel?;

                // 使用別名 AdminCourse 調用後台的 Detail Screen
                return NoTransitionPage(
                  child: AdminCourse.AdminCourseDetailScreen(
                    courseId: courseId,
                    initialData: courseData,
                  ),
                );
              },
            ),
          ],
        ),

        // Admin 用戶/學生管理
        GoRoute(
          path: '/admin/users',
          // 修正：檔案名是 student_list_screen.dart，所以 Class 應該是 StudentListScreen
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: StudentListScreen()),
          routes: [
            GoRoute(
              path: ':studentId',
              builder: (context, state) {
                final studentId = state.pathParameters['studentId']!;
                final extraMap = state.extra as Map<String, dynamic>?;

                final studentData = extraMap?['student'] as StudentModel?;
                final parentName = extraMap?['parentName'] as String?;
                final parentPhone = extraMap?['parentPhone'] as String?;

                return StudentDetailScreen(
                  studentId: studentId,
                  initialStudent: studentData,
                  initialParentName: parentName,
                  initialParentPhone: parentPhone,
                );
              },
            ),
          ],
        ),

        // Admin 財務與其他
        GoRoute(
          path: '/admin/transactions',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: AdminTransactionScreen()),
        ),
        GoRoute(
          path: '/admin/tables',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: TableManagementScreen()),
        ),
        GoRoute(
          path: '/admin/salaries',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: SalaryManagementScreen()),
        ),
        GoRoute(
          path: '/admin/salary_analytics',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: SalaryAnalyticsScreen()),
        ),
        GoRoute(
          path: '/admin/staff_list',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: StaffListScreen()),
        ),
        GoRoute(
          path: '/admin/activities',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: ActivityManagementScreen()),
        ),
        GoRoute(
          path: '/admin/coach_matrix',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: CoachWeeklyMatrixScreen()),
        ),
      ],
    ),
  ],
);
