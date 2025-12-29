import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'data/models/course_model.dart';
import 'data/services/course_repository.dart';

// --- 1. Supabase 初始化設定 ---
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    // 1. 嘗試載入 .env
    await dotenv.load(fileName: ".env");
    print("✅ .env loaded successfully"); // 成功會印出這個

    await Supabase.initialize(
      url: dotenv.env['SUPABASE_URL']!,
      anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
    );
    print("✅ Supabase initialized successfully");
  }catch(e){
      print("❌ ERROR STARTING APP: $e");
  }

  runApp(const MyApp());
}

// --- 2. 路由設定 (導航地圖) ---
final _router = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const HomePage(),
    ),
  ],
);

// --- 3. App 入口 ---
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: '球館課程系統',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueAccent),
        useMaterial3: true,
      ),
      routerConfig: _router,
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // 初始化 Repository
  final _repository = CourseRepository(Supabase.instance.client);
  
  // 未來我們會用 FutureBuilder 來處理這個，現在先簡單測試
  List<Course> _courses = [];
  bool _isLoading = false;
  String _error = '';

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
      appBar: AppBar(title: const Text('課程列表 (測試)')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_isLoading) const CircularProgressIndicator(),
            if (_error.isNotEmpty) Text('錯誤: $_error', style: const TextStyle(color: Colors.red)),
            
            // 顯示抓到的課程數量
            Text('目前找到 ${_courses.length} 堂課'),
            
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _loadCourses,
              child: const Text('重新整理課程列表'),
            ),
            
            // 簡單列出課程標題 (如果有資料的話)
            Expanded(
              child: ListView.builder(
                itemCount: _courses.length,
                itemBuilder: (context, index) {
                  final course = _courses[index];
                  return ListTile(
                    title: Text(course.title),
                    subtitle: Text('${course.instructor} - \$${course.price}'),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
