import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart'; // 記得引入 intl 用於時間格式化
import 'package:go_router/go_router.dart';

// Repositories & Models
import '../../data/services/course_repository.dart';
import '../../data/models/course_model.dart';
import 'widgets/level_icon.dart';

class CoursesScreen extends StatefulWidget {
  const CoursesScreen({super.key});

  @override
  State<CoursesScreen> createState() => _CoursesScreenState();
}

class _CoursesScreenState extends State<CoursesScreen> {
  late final CourseRepository _courseRepo;

  // 狀態變數
  int _selectedDayIndex = 0; // 0=週一, 1=週二 ... 6=週日
  List<CourseModel> _courses = [];
  bool _isLoading = true;
  String? _errorMsg;

  // 會員等級 (beginner / intermediate / advanced)
  String? _memberLevel;

  // 定義星期的標籤
  final List<String> _weekDays = ['一', '二', '三', '四', '五', '六', '日'];

  @override
  void initState() {
    super.initState();
    _courseRepo = CourseRepository(Supabase.instance.client);
    CourseRepository.courseRefreshSignal.addListener(_fetchCourses);
    // 初始化時，自動選擇「今天」是星期幾
    // DateTime.weekday 回傳 1(Mon)~7(Sun)，我們轉成 0~6 的 index
    _selectedDayIndex = DateTime.now().weekday - 1;

    _fetchCourses();
    _loadMemberLevel();
  }

  Future<void> _loadMemberLevel() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      final data = await Supabase.instance.client
          .from('profiles')
          .select('membership')
          .eq('id', user.id)
          .single();

      if (!mounted) return;
      setState(() {
        _memberLevel = (data['membership'] as String?) ?? 'beginner';
      });
    } catch (e) {
      // 會員等級載入失敗時，不影響課程顯示，只是不套用折扣
      debugPrint('載入會員等級失敗: $e');
    }
  }

  // 根據目前選中的星期，重新撈取資料
  Future<void> _fetchCourses() async {
    if (!mounted) return;
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
        title: const Text(
          '課程總覽',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Divider(
          height: 1,
          thickness: 1,
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
        ),
      ),
      body: Column(
        children: [
          // 1. 星期選擇器
          Container(
            color: Colors.grey.shade50,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
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
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Theme.of(context).primaryColor
                              : Colors.transparent,
                          shape: BoxShape.circle,
                          border: isSelected
                              ? null
                              : Border.all(
                                  color: isToday
                                      ? Theme.of(context).primaryColor
                                      : Colors.grey.shade300,
                                  width: isToday ? 2 : 1,
                                ),
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
                      const SizedBox(height: 4),
                      // 標示今日的小點 (選擇性)
                      if (isToday)
                        Container(
                          width: 4,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Theme.of(context).primaryColor,
                            shape: BoxShape.circle,
                          ),
                        )
                      else
                        const SizedBox(height: 4),
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
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 48, color: Colors.red.shade300),
              const SizedBox(height: 16),
              Text(
                "讀取失敗",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _errorMsg!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _fetchCourses,
                icon: const Icon(Icons.refresh),
                label: const Text("重試"),
              ),
            ],
          ),
        ),
      );
    }

    if (_courses.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.calendar_today_outlined,
                size: 48,
                color: Colors.grey.shade400,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              "週${_weekDays[_selectedDayIndex]} 沒有安排課程",
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    // 顯示課程卡片列表
    return RefreshIndicator(
      onRefresh: _fetchCourses,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _courses.length,
        separatorBuilder: (ctx, index) => const SizedBox(height: 16),
        itemBuilder: (context, index) {
          final course = _courses[index];
          return _CourseCard(
            course: course,
            memberLevel: _memberLevel,
          );
        },
      ),
    );
  }
}

// =========================================================
// 優化後的卡片 Widget
// =========================================================
class _CourseCard extends StatelessWidget {
  final CourseModel course;
  final String? memberLevel;

  const _CourseCard({
    required this.course,
    required this.memberLevel,
  });

  @override
  Widget build(BuildContext context) {
    // 時間格式化 (例如: 10:00 - 11:30)
    final timeFormat = DateFormat('HH:mm');
    final timeRange =
        "${timeFormat.format(course.defaultStartTime)} - ${timeFormat.format(course.defaultEndTime)}";

    return Card(
      elevation: 0, // 平面化設計
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200), // 細邊框
      ),
      color: Colors.white,
      clipBehavior: Clip.antiAlias, // 讓圖片切圓角
      child: InkWell(
        onTap: () {
          // 點擊後跳轉到「課程詳情頁」
          context.push('/home/course_detail/${course.id}');
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // A. 圖片區塊 (如果有圖)
            if (course.imageUrl != null && course.imageUrl!.isNotEmpty)
              SizedBox(
                height: 140,
                width: double.infinity,
                child: Image.network(
                  course.imageUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    color: Colors.grey.shade100,
                    child: const Center(
                      child: Icon(Icons.broken_image, color: Colors.grey),
                    ),
                  ),
                ),
              ),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // B. 標籤與價格
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 類型標籤
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: course.category == 'personal'
                              ? Colors.purple.shade50
                              : Color.fromARGB(30, 255, 122, 50),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          course.category == 'personal' ? '一對一' : '團體班',
                          style: TextStyle(
                            fontSize: 12,
                            color: course.category == 'personal'
                                ? Colors.purple
                                : Colors.orange,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const Spacer(),
                      // 價格（根據會員等級套用折扣）
                      _buildPriceWithDiscount(context),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // C. 課程標題
                  Text(
                    course.title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      height: 1.2,
                    ),
                  ),

                  const SizedBox(height: 6),

                  // D. 課程說明 (簡短)
                  if (course.description != null)
                    Text(
                      course.description!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 13,
                      ),
                    ),

                  const SizedBox(height: 16),

                  // 分隔線
                  Divider(height: 1, color: Colors.grey.shade100),
                  const SizedBox(height: 12),

                  // E. 底部資訊 (時間 & 查看按鈕)
                  Row(
                    children: [
                      Icon(
                        Icons.access_time_filled_rounded,
                        size: 16,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        timeRange,
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        "預約",
                        style: TextStyle(
                          color: Theme.of(context).primaryColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.arrow_forward_rounded,
                        size: 16,
                        color: Theme.of(context).primaryColor,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 根據會員等級計算折扣後的價格，並顯示折扣標籤
  Widget _buildPriceWithDiscount(BuildContext context) {
    final basePrice = course.price;
    final finalPrice = getDiscountedPrice(basePrice, memberLevel);
    final discountLabel = getDiscountLabel(memberLevel);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          '\$${finalPrice}',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: Theme.of(context).primaryColor,
          ),
        ),
        if (discountLabel != null)
          Text(
            discountLabel,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade600,
            ),
          ),
      ],
    );
  }
}
