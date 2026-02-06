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

    // 為後台設置局部主題，讓 DropdownMenuItem 背景為白色
    return Theme(
      data: Theme.of(context).copyWith(
        menuTheme: MenuThemeData(
          style: MenuStyle(
            backgroundColor: WidgetStateProperty.all(Colors.white),
          ),
        ),
        colorScheme: Theme.of(context).colorScheme.copyWith(
          surface: Colors.white,
          surfaceContainerHighest: Colors.white,
          surfaceContainerHigh: Colors.white,
          surfaceContainer: Colors.white,
          surfaceContainerLow: Colors.white,
          surfaceContainerLowest: Colors.white,
          surfaceTint: Colors.transparent,
        ),
      ),
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'TTMastiff 球館管理系統',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
          ),
          backgroundColor: Theme.of(
            context,
          ).colorScheme.secondary.withValues(alpha: 0.8),
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.white),
          actions: [
            IconButton(
              icon: const Icon(Icons.home),
              tooltip: '回前台 App',
              color: Colors.white,
              onPressed: () => context.go('/home'),
            ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Divider(
              height: 1,
              thickness: 1,
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
        ),
        drawer: isDesktop
            ? null
            : Drawer(
                backgroundColor: Theme.of(context).colorScheme.surface,
                child: _buildSidebar(context),
              ),
        body: Row(
          children: [
            if (isDesktop)
              Container(
                width: 260,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  border: Border(
                    right: BorderSide(
                      color: Theme.of(context).colorScheme.outlineVariant,
                      width: 1,
                    ),
                  ),
                ),
                child: _buildSidebar(context, isDark: false),
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
        _AdminMenuItem(
          icon: Icons.receipt_long,
          title: '帳務管理',
          route: '/admin/transactions',
          textColor: textColor,
          iconColor: iconColor,
        ),
        _AdminMenuItem(
          icon: Icons.table_restaurant,
          title: '桌次管理',
          route: '/admin/tables',
          textColor: textColor,
          iconColor: iconColor,
        ),
        _AdminMenuItem(
          icon: Icons.payments, // 或是用 Icons.monetization_on 也可以
          title: '薪資管理',
          route: '/admin/salaries',
          textColor: textColor,
          iconColor: iconColor,
        ),
        _AdminMenuItem(
          icon: Icons.manage_accounts, // 或 Icons.people_alt
          title: '人員管理',
          route: '/admin/staff_list', // 連到列表頁
          textColor: textColor,
          iconColor: iconColor,
        ),
        _AdminMenuItem(
          icon: Icons.analytics_outlined, // 或 Icons.insert_chart
          title: '薪資分析',
          route: '/admin/salary_analytics',
          textColor: textColor,
          iconColor: iconColor,
        ),
        _AdminMenuItem(
          icon: Icons.event,
          title: '活動管理',
          route: '/admin/activities',
          textColor: textColor,
          iconColor: iconColor,
        ),
        _AdminMenuItem(
          icon: Icons.calendar_view_week_rounded, // 或 Icons.grid_on_rounded
          title: '教練排班', // 或 '排班矩陣'
          route: '/admin/coach_matrix', // 記得在 routes 中註冊此路徑
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
      leading: Icon(
        icon,
        color: isSelected ? Theme.of(context).colorScheme.primary : iconColor,
      ),
      title: Text(
        title,
        style: TextStyle(
          color: isSelected ? Theme.of(context).colorScheme.primary : textColor,
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
