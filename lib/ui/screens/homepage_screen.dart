import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/services/student_repository.dart';
import '../../data/models/student_model.dart';
import 'widgets/gender_icon.dart';

class HomepageScreen extends StatefulWidget {
  const HomepageScreen({super.key});

  @override
  State<HomepageScreen> createState() => _HomepageScreenState();
}

class _HomepageScreenState extends State<HomepageScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  Timer? _autoScrollTimer;
  
  final _studentRepository = StudentRepository(Supabase.instance.client);
  
  // 個人資訊狀態
  List<StudentModel> _students = [];
  StudentModel? _primaryStudent;
  String? _userEmail;
  String? _userPhone;
  bool _isLoadingUserInfo = true;

  // 輪播圖片列表
  final List<String> _displayImages = [
    'assets/images/display1.jpg',
    'assets/images/display2.jpg',
    'assets/images/display3.jpg',
  ];

  // 活動列表（使用 banner 圖片）
  final List<Map<String, dynamic>> _activities = [
    {
      'image': 'assets/images/banner2.jpg',
      'name': '春季網球訓練營',
      'startTime': DateTime(2024, 3, 1, 9, 0),
      'endTime': DateTime(2024, 3, 31, 18, 0),
    },
    {
      'image': 'assets/images/banner3.jpg',
      'name': '週末友誼賽',
      'startTime': DateTime(2024, 3, 15, 14, 0),
      'endTime': DateTime(2024, 3, 15, 17, 0),
    },
    {
      'image': 'assets/images/banner4.jpg',
      'name': '網球技巧提升班',
      'startTime': DateTime(2024, 3, 20, 10, 0),
      'endTime': DateTime(2024, 4, 20, 12, 0),
    },
  ];

  @override
  void initState() {
    super.initState();
    // 自動輪播
    _startAutoScroll();
    // 載入個人資訊
    _loadUserInfo();
  }
  
  Future<void> _loadUserInfo() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      setState(() => _isLoadingUserInfo = false);
      return;
    }

    setState(() => _isLoadingUserInfo = true);

    try {
      // 1. 平行載入：抓取 Profile (錢包/電話) & 抓取 Students (頭像/姓名)
      final results = await Future.wait<dynamic>([
        // Task A: 抓 Profile
        Supabase.instance.client
            .from('profiles')
            .select()
            .eq('id', user.id)
            .single(),
        // Task B: 抓 Students
        _studentRepository.getMyStudents(),
      ]);

      final profileData = results[0] as Map<String, dynamic>;
      final studentsList = results[1] as List<StudentModel>;

      // 2. 找出本人 (isPrimary = true)
      StudentModel? primary;
      try {
        primary = studentsList.firstWhere((s) => s.isPrimary);
      } catch (_) {
        // 極端情況：如果沒有 primary student，暫時用第一筆或 null
        primary = studentsList.isNotEmpty ? studentsList.first : null;
      }

      if (mounted) {
        setState(() {
          _userEmail = user.email;
          // 電話優先看 profile，沒有才看 auth user
          _userPhone = profileData['phone'] ?? user.phone;
          _students = studentsList;
          _primaryStudent = primary; // 🌟 UI 顯示頭像跟姓名要靠這個
          _isLoadingUserInfo = false;
        });
      }
    } catch (e) {
      debugPrint('載入使用者資料失敗: $e');
      if (mounted) setState(() => _isLoadingUserInfo = false);
    }
  }

  @override
  void dispose() {
    _autoScrollTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _startAutoScroll() {
    _autoScrollTimer?.cancel();
    _autoScrollTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (!mounted || !_pageController.hasClients) {
        timer.cancel();
        return;
      }
      
      // 獲取當前頁面索引
      final currentPage = _pageController.page?.round() ?? _currentPage;
      
      // 計算下一頁索引（循環播放）
      final nextPage = (currentPage + 1) % _displayImages.length;
      
      _pageController.animateToPage(
        nextPage,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '首頁',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {
              context.push('/notifications');
            },
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(
            height: 1,
            thickness: 1,
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 個人資訊卡片
            Padding(
              padding: const EdgeInsets.all(16),
              child: _buildUserInfoCard(),
            ),

            // 精彩一瞬間標題
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                '精彩一瞬間',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // 橫式圖片輪播器（左右 padding 與下方對齊）
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildImageCarousel(),
            ),
            const SizedBox(height: 24),
            
            // 近期活動標題
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                '近期活動',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // 直式圖片展示
            ..._activities.map((activity) => _buildActivityCard(activity)),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildUserInfoCard() {
    if (_isLoadingUserInfo) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    final displayName = _primaryStudent?.name ?? '用戶';
    final primaryGender = _primaryStudent?.gender;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 主帳號資訊
          Row(
            children: [
              Builder(
                builder: (_) {
                  final name = displayName.trim();
                  final initials = name.length >= 2
                      ? name.substring(name.length - 2)
                      : name;

                  return CircleAvatar(
                    radius: 30,
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    child: Text(
                      initials,
                      style: const TextStyle(
                        fontSize: 20,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          displayName,
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        if (primaryGender != null) ...[
                          const SizedBox(width: 4),
                          buildGenderIcon(primaryGender),
                        ],
                      ],
                    ),
                    if (_userEmail != null && _userEmail!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.email,
                              size: 14,
                              color: Colors.grey,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                _userEmail!,
                                style: Theme.of(context).textTheme.bodyMedium,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (_userPhone != null && _userPhone!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.phone_iphone,
                              size: 14,
                              color: Colors.grey,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _userPhone!,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          
          // 家庭成員列表（精簡顯示）
          if (_students.isNotEmpty && _students.length > 1) ...[
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Center(
                  child: const Icon(
                    Icons.people_outline,
                    size: 20,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(width: 6),
                Center(
                  child: Text(
                    '家庭成員',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _students
                  .where((s) => !s.isPrimary) // 排除主帳號
                  .map((student) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .primary
                        .withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      if (student.gender != null) ...[
                        Center(
                          child: SizedBox(
                            width: 24,
                            height: 24,
                            child: buildGenderIcon(student.gender),
                          ),
                        ),
                      ],
                      Center(
                        child: Text(
                          student.name,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildImageCarousel() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        height: 200,
        child: Stack(
          children: [
            PageView.builder(
              controller: _pageController,
              onPageChanged: (index) {
                setState(() {
                  _currentPage = index;
                });
              },
              itemCount: _displayImages.length,
              itemBuilder: (context, index) {
                return Image.asset(
                  _displayImages[index],
                  fit: BoxFit.cover,
                  width: double.infinity,
                );
              },
            ),
            // 指示器
            Positioned(
              bottom: 16,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _displayImages.length,
                  (index) => Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _currentPage == index
                          ? Colors.white
                          : Colors.white.withOpacity(0.5),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityCard(Map<String, dynamic> activity) {
    final dateFormat = DateFormat('yyyy/MM/dd HH:mm');
    return Container(
      margin: const EdgeInsets.only(bottom: 16, left: 16, right: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.asset(
              activity['image'] as String,
              width: double.infinity,
              height: 200,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            activity['name'] as String,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${dateFormat.format(activity['startTime'] as DateTime)} ~ ${dateFormat.format(activity['endTime'] as DateTime)}',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
