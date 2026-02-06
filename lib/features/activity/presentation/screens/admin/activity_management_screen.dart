import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:ttmastiff/core/utils/util.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb;
import '../../../data/models/activity_model.dart';
import '../../../data/repositories/activity_repository.dart';
import '../../../../../core/constants/activity_types.dart';
import '../../../../../core/constants/activity_status.dart';

import '../../widgets/activity_edit_dialog.dart';
import '../../widgets/dashed_card.dart';

class ActivityManagementScreen extends StatefulWidget {
  const ActivityManagementScreen({super.key});

  @override
  State<ActivityManagementScreen> createState() =>
      _ActivityManagementScreenState();
}

class _ActivityManagementScreenState extends State<ActivityManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _activityRepository = ActivityRepository(Supabase.instance.client);

  // 資料狀態
  List<ActivityModel> _carouselActive = [];
  List<ActivityModel> _carouselInactive = [];
  List<ActivityModel> _recentActive = [];
  List<ActivityModel> _recentInactive = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadActivities();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadActivities() async {
    setState(() => _isLoading = true);
    try {
      final carousel = await _activityRepository.getActivities(
        type: ActivityTypes.carousel,
      );
      final recent = await _activityRepository.getActivities(
        type: ActivityTypes.recent,
      );

      if (mounted) {
        setState(() {
          _carouselActive = carousel
              .where((a) => a.status == ActivityStatus.active)
              .toList();
          _carouselInactive = carousel
              .where((a) => a.status == ActivityStatus.inactive)
              .toList();
          _recentActive = recent
              .where((a) => a.status == ActivityStatus.active)
              .toList();
          _recentInactive = recent
              .where((a) => a.status == ActivityStatus.inactive)
              .toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      logError(e);
    }
  }

  bool get _isMobile {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.android;
  }

  Widget _buildImageFromBase64(String? base64Image, {double? height}) {
    if (base64Image == null || base64Image.isEmpty) {
      return Container(
        height: height ?? 100,
        color: Colors.grey.shade200,
        child: const Center(
          child: Icon(Icons.image, size: 32, color: Colors.grey),
        ),
      );
    }

    try {
      final imageBytes = base64Decode(base64Image);
      return Image.memory(imageBytes, height: height ?? 100, fit: BoxFit.cover);
    } catch (e) {
      logError(e);
      return Container(
        height: height ?? 100,
        color: Colors.grey.shade200,
        child: const Center(
          child: Icon(Icons.broken_image, size: 32, color: Colors.grey),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('活動管理'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '上架中'),
            Tab(text: '已下架'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [_buildActiveTab(), _buildInactiveTab()],
            ),
    );
  }

  Widget _buildActiveTab() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 輪播區塊
          _buildSection(
            title: '輪播',
            activities: _carouselActive,
            type: ActivityTypes.carousel,
            isActive: true,
          ),
          const Divider(height: 1),
          // 近期活動區塊
          _buildSection(
            title: '近期活動',
            activities: _recentActive,
            type: ActivityTypes.recent,
            isActive: true,
          ),
        ],
      ),
    );
  }

  Widget _buildInactiveTab() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 輪播區塊
          _buildSection(
            title: '輪播',
            activities: _carouselInactive,
            type: ActivityTypes.carousel,
            isActive: false,
          ),
          const Divider(height: 1),
          // 近期活動區塊
          _buildSection(
            title: '近期活動',
            activities: _recentInactive,
            type: ActivityTypes.recent,
            isActive: false,
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required List<ActivityModel> activities,
    required String type,
    required bool isActive,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        if (isActive) ...[
          if (activities.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Text(
                '暫無活動',
                style: TextStyle(color: Colors.grey.shade600),
              ),
            )
          else
            _buildReorderableList(activities, type),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
            child: DashedCard(
              radius: 12,
              borderColor: Theme.of(context).colorScheme.outlineVariant,
              onTap: () => _openCreateDialog(type),
              child: SizedBox(
                width: double.infinity,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.add_circle_outline,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '新增活動',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ] else ...[
          if (activities.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Center(
                child: Text(
                  '暫無活動',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ),
            )
          else
            _buildInactiveList(activities, type),
        ],
      ],
    );
  }

  Widget _buildReorderableList(List<ActivityModel> activities, String type) {
    return ReorderableListView.builder(
      buildDefaultDragHandles: false,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: activities.length,
      onReorder: (oldIndex, newIndex) {
        if (newIndex > oldIndex) {
          newIndex -= 1;
        }
        setState(() {
          final item = activities.removeAt(oldIndex);
          activities.insert(newIndex, item);
        });
        _updateOrder(activities, type);
      },
      itemBuilder: (context, index) {
        final activity = activities[index];
        return _buildActivityItem(activity, type, true, index: index);
      },
    );
  }

  Widget _buildInactiveList(List<ActivityModel> activities, String type) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: activities.length,
      itemBuilder: (context, index) {
        final activity = activities[index];
        return _buildActivityItem(activity, type, false);
      },
    );
  }

  Widget _buildActivityItem(
    ActivityModel activity,
    String type,
    bool isActive, {
    int? index,
  }) {
    final dateFormat = DateFormat('yyyy/MM/dd HH:mm');
    final tile = Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isActive ? Colors.white : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isActive ? Colors.grey.shade300 : Colors.grey.shade400,
        ),
      ),
      child: ListTile(
        leading: SizedBox(
          width: 80,
          height: 80,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: _buildImageFromBase64(activity.image, height: 80),
          ),
        ),
        title: Text(
          activity.title,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: isActive ? null : Colors.grey.shade600,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              '${dateFormat.format(activity.startTime)} ~ ${dateFormat.format(activity.endTime)}',
              style: TextStyle(
                fontSize: 12,
                color: isActive ? Colors.grey.shade600 : Colors.grey.shade500,
              ),
            ),
          ],
        ),
        trailing: _buildTrailing(
          activity: activity,
          type: type,
          isActive: isActive,
          index: index,
        ),
      ),
    );

    // key 必須在最外層 widget 上
    if (isActive && index != null && _isMobile) {
      // 手機：長按拖拉
      return ReorderableDelayedDragStartListener(
        key: ValueKey(activity.id),
        index: index,
        child: tile,
      );
    }
    if (isActive && index != null) {
      // 網頁/桌面：拖拉 icon 觸發（不靠預設 handle，避免溢出）
      return ReorderableDragStartListener(
        key: ValueKey(activity.id),
        index: index,
        child: tile,
      );
    }
    // 非可排序項目也需要 key
    return Container(key: ValueKey(activity.id), child: tile);
  }

  Widget _buildTrailing({
    required ActivityModel activity,
    required String type,
    required bool isActive,
    int? index,
  }) {
    if (_isMobile) {
      return IconButton(
        icon: const Icon(Icons.more_vert),
        onPressed: () => _openMobileActions(
          activity: activity,
          type: type,
          isActive: isActive,
        ),
        tooltip: '操作',
      );
    }

    // 網頁/桌面：水平排列（鉛筆 + 三點 + 拖拉），避免突出卡片
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.edit, size: 18),
          onPressed: () => _openEditDialog(activity),
          tooltip: '編輯',
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
        ),
        PopupMenuButton<String>(
          onSelected: (value) {
            if (isActive) {
              if (value == 'deactivate') _deactivateActivity(activity);
              if (value == 'switch') _switchActivityType(activity, type);
            } else {
              if (value == 'activate') _activateActivity(activity);
              if (value == 'delete') _deleteActivity(activity);
            }
          },
          itemBuilder: (context) => isActive
              ? [
                  const PopupMenuItem(value: 'deactivate', child: Text('下架')),
                  PopupMenuItem(
                    value: 'switch',
                    child: Text(
                      type == ActivityTypes.carousel ? '改到近期活動' : '改到輪播',
                    ),
                  ),
                ]
              : const [
                  PopupMenuItem(value: 'activate', child: Text('重新上架')),
                  PopupMenuItem(value: 'delete', child: Text('刪除')),
                ],
          icon: const Icon(Icons.more_horiz),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
        ),
        if (isActive && index != null) ...[
          const SizedBox(width: 2),
          Icon(Icons.drag_handle, size: 20, color: Colors.grey.shade500),
        ],
      ],
    );
  }

  Future<void> _openMobileActions({
    required ActivityModel activity,
    required String type,
    required bool isActive,
  }) async {
    await showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('編輯'),
              onTap: () {
                Navigator.pop(ctx);
                _openEditDialog(activity);
              },
            ),
            if (isActive) ...[
              ListTile(
                leading: const Icon(Icons.arrow_downward),
                title: const Text('下架'),
                onTap: () {
                  Navigator.pop(ctx);
                  _deactivateActivity(activity);
                },
              ),
              ListTile(
                leading: const Icon(Icons.swap_horiz),
                title: Text(type == ActivityTypes.carousel ? '改到近期活動' : '改到輪播'),
                onTap: () {
                  Navigator.pop(ctx);
                  _switchActivityType(activity, type);
                },
              ),
            ] else ...[
              ListTile(
                leading: const Icon(Icons.arrow_upward),
                title: const Text('重新上架'),
                onTap: () {
                  Navigator.pop(ctx);
                  _activateActivity(activity);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('刪除', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(ctx);
                  _deleteActivity(activity);
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _updateOrder(List<ActivityModel> activities, String type) async {
    try {
      await _activityRepository.updateActivitiesOrder(activities);
      await _loadActivities();
    } catch (e) {
      logError(e);
    }
  }

  Future<void> _deactivateActivity(ActivityModel activity) async {
    try {
      await _activityRepository.updateActivityStatus(activity.id, 'inactive');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('活動已下架')));
        await _loadActivities();
      }
    } catch (e) {
      logError(e);
    }
  }

  Future<void> _activateActivity(ActivityModel activity) async {
    try {
      await _activityRepository.updateActivityStatus(
        activity.id,
        ActivityStatus.active,
      );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('活動已重新上架')));
        await _loadActivities();
      }
    } catch (e) {
      logError(e);
    }
  }

  Future<void> _switchActivityType(
    ActivityModel activity,
    String currentType,
  ) async {
    try {
      final newType = currentType == ActivityTypes.carousel
          ? ActivityTypes.recent
          : ActivityTypes.carousel;
      await _activityRepository.updateActivityType(activity.id, newType);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('活動區域已變更')));
        await _loadActivities();
      }
    } catch (e) {
      logError(e);
    }
  }

  Future<void> _deleteActivity(ActivityModel activity) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('確認刪除'),
        content: Text('確定要刪除「${activity.title}」嗎？此操作無法復原。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('刪除'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _activityRepository.deleteActivity(activity.id);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('活動已刪除')));
        await _loadActivities();
      }
    } catch (e) {
      logError(e);
    }
  }

  Future<void> _openCreateDialog(String type) async {
    await ActivityEditDialog.show(
      context,
      titleText: '新增${type == ActivityTypes.carousel ? '輪播' : '近期活動'}',
      fixedType: type,
      onSubmit:
          ({
            required String title,
            required String description,
            required DateTime startTime,
            required DateTime endTime,
            required String? base64Image,
            required String type,
          }) async {
            await _activityRepository.createActivity(
              title: title,
              description: description,
              startTime: startTime,
              endTime: endTime,
              image: base64Image,
              type: type,
              status: ActivityStatus.active,
            );
            if (!mounted) return;
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('活動已新增')));
            await _loadActivities();
          },
    );
  }

  Future<void> _openEditDialog(ActivityModel activity) async {
    await ActivityEditDialog.show(
      context,
      titleText: '編輯活動',
      fixedType: activity.type,
      initial: activity,
      allowTypeChange: true,
      onSubmit:
          ({
            required String title,
            required String description,
            required DateTime startTime,
            required DateTime endTime,
            required String? base64Image,
            required String type,
          }) async {
            // 如果沒有上傳新圖片，保留原來的圖片
            final imageToUse = base64Image ?? activity.image;
            final updated = activity.copyWith(
              title: title,
              description: description,
              startTime: startTime,
              endTime: endTime,
              image: imageToUse,
              type: type,
            );
            await _activityRepository.updateActivity(updated);
            if (!mounted) return;
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('活動已更新')));
            await _loadActivities();
          },
    );
  }
}
