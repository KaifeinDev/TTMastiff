import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import '../../data/models/course_model.dart';
import '../../data/services/course_repository.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _repository = CourseRepository(Supabase.instance.client);
  
  List<Course> _courses = [];
  bool _isLoading = false;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _loadCourses(); // 初始化時載入
  }

  Future<void> _loadCourses() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });

    try {
      final courses = await _repository.getPublishedCourses();
      setState(() {
        _courses = courses;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('球館課程列表')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_isLoading) const CircularProgressIndicator(),
            if (_error.isNotEmpty) Text('錯誤: $_error', style: const TextStyle(color: Colors.red)),
            
            // 列表顯示
            Expanded(
              child: ListView.builder(
                itemCount: _courses.length,
                itemBuilder: (context, index) {
                  final course = _courses[index];
                  return ListTile(
                    title: Text(course.title),
                    subtitle: Text('${course.instructor} - \$${course.price}'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      // 使用 go_router 跳轉
                      context.go('/home/course/${course.id}');
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _loadCourses,
        child: const Icon(Icons.refresh),
      ),
    );
  }
}
