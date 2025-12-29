import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// 這是共用的殼，包含底部的 NavigationBar
class ScaffoldWithNavBar extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const ScaffoldWithNavBar({
    required this.navigationShell,
    Key? key,
  }) : super(key: key ?? const ValueKey<String>('ScaffoldWithNavBar'));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 這裡顯示當前路由的子頁面
      body: navigationShell,
      
      // 底部導航列
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (int index) {
          // 切換分頁
          navigationShell.goBranch(
            index,
            initialLocation: index == navigationShell.currentIndex,
          );
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.calendar_month), label: '課程'),
          NavigationDestination(icon: Icon(Icons.bookmark), label: '我的課程'),
          NavigationDestination(icon: Icon(Icons.person), label: '檔案'),
        ],
      ),
    );
  }
}
