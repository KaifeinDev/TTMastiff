import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:ttmastiff/main.dart';

// --- 1. 一般頁面 ---
import 'ui/screens/login_screen.dart';
import 'ui/screens/register_screen.dart';
import 'ui/screens/home_screen.dart';
import 'ui/screens/course_detail_screen.dart'; // 這是前台的課程詳情
import 'ui/screens/my_bookings_screen.dart';
import 'ui/screens/profile_screen.dart';
import 'ui/screens/scaffold_with_nav_bar.dart';

// --- 2. 管理後台頁面 ---
import '../ui/admin/admin_scaffold.dart';
import '../ui/admin/dashboard_screen.dart';
import 'ui/admin/students/user_list_screen.dart';

// --- 3. 新增的課程管理頁面 (請確認檔案已建立) ---
// 原本的 course_manage_screen.dart 建議改名為 course_list_screen.dart
import '../ui/admin/courses/course_list_screen.dart';
import '../ui/admin/courses/course_detail_screen.dart';

// --- 4. Model ---
import 'data/models/course_model.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

final appRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/login',
  refreshListenable: authManager,

  // 路由守衛 (Redirect Logic) - 保持不變
  redirect: (context, state) {
    if (authManager.isLoading) return null;
    final isLoggedIn = authManager.currentUser != null;
    final isAdmin = authManager.isAdmin;
    final location = state.matchedLocation;
    final isLoggingIn = location == '/login' || location == '/register';

    // 規則 1: 未登入 -> 踢回 /login
    if (!isLoggedIn && !isLoggingIn) return '/login';

    // 規則 2: 已登入 -> 根據身分分流
    if (isLoggedIn && isLoggingIn)
      return isAdmin ? '/admin/dashboard' : '/home';

    // 規則 3: 一般用戶闖入後台 -> 踢回 /home
    if (isLoggedIn && location.startsWith('/admin') && !isAdmin) {
      print('⛔ 權限不足：一般使用者嘗試進入後台');
      return '/home';
    }

    return null;
  },

  routes: [
    GoRoute(path: '/', redirect: (context, state) => '/login'),

    // --- Auth 區域 ---
    GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
    GoRoute(
      path: '/register',
      builder: (context, state) => const RegisterScreen(),
    ),

    // --- App 前台主區域 ---
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) {
        return ScaffoldWithNavBar(navigationShell: navigationShell);
      },
      branches: [
        // 分頁 1: 首頁
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/home',
              builder: (context, state) => const HomeScreen(),
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
        // 分頁 2: 我的課程
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/bookings',
              builder: (context, state) => const MyBookingScreen(),
            ),
          ],
        ),
        // 分頁 3: 個人檔案
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/profile',
              builder: (context, state) => const ProfileScreen(),
            ),
          ],
        ),
      ],
    ),

    // --- Admin 後台區域 ---
    ShellRoute(
      builder: (context, state, child) {
        return AdminScaffold(child: child);
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
        ),
      ],
    ),
  ],
);
