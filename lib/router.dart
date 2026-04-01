import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:ttmastiff/main.dart';

// --- 1. 一般頁面 ---
import 'ui/screens/login_screen.dart';
import 'ui/screens/register_screen.dart';
import 'ui/screens/reset_password_screen.dart';
import 'ui/screens/homepage_screen.dart';
import 'ui/screens/courses_screen.dart';
import 'ui/screens/course_detail_screen.dart'; // 這是前台的課程詳情
import 'ui/screens/my_bookings_screen.dart';
import 'ui/screens/profile_screen.dart';
import 'ui/screens/scaffold_with_nav_bar.dart';
import 'ui/screens/transaction_history_screen.dart';
import 'ui/screens/splash_screen.dart';
import 'ui/screens/notifications_screen.dart';
import 'ui/screens/notification_detail_screen.dart';
import 'ui/screens/activity_detail_screen.dart';

// --- 2. 管理後台頁面 ---
import '../ui/admin/admin_scaffold.dart';
import 'ui/admin/dashboard/dashboard_screen.dart';
import 'ui/admin/students/user_list_screen.dart';
import 'ui/admin/salary_management/salary_management_screen.dart';
import 'ui/admin/salary_management/hidden_page/staff_list_screen.dart';
import 'ui/admin/salary_management/hidden_page/salary_analytics_screen.dart';
import 'ui/admin/coach/coach_weekly_matrix_screen.dart';

// --- 3. 新增的課程管理頁面 (請確認檔案已建立) ---
// 原本的 course_manage_screen.dart 建議改名為 course_list_screen.dart
import '../ui/admin/courses/course_list_screen.dart';
import '../ui/admin/courses/course_detail_screen.dart';
import '../ui/admin/students/student_detail_screen.dart';
import '../ui/admin/transactions/admin_transaction_screen.dart';
import '../ui/admin/table_management_screen.dart';
import '../ui/admin/activities/activity_management_screen.dart';

// --- 4. Model ---
import 'data/models/course_model.dart';
import 'data/models/student_model.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

final appRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/login',
  refreshListenable: authManager,

  // 路由守衛 (Redirect Logic) - 保持不變
  redirect: (context, state) {
    final location = state.matchedLocation;
    final isAuthFlowPage = location == '/login' ||
        location == '/register' ||
        location == '/reset-password';

    // 如果 auth 正在初始化/刷新 token，但使用者目前已在登入/註冊頁
    // 就不要跳 splash，否則 login 頁會被重建，validator 的錯誤訊息會消失。
    if (authManager.isLoading) {
      final isAuthPage = location == '/login' ||
          location == '/register' ||
          location == '/reset-password';
      if (!isAuthPage) {
        return '/splash';
      }
    }
    final isSplash = state.matchedLocation == '/splash';
    final isLoggedIn = authManager.currentUser != null;
    final isAdmin = authManager.isAdmin;
    final isCoach = authManager.isCoach;

    if (isSplash && !isLoggedIn) return '/login';
    // 規則 1: 未登入 -> 踢回 /login
    if (!isLoggedIn && !isAuthFlowPage) return '/login';

    // 規則 2: 已登入 -> 根據身分分流
    if (isLoggedIn && (location == '/login' || location == '/register') ||
        isSplash) {
      return isAdmin || isCoach ? '/admin/dashboard' : '/homepage';
    }

    // 規則 2-1: admin-only 頁面（避免非 admin 仍可直接輸入網址存取）
    final isAdminOnlyPage = location == '/admin/activities' ||
        location == '/admin/transactions';
    if (isAdminOnlyPage && !isAdmin) {
      return isCoach ? '/admin/dashboard' : '/homepage';
    }

    // 規則 3: 一般用戶闖入後台 -> 踢回 /homepage
    if (isLoggedIn && location.startsWith('/admin') && !isAdmin && !isCoach) {
      if (kDebugMode) {
        debugPrint('[router] 非管理員導向 /admin，已導回 /homepage');
      }
      return '/homepage';
    }

    return null;
  },

  routes: [
    GoRoute(path: '/splash', builder: (context, state) => const SplashScreen()),
    GoRoute(path: '/', redirect: (context, state) => '/login'),

    // --- Auth 區域 ---
    GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
    GoRoute(
      path: '/register',
      builder: (context, state) => const RegisterScreen(),
    ),
    GoRoute(
      path: '/reset-password',
      builder: (context, state) => const ResetPasswordScreen(),
    ),

    // --- App 前台主區域 ---
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) {
        return ScaffoldWithNavBar(navigationShell: navigationShell);
      },
      branches: [
        // 分頁 1: 首頁（新增）
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/homepage',
              builder: (context, state) => const HomepageScreen(),
            ),
          ],
        ),
        // 分頁 2: 課程（原本的 /home）
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/home',
              builder: (context, state) => const CoursesScreen(),
              routes: [
                GoRoute(
                  path: 'course_detail/:courseId',
                  builder: (context, state) {
                    final courseId = state.pathParameters['courseId']!;
                    return CourseDetailScreen(courseId: courseId);
                  },
                ),
              ],
            ),
          ],
        ),
        // 分頁 3: 我的課程
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/bookings',
              builder: (context, state) => const MyBookingScreen(),
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
                // 這就是 /profile/transactions
                GoRoute(
                  path: 'transactions',
                  parentNavigatorKey:
                      _rootNavigatorKey, // 🌟 關鍵：加上這行，新頁面會蓋過 Bottom Bar
                  builder: (context, state) => const TransactionHistoryScreen(),
                ),
              ],
            ),
          ],
        ),
      ],
    ),

    // --- 通知頁面 (獨立路由，不在底部導航欄) ---
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

    // --- 活動詳情頁面 ---
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
        return AdminScaffold(
          isAdmin: authManager.isAdmin,
          child: child,
        );
      },
      routes: [
        GoRoute(
          path: '/admin/dashboard',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: DashboardScreen()),
        ),

        // 🔥 修改重點：課程管理路由升級 (巢狀結構)
        GoRoute(
          path: '/admin/courses',
          // 這是列表頁 (原 CourseManageScreen)
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: CourseListScreen()),
          routes: [
            // 這是詳情頁 (負責排課/場次管理)
            // 網址結構: /admin/courses/some-uuid-123
            GoRoute(
              path: ':courseId',
              pageBuilder: (context, state) {
                final courseId = state.pathParameters['courseId']!;

                // 接收從列表頁傳來的整個 Course 物件 (extra)，這樣可以不讀取 API 直接顯示標題
                // extra 是可選的，如果沒有傳遞則為 null
                final courseData = state.extra as CourseModel?;

                return NoTransitionPage(
                  child: AdminCourseDetailScreen(
                    // 注意：這裡我改了名字區分前台
                    courseId: courseId,
                    initialData: courseData,
                  ),
                );
              },
            ),
          ],
        ),
        GoRoute(
          path: '/admin/users',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: UserListScreen()),
          routes: [
            // 學生詳情頁
            GoRoute(
              path: ':studentId',
              builder: (context, state) {
                final studentId = state.pathParameters['studentId']!;
                final extraMap = state.extra as Map<String, dynamic>?;

                // 3. 從 Map 中取出資料 (如果 extraMap 是 null，這些也會是 null)
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
