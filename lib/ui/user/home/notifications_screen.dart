import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../data/services/activity_repository.dart';
import '../../../data/models/activity_model.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _activityRepository = ActivityRepository(Supabase.instance.client);

  // 活動通知
  List<ActivityModel> _activityNotifications = [];
  bool _isLoadingActivities = true;

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
    _loadActivityNotifications();
  }

  Future<void> _loadActivityNotifications() async {
    try {
      final activities = await _activityRepository.getActivityNotifications();
      
      // 由新到舊排序（依開始時間）
      activities.sort((a, b) => b.startTime.compareTo(a.startTime));

      if (mounted) {
        setState(() {
          _activityNotifications = activities;
          _isLoadingActivities = false;
        });
      }
    } catch (e) {
      debugPrint('載入活動通知失敗: $e');
      if (mounted) {
        setState(() => _isLoadingActivities = false);
      }
    }
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
          _buildActivityNotificationList(),
          _buildNotificationList(_personalNotifications),
        ],
      ),
    );
  }

  Widget _buildActivityNotificationList() {
    if (_isLoadingActivities) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_activityNotifications.isEmpty) {
      return Center(
        child: Text(
          '暫無活動通知',
          style: TextStyle(color: Colors.grey.shade600),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _activityNotifications.length,
      separatorBuilder: (context, index) => Divider(
        color: Colors.grey.shade300,
        height: 1,
      ),
      itemBuilder: (context, index) {
        final activity = _activityNotifications[index];
        return _buildActivityNotificationItem(activity);
      },
    );
  }

  Widget _buildActivityNotificationItem(ActivityModel activity) {
    final isUnread = activity.notificationStatus == 'unread';
    final dateFormat = DateFormat('yyyy/MM/dd HH:mm');
    
    return InkWell(
      onTap: () async {
        // 標記為已讀
        if (isUnread) {
          await _activityRepository.markActivityAsRead(activity.id);
          // 更新本地狀態
          setState(() {
            final index = _activityNotifications.indexWhere((a) => a.id == activity.id);
            if (index != -1) {
              _activityNotifications[index] = activity.copyWith(
                notificationStatus: 'read',
              );
            }
          });
          // 通知首頁更新未讀數量（通過重新取得未讀數量）
          // 這裡可以觸發一個事件或使用 callback，但最簡單的方式是讓首頁在返回時重新載入
        }
        context.push('/activity/${activity.id}');
      },
      child: Container(
        color: isUnread ? Colors.grey.shade100 : Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      activity.title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: isUnread ? FontWeight.w700 : FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      activity.description,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      dateFormat.format(activity.startTime),
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
