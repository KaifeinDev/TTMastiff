import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:ttmastiff/data/services/session_repository.dart';
import 'package:ttmastiff/data/models/session_model.dart';
// 引入所有頁面
import 'ui/screens/login_screen.dart';
import 'ui/screens/register_screen.dart';
import 'ui/screens/home_screen.dart';
import 'ui/screens/course_detail_screen.dart';
import 'ui/screens/my_bookings_screen.dart';
import 'ui/screens/profile_screen.dart';
import 'ui/screens/scaffold_with_nav_bar.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

final appRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/login', // 暫時先設為登入頁，方便測試流程
  routes: [
    GoRoute(
      path: '/',
      redirect: (context, state) => '/login',
    ),
    // --- 1. Auth 區域 (沒有底部導航) ---
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/register',
      builder: (context, state) => const RegisterScreen(),
    ),

    // --- 2. App 主區域 (有底部導航) ---
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) {
        return ScaffoldWithNavBar(navigationShell: navigationShell);
      },
      branches: [
        // 第一個分頁: 課程首頁
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/home',
              builder: (context, state) => const HomeScreen(),
              routes: [
                // 課程詳情頁 (屬於首頁的子路由)
                // 🔴 修改點：路徑改成簡單的標識，並從 extra 讀取物件
                GoRoute(
                  path: 'course_detail/:courseId', // 完整路徑變成 /home/course_detail
                  builder: (context, state) {
                    // 從 extra 拿出 SessionModel
                    // 注意：如果直接輸入網址進入，extra 會是 null，這裡假設都是從點擊進入
                    final courseId = state.pathParameters['courseId']!;
                    return CourseDetailScreen(courseId: courseId);
                  },
                ),
              ],
            ),
          ],
        ),

        // 第二個分頁: 我的課程
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/bookings',
              builder: (context, state) => const MyBookingsScreen(),
            ),
          ],
        ),

        // 第三個分頁: 個人檔案
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
  ],
);
