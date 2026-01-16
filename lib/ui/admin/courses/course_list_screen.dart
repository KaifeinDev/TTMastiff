import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:ttmastiff/main.dart'; // 取得 adminRepository
import 'widgets/course_edit_dialog.dart';

// 🔥 引入 CourseModel
import '../../../../data/models/course_model.dart';

class CourseListScreen extends StatefulWidget {
  const CourseListScreen({super.key});

  @override
  State<CourseListScreen> createState() => _CourseListScreenState();
}

class _CourseListScreenState extends State<CourseListScreen>
    with SingleTickerProviderStateMixin {
  // 🔥 改動 1: 使用 List<CourseModel>
  List<CourseModel> _publishedCourses = []; // 上架中
  List<CourseModel> _archivedCourses = []; // 已封存

  bool _isLoading = true;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchCourses();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchCourses() async {
    try {
      // Repository 現在回傳 List<CourseModel>
      final data = await courseRepository.getCourses();
      if (mounted) {
        setState(() {
          _publishedCourses = data.where((c) => c.isPublished).toList();
          _archivedCourses = data.where((c) => !c.isPublished).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('載入失敗: $e')));
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _togglePublishStatus(CourseModel course) async {
    final isCurrentlyPublished = course.isPublished;
    final actionName = isCurrentlyPublished ? '封存' : '重新上架';

    // 簡單確認
    // 如果覺得封存不需要確認，可以把這段註解掉直接執行
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('確認$actionName？'),
        content: Text(
          isCurrentlyPublished
              ? '封存後，學生端將無法看到此課程，但歷史資料會保留。'
              : '重新上架後，學生端將可再次看到此課程。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              '確認',
              style: TextStyle(color: Theme.of(context).primaryColor),
            ),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    // 顯示 Loading (或是樂觀更新 UI)
    setState(() => _isLoading = true);

    try {
      await courseRepository.toggleCoursePublishStatus(
        course.id,
        isCurrentlyPublished,
      );

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('課程已$actionName')));
        await _fetchCourses(); // 刷新列表
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('操作失敗: $e')));
        setState(() => _isLoading = false);
      }
    }
  }

  // 🔥 改動 2: 參數型別改為 CourseModel?
  Future<void> _showCourseDialog([CourseModel? course]) async {
    final result = await showDialog(
      context: context,
      builder: (context) => CourseEditDialog(course: course),
    );

    if (result == true) {
      _fetchCourses(); // 刷新列表
    }
  }

  // 刪除課程 (選擇性功能，若需要可加上)
  // 刪除課程 (前端邏輯 - 嚴格規範版)
  Future<void> _deleteCourse(String courseId) async {
    // 1. 第一道防線：刪除確認對話框
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('⚠️ 確認刪除課程？'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('您即將刪除此課程模板。'),
            SizedBox(height: 12),
            Text(
              '這將會導致：\n'
              '1. 所有「已結束」的歷史場次資料將被連帶清除。\n'
              '2. 歷史交易紀錄會被保留 (但失去課程連結)。',
              style: TextStyle(fontSize: 13, color: Colors.black87),
            ),
            SizedBox(height: 12),
            Text(
              '若尚有「未結束」的未來場次，系統將會阻止刪除。',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('確認刪除'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      // 呼叫後端 Repo 進行刪除 (這裡會觸發我們剛寫的防護檢查)
      await courseRepository.deleteCourse(courseId);

      // 成功處理
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('課程已成功刪除'),
            backgroundColor: Colors.green,
          ),
        );

        // 刷新列表
        await _fetchCourses();
      }
    } catch (e) {
      // 失敗 (使用 Dialog 顯示詳細錯誤)
      if (mounted) {
        // 處理錯誤訊息字串 (去掉 "Exception: " 字頭讓畫面好看點)
        final String errorMessage = e.toString().replaceAll('Exception: ', '');

        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.error_outline, color: Colors.red.shade700),
                const SizedBox(width: 8),
                const Text('無法刪除'),
              ],
            ),
            // 這裡顯示 Repository 拋出的詳細指導文字
            content: Text(
              errorMessage,
              style: const TextStyle(fontSize: 15, height: 1.5),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('我了解了'), // 引導使用者去處理場次
              ),
            ],
          ),
        );
      }
    } finally {
      // 不管成功或失敗，都要解除鎖定
      if (mounted) {
        setState(() {
          _isLoading = false; // 🔓 解除鎖定
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('課程管理 (模板)'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Theme.of(context).primaryColor,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Theme.of(context).primaryColor,
          tabs: const [
            Tab(text: '上架中'),
            Tab(text: '已封存'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCourseDialog(),
        icon: const Icon(Icons.add),
        label: const Text('新增課程'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                // 1. 上架中列表
                _buildCourseList(_publishedCourses, isArchived: false),
                // 2. 已封存列表
                _buildCourseList(_archivedCourses, isArchived: true),
              ],
            ),
    );
  }

  Widget _buildCourseList(
    List<CourseModel> courses, {
    required bool isArchived,
  }) {
    if (courses.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isArchived
                  ? Icons.inventory_2_outlined
                  : Icons.dashboard_outlined,
              size: 64,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              isArchived ? '沒有已封存的課程' : '目前沒有上架的課程',
              style: TextStyle(color: Colors.grey.shade500),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchCourses,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        // 為了讓 RefreshIndicator 在空內容時也能運作，建議把 itemCount 加 1 (padding) 或用 physics
        itemCount: courses.length + 1,
        itemBuilder: (context, index) {
          if (index == courses.length)
            return const SizedBox(height: 80); // 底部留白給 FAB

          final course = courses[index];

          // 若 CourseModel 有這些 getter
          // final startTime = course.defaultStartTime;
          // final endTime = course.defaultEndTime;
          // final timeFormat = DateFormat('HH:mm');

          return Card(
            elevation: 2,
            margin: const EdgeInsets.only(bottom: 12),
            color: isArchived ? Colors.grey.shade100 : Colors.white, // 封存的灰底
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {
                // 跳轉到詳情頁
                context.go('/admin/courses/${course.id}', extra: course);
              },
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            course.title,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: isArchived ? Colors.grey : Colors.black87,
                              decoration: isArchived
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: course.category == 'group'
                                      ? (isArchived
                                            ? Colors.grey.shade300
                                            : Colors.orange.shade100)
                                      : (isArchived
                                            ? Colors.grey.shade300
                                            : Colors.blue.shade100),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  course.category == 'group' ? '團體課' : '個人課',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isArchived
                                        ? Colors.grey.shade600
                                        : (course.category == 'group'
                                              ? Colors.orange.shade900
                                              : Colors.blue.shade900),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '\$${course.price}',
                                style: TextStyle(
                                  fontWeight: FontWeight.w500,
                                  color: isArchived
                                      ? Colors.grey
                                      : Colors.black,
                                ),
                              ),
                            ],
                          ),
                          // 如果 Model 裡有 defaultStartTime，可以打開下面這段
                          /*
                          const SizedBox(height: 4),
                          Text(
                            '預設時段: ${timeFormat.format(startTime)} - ${timeFormat.format(endTime)}',
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                          ),
                          */
                        ],
                      ),
                    ),
                    // 操作按鈕區
                    Column(
                      children: [
                        // 1. 編輯按鈕
                        IconButton(
                          icon: const Icon(
                            Icons.edit_outlined,
                            color: Colors.blue,
                          ),
                          tooltip: '編輯資訊',
                          onPressed: () => _showCourseDialog(course),
                        ),
                        // 2. 🔥 封存/上架按鈕
                        IconButton(
                          icon: Icon(
                            isArchived
                                ? Icons.unarchive_outlined
                                : Icons.inventory_2_outlined,
                            color: isArchived ? Colors.green : Colors.orange,
                          ),
                          tooltip: isArchived ? '重新上架' : '封存課程',
                          onPressed: () => _togglePublishStatus(course),
                        ),
                        // 3. 刪除按鈕 (可以只在封存頁顯示，或是都顯示)
                        if (isArchived) // 建議只在封存頁才顯示刪除，避免誤刪
                          IconButton(
                            icon: const Icon(
                              Icons.delete_outline,
                              color: Colors.grey,
                            ),
                            tooltip: '永久刪除 (僅限無紀錄課程)',
                            onPressed: () => _deleteCourse(course.id),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
