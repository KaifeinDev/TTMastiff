import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:ttmastiff/core/di/service_locator.dart';
import 'package:ttmastiff/data/services/course_repository.dart';

/// 這是共用的殼，包含底部的 NavigationBar
class ScaffoldWithNavBar extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const ScaffoldWithNavBar({required this.navigationShell, Key? key})
    : super(key: key ?? const ValueKey<String>('ScaffoldWithNavBar'));

  @override
  Widget build(BuildContext context) {
    final courseRepository = getIt<CourseRepository>();
    return Scaffold(
      // 這裡顯示當前路由的子頁面
      body: navigationShell,

      // 底部導航列
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (int index) {
          if (index == navigationShell.currentIndex) {
            // 切換分頁
            // 點擊可重載
            if (index == 1) {
              courseRepository.courseRefreshSignal.notify();
            }
            // if (index == 2) {
            //   BookingRepository.bookingRefreshSignal.notify();
            // }
            navigationShell.goBranch(index, initialLocation: true);
          } else {
            // 切換到其他分頁
            navigationShell.goBranch(index, initialLocation: false);
          }
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home), label: '首頁'),
          NavigationDestination(icon: Icon(Icons.calendar_month), label: '課程'),
          NavigationDestination(icon: Icon(Icons.bookmark), label: '我的課程'),
          NavigationDestination(icon: Icon(Icons.person), label: '檔案'),
        ],
      ),
    );
  }
}
