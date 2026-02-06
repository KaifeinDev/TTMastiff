import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../student/data/repositories/student_repository.dart';
import '../../../activity/data/repositories/activity_repository.dart';
import '../../../student/data/models/student_model.dart';
import '../../../activity/data/models/activity_model.dart';
import '../../../../core/widgets/user_info_card.dart';
import '../../../../core/widgets/gender_icon.dart';

class ClientHomeScreen extends StatefulWidget {
  const ClientHomeScreen({super.key});

  @override
  State<ClientHomeScreen> createState() => _ClientHomeScreenState();
}

class _ClientHomeScreenState extends State<ClientHomeScreen> {
  late final PageController _pageController;
  int _currentPage = 0;
  
  final _studentRepository = StudentRepository(Supabase.instance.client);
  final _activityRepository = ActivityRepository(Supabase.instance.client);

  final Map<String, Uint8List> _activityImageCache = {};
  
  // 個人資訊狀態
  List<StudentModel> _students = [];
  StudentModel? _primaryStudent;
  String? _membership; // 會員等級
  String? _userEmail;
  String? _userPhone;
  bool _isLoadingUserInfo = true;

  // 活動資料
  List<ActivityModel> _carouselActivities = [];
  List<ActivityModel> _recentActivities = [];
  bool _isLoadingActivities = true;
  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    // 載入個人資訊
    _loadUserInfo();
    // 載入活動資料
    _loadActivities();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 當從其他頁面返回時，重新載入未讀數量
    _refreshUnreadCount();
  }

  Future<void> _refreshUnreadCount() async {
    try {
      final unreadCount = await _activityRepository.getUnreadCount();
      if (mounted) {
        setState(() {
          _unreadCount = unreadCount;
        });
      }
    } catch (e) {
      debugPrint('更新未讀數量失敗: $e');
    }
  }
  
  Future<void> _loadUserInfo() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      setState(() => _isLoadingUserInfo = false);
      return;
    }

    setState(() => _isLoadingUserInfo = true);

    try {
      // 1. 平行載入：抓取 Profile (會員等級/電話) & 抓取 Students (頭像/姓名)
      final results = await Future.wait<dynamic>([
        // Task A: 抓 Profile (會員等級/電話)
        Supabase.instance.client
            .from('profiles')
            .select('membership, phone')
            .eq('id', user.id)
            .single(),
        // Task B: 抓 Students
        _studentRepository.getMyStudents(),
      ]);

      final profileData = results[0] as Map<String, dynamic>;
      final studentsList = results[1] as List<StudentModel>;
      final membership = profileData['membership'] as String?;
      final phone = profileData['phone'] as String?;

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
          _students = studentsList;
          _primaryStudent = primary; // 🌟 UI 顯示頭像跟姓名要靠這個
          _membership = membership;
          _userEmail = user.email;
          _userPhone = phone ?? user.phone;
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
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadActivities() async {
    try {
      final carousel = await _activityRepository.getActivities(
        type: 'carousel',
        status: 'active',
      );
      final recent = await _activityRepository.getActivities(
        type: 'recent',
        status: 'active',
      );
      final unreadCount = await _activityRepository.getUnreadCount();

      if (mounted) {
        setState(() {
          _carouselActivities = carousel;
          _recentActivities = recent;
          _unreadCount = unreadCount;
          _isLoadingActivities = false;
        });
      }
    } catch (e) {
      debugPrint('載入活動失敗: $e');
      if (mounted) {
        setState(() => _isLoadingActivities = false);
      }
    }
  }

  Uint8List? _getCachedBytes(String cacheKey, String? base64Image) {
    if (_activityImageCache.containsKey(cacheKey)) {
      return _activityImageCache[cacheKey];
    }
    if (base64Image == null || base64Image.isEmpty) return null;
    try {
      final bytes = base64Decode(base64Image);
      _activityImageCache[cacheKey] = bytes;
      return bytes;
    } catch (_) {
      return null;
    }
  }

  Widget _buildImageFromBase64(String? base64Image, {Uint8List? bytes}) {
    if (base64Image == null || base64Image.isEmpty) {
      return Container(
        color: Colors.grey.shade200,
        child: const Center(
          child: Icon(Icons.image, size: 64, color: Colors.grey),
        ),
      );
    }

    try {
      final imageBytes = bytes ?? base64Decode(base64Image);
      return Image.memory(
        imageBytes,
        fit: BoxFit.cover,
        width: double.infinity,
        gaplessPlayback: true,
      );
    } catch (e) {
      return Container(
        color: Colors.grey.shade200,
        child: const Center(
          child: Icon(Icons.broken_image, size: 64, color: Colors.grey),
        ),
      );
    }
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
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined),
                onPressed: () async {
                  await context.push('/notifications');
                  // 從通知頁面返回時，重新載入未讀數量
                  _refreshUnreadCount();
                },
              ),
              if (_unreadCount > 0)
                Positioned(
                  right: 10,
                  top: 8,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
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
            if (_isLoadingActivities)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(
                  height: 200,
                  child: Center(child: CircularProgressIndicator()),
                ),
              )
            else if (_carouselActivities.isNotEmpty)
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
            if (_isLoadingActivities)
              const Center(child: CircularProgressIndicator())
            else if (_recentActivities.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: Text(
                    '暫無活動',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ),
              )
            else
              ..._recentActivities.map((activity) => _buildActivityCard(activity)),
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 主帳號資訊
        UserInfoCard(
          displayName: displayName,
          gender: primaryGender,
          email: _userEmail,
          phone: _userPhone,
          membership: _membership,
          isPrimary: true, // 主帳號是本人
        ),
        
        // 家庭成員列表
        if (_students.isNotEmpty && _students.length > 1) ...[
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Icon(
                Icons.people_outline,
                size: 20,
                color: Colors.grey,
              ),
              const SizedBox(width: 6),
              Text(
                '家庭成員',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700,
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
                      SizedBox(
                        width: 24,
                        height: 24,
                        child: GenderIcon(gender: student.gender),
                      ),
                      const SizedBox(width: 4),
                    ],
                    Text(
                      student.name,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildImageCarousel() {
    if (_carouselActivities.isEmpty) {
      return const SizedBox.shrink();
    }

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
              itemCount: _carouselActivities.length,
              itemBuilder: (context, index) {
                final a = _carouselActivities[index];
                final bytes = _getCachedBytes('carousel:${a.id}', a.image);
                return RepaintBoundary(
                  child: _buildImageFromBase64(a.image, bytes: bytes),
                );
              },
            ),
            // 指示器
            if (_carouselActivities.length > 1)
              Positioned(
                bottom: 16,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    _carouselActivities.length,
                    (index) => GestureDetector(
                      onTap: () {
                        _pageController.animateToPage(
                          index,
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeInOut,
                        );
                      },
                      child: Container(
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
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityCard(ActivityModel activity) {
    final dateFormat = DateFormat('yyyy/MM/dd HH:mm');
    return InkWell(
      onTap: () {
        context.push('/activity/${activity.id}');
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16, left: 16, right: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: double.infinity,
                height: 200,
                child: RepaintBoundary(
                  child: _buildImageFromBase64(
                    activity.image,
                    bytes: _getCachedBytes('recent:${activity.id}', activity.image),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              activity.title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${dateFormat.format(activity.startTime)} ~ ${dateFormat.format(activity.endTime)}',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
