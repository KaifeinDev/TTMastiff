import 'package:flutter/material.dart';
import 'package:ttmastiff/core/utils/util.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// 假設您的 Model 和 Repository 路徑如下，請根據實際專案結構調整
import '../../data/repositories/auth_repository.dart';
import '../../../student/data/repositories/student_repository.dart';
import '../../../student/data/models/student_model.dart';
import 'package:ttmastiff/core/di/service_locator.dart';
import 'package:ttmastiff/features/auth/data/repositories/auth_manager.dart';
import '../../../booking/data/repositories/booking_repository.dart';
import '../../../../core/widgets/user_info_card.dart';
import '../../../student/presentation/widgets/student_list_item.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _authRepository = AuthRepository(Supabase.instance.client);
  final _studentRepository = StudentRepository(Supabase.instance.client);

  // 狀態變數
  List<StudentModel> _students = [];
  StudentModel? _primaryStudent; // 🌟 新增：專門存「本人」的資料
  bool _isLoading = true;

  // 使用者資訊 (帳號層)
  String? _userEmail;
  String? _userPhone;
  int _credits = 0;
  String? _membership; // profiles.membership

  final authManager = getIt<AuthManager>();

  @override
  void initState() {
    super.initState();
    _loadData();
    // 當 BookingRepository 發出通知時 (例如報名成功扣款後)，
    // 自動重新執行 _loadData 來抓取最新的點數
    BookingRepository.bookingRefreshSignal.addListener(_loadData);
  }

  @override
  void dispose() {
    BookingRepository.bookingRefreshSignal.removeListener(_loadData);
    super.dispose();
  }

  Future<void> _loadData() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    setState(() => _isLoading = true);

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
      } catch (e) {
        logError(e);
      }

      if (mounted) {
        setState(() {
          _userEmail = user.email;
          // 電話優先看 profile，沒有才看 auth user
          _userPhone = profileData['phone'] ?? user.phone;
          _credits = profileData['credits'] ?? 0;
          _membership = profileData['membership'] as String? ?? 'beginner';

          _students = studentsList;
          _primaryStudent = primary; // 🌟 UI 顯示頭像跟姓名要靠這個

          _isLoading = false;
        });
      }
    } catch (e) {
      logError(e);
    }
  }

  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('確定要登出嗎？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('登出', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _authRepository.signOut();
      if (mounted) {
        context.go('/login');
      }
    }
  }

  // 🔒 顯示鎖定提示
  void _showLockedDialog(String title, String content) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('了解'),
          ),
        ],
      ),
    );
  }

  void _showAddStudentDialog() {
    // 1. 檢查上限
    if (_students.length >= 4) {
      _showLockedDialog(
        '已達新增上限',
        '為了確保服務品質，每個帳號最多新增 3 位子學員 (含本人共 4 位)。\n\n如需新增更多成員，請洽詢場館管理員協助。',
      );
      return;
    }

    final nameController = TextEditingController();
    final noteController = TextEditingController();
    DateTime? tempSelectedDate; // 暫存選到的日期

    showDialog(
      context: context,
      builder: (context) {
        // 🌟 使用 StatefulBuilder 讓 Dialog 內部可以更新 UI (顯示選到的日期)
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('新增學員'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '請輸入資料以建立學員檔案',
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                    const SizedBox(height: 16),

                    // 1. 姓名輸入
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: '姓名 / 暱稱',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 2. 生日選擇器
                    InkWell(
                      onTap: () async {
                        final now = DateTime.now();
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: DateTime(2010),
                          firstDate: DateTime(1900),
                          lastDate: now,
                          locale: const Locale('zh', 'TW'),
                        );
                        if (picked != null) {
                          setStateDialog(() => tempSelectedDate = picked);
                        }
                      },
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: '出生年月日',
                          border: OutlineInputBorder(),
                          isDense: true,
                          suffixIcon: Icon(Icons.calendar_today),
                        ),
                        child: Text(
                          tempSelectedDate == null
                              ? '點擊選擇'
                              : '${tempSelectedDate!.year}/${tempSelectedDate!.month}/${tempSelectedDate!.day}',
                          style: TextStyle(
                            color: tempSelectedDate == null
                                ? Colors.grey
                                : Colors.black,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 3. 備註輸入
                    TextField(
                      controller: noteController,
                      decoration: const InputDecoration(
                        labelText: '備註 (選填)',
                        hintText: '特殊身體狀況...',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('取消'),
                ),
                FilledButton(
                  onPressed: () async {
                    final name = nameController.text.trim();

                    if (name.isEmpty) {
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(const SnackBar(content: Text('請輸入姓名')));
                      return;
                    }
                    if (tempSelectedDate == null) {
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(const SnackBar(content: Text('請選擇生日')));
                      return;
                    }

                    Navigator.pop(context);

                    // 呼叫新增方法
                    await _performAddStudent(
                      name,
                      tempSelectedDate!, // 👈 確保不為 null
                      noteController.text.trim().isEmpty
                          ? null
                          : noteController.text.trim(),
                    );
                  },
                  child: const Text('新增'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _performAddStudent(
    String name,
    DateTime birthDate,
    String? note,
  ) async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('正在建立學員資料...'),
        duration: Duration(seconds: 1),
      ),
    );

    try {
      await _studentRepository.addStudent(
        name: name,
        birthDate: birthDate,
        medicalNote: note,
      );
      await _loadData(); // 重新整理全部資料
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('🎉 新增成功！')));
      }
    } catch (e) {
      logError(e);
    }
  }

  void _showEditDialog(StudentModel student) {
    final bool isPrimary = student.isPrimary;
    final nameController = TextEditingController(text: student.name);
    final noteController = TextEditingController(
      text: student.medicalNote ?? '',
    );

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('編輯資料'),
              scrollable: true,
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Name
                  TextField(
                    controller: nameController,
                    enabled: !isPrimary, // 🌟 本人不可改名
                    decoration: InputDecoration(
                      labelText: '姓名',
                      prefixIcon: const Icon(Icons.person_outline),
                      border: const OutlineInputBorder(),
                      filled: isPrimary,
                      fillColor: isPrimary ? Colors.grey.shade100 : null,
                      suffixIcon: isPrimary
                          ? const Icon(Icons.lock, size: 16, color: Colors.grey)
                          : null,
                    ),
                  ),
                  if (isPrimary)
                    const Padding(
                      padding: EdgeInsets.only(top: 4, left: 4, bottom: 16),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '※ 實名制帳號無法自行修改姓名',
                          style: TextStyle(fontSize: 10, color: Colors.grey),
                        ),
                      ),
                    )
                  else
                    const SizedBox(height: 16),

                  // Note
                  TextField(
                    controller: noteController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: '醫療 / 身體狀況備註',
                      hintText: '例如：氣喘、舊傷、過敏...',
                      prefixIcon: Icon(Icons.medical_services_outlined),
                      border: OutlineInputBorder(),
                      alignLabelWithHint: true,
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('取消'),
                ),
                FilledButton(
                  onPressed: () async {
                    Navigator.pop(context);
                    await _performUpdateStudent(
                      student.id,
                      nameController.text.trim(),
                      noteController.text.trim().isEmpty
                          ? null
                          : noteController.text.trim(),
                    );
                  },
                  child: const Text('儲存'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _performUpdateStudent(
    String id,
    String newName,
    String? note,
  ) async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('更新資料中...'), duration: Duration(seconds: 1)),
    );

    try {
      await _studentRepository.updateStudent(id, newName, note);
      await _loadData(); // 重新載入以更新 UI
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('✅ 更新成功！')));
      }
    } catch (e) {
      logError(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    // 🌟 獲取主要顯示資訊
    final displayName = _primaryStudent?.name ?? '用戶';
    final primaryGender = _primaryStudent?.gender;
    return ListenableBuilder(
      listenable: authManager,
      builder: (context, child) {
        final bool isAdmin = authManager.isAdmin;
        final bool isCoach = authManager.isCoach;
        return Scaffold(
          appBar: AppBar(
            title: const Text(
              '我的檔案',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: Divider(
                height: 1,
                thickness: 1,
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.logout),
                onPressed: _handleLogout,
                tooltip: '登出',
              ),
            ],
          ),
          body: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 1. 主帳號資訊卡片
                        UserInfoCard(
                          displayName: displayName,
                          gender: primaryGender,
                          email: _userEmail,
                          phone: _userPhone,
                          membership: _membership,
                          padding: const EdgeInsets.all(12),
                          showLockButton: true,
                          isPrimary: true, // 主帳號是本人
                          onLockTap: () => _showLockedDialog(
                            '資料已鎖定',
                            '為了確保會員權益與實名制安全，主帳號資料無法自行修改。\n\n如需變更，請洽櫃檯人員。',
                          ),
                        ),

                        const SizedBox(height: 16),
                        if (isAdmin || isCoach) ...[
                          Card(
                            shadowColor: Colors.blueGrey.shade50,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: BorderSide(color: Colors.blueGrey.shade200),
                            ),
                            color: Colors.blueGrey.shade50, // 用淺紅色背景區分
                            child: InkWell(
                              onTap: () {
                                // 這裡填入您後台的首頁路由
                                context.go('/admin/dashboard');
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 16,
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: Colors.blueGrey.shade100,
                                        ),
                                      ),
                                      child: Icon(
                                        Icons.admin_panel_settings,
                                        color: Colors.blueGrey.shade900,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '管理後台',
                                            style: TextStyle(
                                              color: Colors.blueGrey.shade900,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                          Text(
                                            '切換至管理員模式',
                                            style: TextStyle(
                                              color: Colors.blueGrey.shade700,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Icon(
                                      Icons.arrow_forward_ios,
                                      size: 16,
                                      color: Colors.blueGrey.shade900,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          // 加一點間距，才不會跟下面的錢包卡片黏在一起
                          const SizedBox(height: 16),
                        ],

                        // 2. 錢包/點數區塊
                        Card(
                          shape: RoundedRectangleBorder(
                            side: BorderSide(
                              color: const Color.fromARGB(255, 242, 148, 136),
                              width: 1,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: 18,
                              horizontal: 20,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '剩餘點數',
                                  style: TextStyle(
                                    color: Colors.black,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.monetization_on,
                                          color: Colors.amber,
                                          size: 48,
                                        ),
                                        const SizedBox(width: 12),
                                        Text(
                                          NumberFormat(
                                            '#,###',
                                          ).format(_credits),
                                          style: TextStyle(
                                            color: Theme.of(
                                              context,
                                            ).primaryColor,
                                            fontSize: 28,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ],
                                    ),
                                    FilledButton.tonal(
                                      onPressed: () {
                                        context.push('/profile/transactions');
                                      },
                                      style: FilledButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 18,
                                          vertical: 12,
                                        ),
                                        shape: const StadiumBorder(),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(Icons.history, size: 18),
                                          const SizedBox(width: 6),
                                          Text(
                                            '查看紀錄',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 15,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),

                        // 3. 學員管理標題
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.people_outline),
                                  const SizedBox(width: 6),
                                  Text(
                                    '家庭成員 / 學員',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleLarge
                                        ?.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                              FilledButton.tonalIcon(
                                onPressed: _showAddStudentDialog,
                                icon: const Icon(Icons.add),
                                label: const Text('新增'),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // 4. 學員列表（淺灰背景）
                        if (_students.isEmpty)
                          const Center(
                            child: Padding(
                              padding: EdgeInsets.all(32.0),
                              child: Text('載入中...'),
                            ),
                          )
                        else
                          Container(
                            color: Colors.grey.shade50,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            child: ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _students.length,
                              separatorBuilder: (context, index) =>
                                  const SizedBox(height: 16),
                              itemBuilder: (context, index) {
                                final student = _students[index];
                                final isSelf = student.isPrimary;

                                return StudentListItem(
                                  student: student,
                                  isPrimary: isSelf,
                                  medicalNote: student.medicalNote,
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                  ),
                                  onTap: () => _showEditDialog(student),
                                );
                              },
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
        );
      },
    );
  }
}
