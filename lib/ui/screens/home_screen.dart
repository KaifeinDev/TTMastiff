import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Screens
import 'course_detail_screen.dart'; // 記得引入剛剛改好的 Detail Screen

// Repositories & Models
import '../../data/services/course_repository.dart';
import '../../data/models/course_model.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final CourseRepository _courseRepo;

  // 狀態變數
  int _selectedDayIndex = 0; // 0=週一, 1=週二 ... 6=週日
  List<CourseModel> _courses = [];
  bool _isLoading = true;
  String? _errorMsg;

  // 定義星期的標籤
  final List<String> _weekDays = ['一', '二', '三', '四', '五', '六', '日'];

  @override
  void initState() {
    super.initState();
    _courseRepo = CourseRepository(Supabase.instance.client);

    // 初始化時，自動選擇「今天」是星期幾
    // DateTime.weekday 回傳 1(Mon)~7(Sun)，我們轉成 0~6 的 index
    _selectedDayIndex = DateTime.now().weekday - 1;

    _fetchCourses();
  }

  // 根據目前選中的星期，重新撈取資料
  Future<void> _fetchCourses() async {
    setState(() {
      _isLoading = true;
      _errorMsg = null;
    });

    try {
      // API 需要 1~7，但 index 是 0~6，所以 +1
      final courses = await _courseRepo.fetchCoursesByWeekday(
        _selectedDayIndex + 1,
      );

      if (mounted) {
        setState(() {
          _courses = courses;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMsg = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  // 切換星期標籤
  void _onDaySelected(int index) {
    if (_selectedDayIndex == index) return;
    setState(() {
      _selectedDayIndex = index;
    });
    _fetchCourses();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('課程總覽'),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      backgroundColor: Colors.grey.shade100,
      body: Column(
        children: [
          // 1. 星期選擇器
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(_weekDays.length, (index) {
                final isSelected = _selectedDayIndex == index;
                final isToday = DateTime.now().weekday - 1 == index;

                return GestureDetector(
                  onTap: () => _onDaySelected(index),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 圓形按鈕
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 40, // 固定寬度確保塞得下
                        height: 40,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Theme.of(context).primaryColor
                              : (isToday
                                    ? Colors.blue.shade50
                                    : Colors.transparent),
                          shape: BoxShape.circle,
                          border: isSelected
                              ? null
                              : Border.all(color: Colors.grey.shade300),
                        ),
                        child: Center(
                          child: Text(
                            _weekDays[index],
                            style: TextStyle(
                              color: isSelected
                                  ? Colors.white
                                  : (isToday
                                        ? Theme.of(context).primaryColor
                                        : Colors.grey.shade600),
                              fontWeight: isSelected || isToday
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                      // const SizedBox(height: 4),
                      // Text(
                      //   "週${_weekDays[index]}",
                      //   style: TextStyle(fontSize: 10, color: isSelected ? Colors.black : Colors.grey),
                      // )
                    ],
                  ),
                );
              }),
            ),
          ),

          // 2. 課程列表內容
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMsg != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text(_errorMsg!),
            TextButton(onPressed: _fetchCourses, child: const Text("重試")),
          ],
        ),
      );
    }

    if (_courses.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.calendar_today_outlined,
              size: 64,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              "週${_weekDays[_selectedDayIndex]} 目前沒有安排課程",
              style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
            ),
          ],
        ),
      );
    }

    // 顯示課程卡片列表
    return RefreshIndicator(
      onRefresh: _fetchCourses,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _courses.length,
        itemBuilder: (context, index) {
          final course = _courses[index];
          return _CourseCard(course: course);
        },
      ),
    );
  }
}

// 抽離出來的卡片 Widget，讓程式碼比較乾淨
class _CourseCard extends StatelessWidget {
  final CourseModel course;

  const _CourseCard({required this.course});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          // 點擊後跳轉到「課程詳情頁 (CourseDetailScreen)」
          // 這裡傳入 courseId，支援批量報名
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CourseDetailScreen(courseId: course.id),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. 左側：類型標籤 (團體/個人)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: course.category == 'personal'
                          ? Colors.purple.shade50
                          : Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      course.category == 'personal' ? '一對一' : '團體班',
                      style: TextStyle(
                        fontSize: 12,
                        color: course.category == 'personal'
                            ? Colors.purple
                            : Colors.blue,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const Spacer(),
                  // 2. 右側：價格
                  Text(
                    '\$${course.price}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // 3. 課程標題
              Text(
                course.title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),

              // 4. 課程說明 (簡短版)
              if (course.description != null)
                Text(
                  course.description!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                ),

              const SizedBox(height: 16),

              // 5. 底部行動呼籲
              Row(
                children: [
                  Icon(
                    Icons.access_time,
                    size: 16,
                    color: Colors.grey.shade500,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    "${course.durationMinutes} 分鐘",
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                  const Spacer(),
                  const Text(
                    "查看時段",
                    style: TextStyle(
                      color: Colors.blue,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Icon(
                    Icons.arrow_forward_ios,
                    size: 14,
                    color: Colors.blue,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
