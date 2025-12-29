import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
// 記得確認這兩個路徑是否正確
import '../../data/models/course_model.dart';
import '../../data/services/course_repository.dart';
import '../../data/services/student_repository.dart'; // 👈 新增引入

class CourseDetailScreen extends StatefulWidget {
  final String courseId;

  const CourseDetailScreen({super.key, required this.courseId});

  @override
  State<CourseDetailScreen> createState() => _CourseDetailScreenState();
}

class _CourseDetailScreenState extends State<CourseDetailScreen> {
  // 1. Repository 初始化
  final _repository = CourseRepository(Supabase.instance.client);
  final _studentRepository = StudentRepository(Supabase.instance.client); // 👈 新增：學員儲存庫
  
  // 2. Future 變數
  late Future<Course?> _courseFuture;

  // 3. 狀態變數
  bool _isBooking = false; 

  @override
  void initState() {
    super.initState();
    _courseFuture = _repository.getCourseById(widget.courseId);
  }

  // ✨ 新增功能：執行實際的報名動作 (無論是自動帶入還是手選，最後都呼叫這個)
  Future<void> _performBooking(String studentId, String courseId, int maxCapacity) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      // 呼叫 Repository (注意：你的 bookCourse 必須已經更新為接收 studentId)
      await _repository.bookCourse(
        courseId: courseId,
        userId: user.id,
        studentId: studentId, 
        maxCapacity: maxCapacity,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ 報名成功！')),
        );
        setState(() {
          _courseFuture = _repository.getCourseById(widget.courseId);
          _isBooking = false; // 報名完成，解除 Loading
        });
      }
    } catch (e) {
      if (mounted) {
        final errorMessage = e.toString().replaceAll('Exception: ', '');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ 報名失敗: $errorMessage'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() {
          _isBooking = false; // 發生錯誤，解除 Loading
        });
      }
    }
  }

  // ✨ 新增功能：顯示選擇學員的底部彈窗
  void _showStudentSelection(List<StudentModel> students, int maxCapacity) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Text(
                '請問是誰要上課？',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              // 列出所有學員
              ...students.map((student) => ListTile(
                leading: CircleAvatar(
                  backgroundImage: NetworkImage(student.avatarUrl ?? ''),
                  child: student.avatarUrl == null ? Text(student.name[0]) : null,
                ),
                title: Text(student.name),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.pop(context); // 關閉彈窗
                  // 繼續執行報名
                  _performBooking(student.id, widget.courseId, maxCapacity);
                },
              )),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    ).whenComplete(() {
      // 如果使用者只是關掉視窗沒選人，要把 Loading 狀態改回來
      if (_isBooking && mounted) {
        setState(() => _isBooking = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('課程詳情')),
      body: FutureBuilder<Course?>(
        future: _courseFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || snapshot.data == null) {
            return const Center(child: Text('找不到課程或發生錯誤'));
          }

          final course = snapshot.data!;

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(course.title, style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 8),
                Chip(label: Text('教練: ${course.instructor}')),
                const SizedBox(height: 16),
                Text("時間: ${course.startTime}"), // 建議之後用 intl 套件格式化時間
                Text("地點: ${course.location}"),
                Text("費用: \$${course.price}", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                const Divider(height: 32),
                Text("課程說明", style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                Text(course.description),
                
                const Spacer(),
                
                // 報名按鈕
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _isBooking ? null : () async {
                      final user = Supabase.instance.client.auth.currentUser;
                      if (user == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('請先登入才能報名課程')),
                        );
                        return;
                      }

                      setState(() {
                        _isBooking = true;
                      });

                      try {
                        // 1. 先去抓取該帳號底下的所有學員
                        final students = await _studentRepository.getMyStudents();

                        if (students.isEmpty) {
                          throw Exception('帳號資料異常：找不到學員資料，請聯繫管理員');
                        }

                        if (students.length == 1) {
                          // ✅ 情境 A：只有一個學員 (單身或預設狀態) -> 直接報名，不囉嗦
                          await _performBooking(students.first.id, widget.courseId, course.maxCapacity);
                        } else {
                          // ✅ 情境 B：有多個學員 (家庭帳號) -> 跳出選單讓家長選
                          if (mounted) {
                            _showStudentSelection(students, course.maxCapacity);
                            // 注意：這裡不設 _isBooking = false，因為要在選完人之後才解除
                          }
                        }

                      } catch (e) {
                         if (mounted) {
                           ScaffoldMessenger.of(context).showSnackBar(
                             SnackBar(content: Text('❌ 錯誤: $e'), backgroundColor: Colors.red),
                           );
                           setState(() => _isBooking = false);
                         }
                      }
                    },
                    child: _isBooking 
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                        : const Text('立即報名'),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
