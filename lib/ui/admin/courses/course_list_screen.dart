import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:ttmastiff/main.dart'; // 取得 adminRepository
import 'widgets/course_edit_dialog.dart';

// 🔥 引入 CourseModel
import '../../../../data/models/course_model.dart';

class CourseListScreen extends StatefulWidget {
  const CourseListScreen({super.key});

  @override
  State<CourseListScreen> createState() => _CourseListScreenState();
}

class _CourseListScreenState extends State<CourseListScreen> {
  // 🔥 改動 1: 使用 List<CourseModel>
  List<CourseModel> _courses = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchCourses();
  }

  Future<void> _fetchCourses() async {
    try {
      // Repository 現在回傳 List<CourseModel>
      final data = await adminRepository.getCourses();
      if (mounted) {
        setState(() {
          _courses = data;
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
  Future<void> _deleteCourse(String courseId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('刪除課程'),
        content: const Text('確定要刪除此課程模板嗎？相關的歷史場次可能會失去關聯。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('刪除'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await adminRepository.deleteCourse(courseId); // 需在 repo 實作
        _fetchCourses();
      } catch (e) {
        if (mounted)
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('刪除失敗: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('課程管理 (模板)')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCourseDialog(),
        icon: const Icon(Icons.add),
        label: const Text('新增課程'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _courses.isEmpty
          ? const Center(child: Text('尚無課程模板，請點擊新增'))
          : RefreshIndicator(
              onRefresh: _fetchCourses, // 加入下拉刷新功能
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _courses.length,
                itemBuilder: (context, index) {
                  final course = _courses[index];

                  // 🔥 改動 3: 直接使用 Model 屬性 (已經是 DateTime，不需要 parse)
                  final startTime = course.defaultStartTime;
                  final endTime = course.defaultEndTime;
                  final timeFormat = DateFormat('HH:mm');

                  return Card(
                    elevation: 2,
                    margin: const EdgeInsets.only(bottom: 12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {
                        // 跳轉到詳情頁 (Session 管理)
                        context.go(
                          '/admin/courses/${course.id}',
                          extra: course, // 傳遞 Model 物件
                        );
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
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
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
                                              ? Colors.orange.shade100
                                              : Colors.blue.shade100,
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                        child: Text(
                                          course.category == 'group'
                                              ? '團體課'
                                              : '個人課',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: course.category == 'group'
                                                ? Colors.orange.shade900
                                                : Colors.blue.shade900,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        '\$${course.price}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '預設時段: ${timeFormat.format(startTime)} - ${timeFormat.format(endTime)}',
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              children: [
                                IconButton(
                                  icon: const Icon(
                                    Icons.edit_outlined,
                                    color: Colors.blue,
                                  ),
                                  onPressed: () => _showCourseDialog(course),
                                ),
                                // 這裡也可以加刪除按鈕
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    color: Colors.grey,
                                  ),
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
            ),
    );
  }
}
