import 'package:go_router/go_router.dart';
import 'ui/screens/home_screen.dart';
import 'ui/screens/course_detail_screen.dart';

// 將變數設為 public (沒有底線)，讓 main.dart 可以存取
final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const HomeScreen(),
      routes: [
        // 子路由：詳情頁
        GoRoute(
          path: 'course/:id',
          builder: (context, state) {
            final id = state.pathParameters['id']!;
            return CourseDetailScreen(courseId: id);
          },
        ),
      ],
    ),
  ],
);
