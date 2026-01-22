import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // 活動通知
  final List<Map<String, dynamic>> _activityNotifications = [
    {
      'id': '1',
      'title': '春季網球訓練營開始報名',
      'description': '歡迎參加我們的春季網球訓練營，提升您的網球技巧！',
      'dateTime': DateTime(2024, 3, 1, 10, 30),
    },
    {
      'id': '2',
      'title': '週末友誼賽即將開始',
      'description': '本週末將舉辦友誼賽，歡迎所有會員報名參加。',
      'dateTime': DateTime(2024, 3, 5, 14, 0),
    },
  ];

  // 個人通知
  final List<Map<String, dynamic>> _personalNotifications = [
    {
      'id': '3',
      'title': '您的課程預約已確認',
      'description': '您預約的課程已成功確認，請準時參加。',
      'dateTime': DateTime(2024, 3, 2, 9, 0),
    },
    {
      'id': '4',
      'title': '點數即將到期提醒',
      'description': '您的點數將於下個月到期，請盡快使用。',
      'dateTime': DateTime(2024, 3, 3, 15, 30),
    },
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '通知',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Theme.of(context).colorScheme.primary,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Theme.of(context).colorScheme.primary,
          tabs: const [
            Tab(text: '活動通知'),
            Tab(text: '個人通知'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildNotificationList(_activityNotifications),
          _buildNotificationList(_personalNotifications),
        ],
      ),
    );
  }

  Widget _buildNotificationList(List<Map<String, dynamic>> notifications) {
    if (notifications.isEmpty) {
      return Center(
        child: Text(
          '暫無通知',
          style: TextStyle(color: Colors.grey.shade600),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: notifications.length,
      separatorBuilder: (context, index) => Divider(
        color: Colors.grey.shade300,
        height: 1,
      ),
      itemBuilder: (context, index) {
        final notification = notifications[index];
        return _buildNotificationItem(notification);
      },
    );
  }

  Widget _buildNotificationItem(Map<String, dynamic> notification) {
    final dateFormat = DateFormat('yyyy/MM/dd HH:mm');
    
    return InkWell(
      onTap: () {
        context.push('/notifications/${notification['id']}');
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notification['title'] as String,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    notification['description'] as String,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade700,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    dateFormat.format(notification['dateTime'] as DateTime),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.chevron_right,
              color: Colors.grey.shade400,
            ),
          ],
        ),
      ),
    );
  }
}
