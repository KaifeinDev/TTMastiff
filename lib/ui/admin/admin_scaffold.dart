import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AdminScaffold extends StatefulWidget {
  final Widget child;
  const AdminScaffold({super.key, required this.child});

  @override
  State<AdminScaffold> createState() => _AdminScaffoldState();
}

class _AdminScaffoldState extends State<AdminScaffold> {
  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final bool isDesktop = screenWidth > 900;

    final currentPath = GoRouterState.of(context).uri.toString();

    return Scaffold(
      appBar: AppBar(
        title: const Text('TTMastiff 球館管理系統'),
        backgroundColor: Colors.blueGrey.shade900,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.home),
            tooltip: '回前台 App',
            onPressed: () => context.go('/home'),
          ),
        ],
      ),
      drawer: isDesktop ? null : Drawer(child: _buildSidebar(context)),
      body: Row(
        children: [
          if (isDesktop)
            Container(
              width: 260,
              color: Colors.blueGrey.shade800,
              child: _buildSidebar(context, isDark: true),
            ),
          Expanded(
            child: Container(
              color: Colors.grey.shade100, // 背景色淡灰，突顯內容
              padding: const EdgeInsets.all(24),
              child: KeyedSubtree(
                key: ValueKey(currentPath),
                child: widget.child,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar(BuildContext context, {bool isDark = false}) {
    final textColor = isDark ? Colors.white70 : Colors.black87;
    final iconColor = isDark ? Colors.white70 : Colors.black54;

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 20),
      children: [
        _AdminMenuItem(
          icon: Icons.dashboard,
          title: '儀表板',
          route: '/admin/dashboard',
          textColor: textColor,
          iconColor: iconColor,
        ),
        _AdminMenuItem(
          icon: Icons.calendar_month,
          title: '場次管理',
          route: '/admin/courses',
          textColor: textColor,
          iconColor: iconColor,
        ),
        _AdminMenuItem(
          icon: Icons.people,
          title: '學員與點數',
          route: '/admin/users',
          textColor: textColor,
          iconColor: iconColor,
        ),
      ],
    );
  }
}

class _AdminMenuItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String route;
  final Color textColor;
  final Color iconColor;

  const _AdminMenuItem({
    required this.icon,
    required this.title,
    required this.route,
    required this.textColor,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    // 檢查當前路徑是否選中 (簡單實作)
    final isSelected = GoRouterState.of(
      context,
    ).uri.toString().startsWith(route);

    return ListTile(
      leading: Icon(icon, color: isSelected ? Colors.blueAccent : iconColor),
      title: Text(
        title,
        style: TextStyle(
          color: isSelected ? Colors.blueAccent : textColor,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      onTap: () {
        context.go(route);
        // 如果是手機版 Drawer，點擊後要關閉
        if (Scaffold.of(context).hasDrawer &&
            Scaffold.of(context).isDrawerOpen) {
          Navigator.pop(context);
        }
      },
    );
  }
}
