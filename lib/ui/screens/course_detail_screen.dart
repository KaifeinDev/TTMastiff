import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/models/course_model.dart';
import '../../data/services/course_repository.dart';

class CourseDetailScreen extends StatefulWidget {
  final String courseId;

  const CourseDetailScreen({super.key, required this.courseId});

  @override
  State<CourseDetailScreen> createState() => _CourseDetailScreenState();
}

class _CourseDetailScreenState extends State<CourseDetailScreen> {
  // 1. Repository 初始化
  final _repository = CourseRepository(Supabase.instance.client);
  
  // 2. Future 變數
  late Future<Course?> _courseFuture;

  // ✅✅✅ 修正重點：變數必須宣告在這裡 (類別層級)，不能在 build 裡面，也不能漏掉
  bool _isBooking = false; 

  @override
  void initState() {
    super.initState();
    _courseFuture = _repository.getCourseById(widget.courseId);
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
                Text("時間: ${course.startTime}"),
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
                    // 這裡就能正確讀取到 _isBooking 了
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
                        await _repository.bookCourse(
                          courseId: widget.courseId,
                          userId: user.id,
                          maxCapacity: course.maxCapacity,
                        );

                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('✅ 報名成功！')),
                          );
                          setState(() {
                            _courseFuture = _repository.getCourseById(widget.courseId);
                          });
                        }
                      } catch (e) {
                        if (context.mounted) {
                          final errorMessage = e.toString().replaceAll('Exception: ', '');
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('❌ 報名失敗: $errorMessage'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      } finally {
                        if (mounted) {
                          setState(() {
                            _isBooking = false;
                          });
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
