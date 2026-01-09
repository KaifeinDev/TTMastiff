import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

import '../../data/services/student_repository.dart';
import '../../data/services/course_repository.dart';
import '../../data/services/session_repository.dart';
import '../../data/models/student_model.dart';
import '../../data/models/course_model.dart';
import '../../data/models/session_model.dart';
import '../../data/models/booking_model.dart';
import '../../core/utils/util.dart';
import 'courses/widgets/session_edit_dialog.dart';

class UserListScreen extends StatefulWidget {
  const UserListScreen({super.key});

  @override
  State<UserListScreen> createState() => _UserListScreenState();
}

class _UserListScreenState extends State<UserListScreen> {
  late final StudentRepository _studentRepo;
  late final CourseRepository _courseRepo;
  late final SessionRepository _sessionRepo;

  // 篩選狀態
  List<CourseModel> _courses = [];
  CourseModel? _selectedCourse;
  List<SessionModel> _sessions = [];
  SessionModel? _selectedSession;
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();

  // 學員列表
  List<StudentModel> _students = [];
  Map<String, String?> _studentPhones = {}; // 存儲學員 ID -> 電話的映射
  bool _isLoading = false;
  bool _isLoadingFilter = false;

  @override
  void initState() {
    super.initState();
    _studentRepo = StudentRepository(Supabase.instance.client);
    _courseRepo = CourseRepository(Supabase.instance.client);
    _sessionRepo = SessionRepository(Supabase.instance.client);
    _loadCourses();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _loadCourses() async {
    try {
      final courses = await _courseRepo.getCourses();
      if (mounted) {
        setState(() {
          _courses = courses;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('載入課程失敗: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _loadSessions(String courseId) async {
    setState(() {
      _isLoadingFilter = true;
      _selectedSession = null;
      _sessions = [];
    });

    try {
      // 查詢該課程的所有場次（不限制未來場次）
      final sessions = await _sessionRepo.getSessionsByCourse(courseId);
      if (mounted) {
        setState(() {
          _sessions = sessions;
          _isLoadingFilter = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingFilter = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('載入場次失敗: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _onCourseChanged(CourseModel? course) async {
    setState(() {
      _selectedCourse = course;
      _selectedSession = null;
      _sessions = [];
    });

    if (course != null) {
      await _loadSessions(course.id);
    }
  }

  Future<void> _searchStudents() async {
    setState(() {
      _isLoading = true;
      _students = [];
      _studentPhones = {};
    });

    try {
      final students = await _studentRepo.fetchStudentsByFilter(
        courseId: _selectedCourse?.id,
        sessionId: _selectedSession?.id,
        name: _nameController.text.trim().isEmpty ? null : _nameController.text.trim(),
        phone: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
      );

      // 批量查詢學員的家長電話
      if (students.isNotEmpty) {
        final parentIds = students.map((s) => s.parentId).toSet().toList();
        try {
          final profilesResponse = await Supabase.instance.client
              .from('profiles')
              .select('id, phone')
              .inFilter('id', parentIds);

          final Map<String, String?> phoneMap = {};
          for (var profile in profilesResponse) {
            phoneMap[profile['id'] as String] = profile['phone'] as String?;
          }

          // 建立學員 ID -> 電話的映射
          final Map<String, String?> studentPhoneMap = {};
          for (var student in students) {
            studentPhoneMap[student.id] = phoneMap[student.parentId];
          }

          if (mounted) {
            setState(() {
              _students = students;
              _studentPhones = studentPhoneMap;
              _isLoading = false;
            });
          }
        } catch (e) {
          // 如果查詢電話失敗，仍然顯示學員列表，只是沒有電話
          if (mounted) {
            setState(() {
              _students = students;
              _studentPhones = {};
              _isLoading = false;
            });
          }
        }
      } else {
        if (mounted) {
          setState(() {
            _students = students;
            _studentPhones = {};
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('查詢失敗: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('學員管理'),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      backgroundColor: Colors.grey.shade100,
      body: Column(
        children: [
          // 篩選區域
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '篩選條件',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 16),

                // 課程選擇
                DropdownButtonFormField<CourseModel>(
                  value: _selectedCourse,
                  isExpanded: true, // 讓下拉選單可以展開，避免溢出
                  decoration: const InputDecoration(
                    labelText: '選擇課程',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.book),
                  ),
                  items: [
                    const DropdownMenuItem<CourseModel>(
                      value: null,
                      child: Text('全部課程'),
                    ),
                    ..._courses.map((course) {
                      return DropdownMenuItem<CourseModel>(
                        value: course,
                        child: Text(
                          course.title,
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      );
                    }),
                  ],
                  onChanged: _onCourseChanged,
                ),
                const SizedBox(height: 16),

                // 場次選擇
                if (_selectedCourse != null)
                  DropdownButtonFormField<SessionModel>(
                    value: _selectedSession,
                    decoration: InputDecoration(
                      labelText: '選擇場次',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.calendar_today),
                      suffixIcon: _isLoadingFilter
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : null,
                    ),
                    items: [
                      const DropdownMenuItem<SessionModel>(
                        value: null,
                        child: Text('全部場次'),
                      ),
                      ..._sessions.map((session) {
                        final dateFormat = DateFormat('MM/dd (E) HH:mm', 'zh_TW');
                        return DropdownMenuItem<SessionModel>(
                          value: session,
                          child: Text(
                            '${dateFormat.format(session.startTime)} - ${DateFormat('HH:mm').format(session.endTime)}',
                          ),
                        );
                      }),
                    ],
                    onChanged: (session) {
                      setState(() => _selectedSession = session);
                    },
                  ),

                const SizedBox(height: 16),

                // 名字搜尋
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: '姓名（選填）',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person),
                    hintText: '輸入姓名進行模糊搜尋',
                  ),
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 16),

                // 電話搜尋
                TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: '電話（選填）',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.phone),
                    hintText: '輸入電話進行模糊搜尋',
                  ),
                  textInputAction: TextInputAction.done,
                ),
                const SizedBox(height: 16),

                // 查詢按鈕
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _isLoading ? null : _searchStudents,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text('查詢', style: TextStyle(fontSize: 16)),
                  ),
                ),
              ],
            ),
          ),

          // 學員列表
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _students.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.people_outline,
                              size: 64,
                              color: Colors.grey.shade300,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              '目前還沒有學員報名這堂課！',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _students.length,
                        itemBuilder: (context, index) {
                          final student = _students[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundImage: student.avatarUrl != null
                                    ? NetworkImage(student.avatarUrl!)
                                    : null,
                                child: student.avatarUrl == null
                                    ? Text(
                                        student.name.isNotEmpty
                                            ? student.name[0]
                                            : '?',
                                        style: const TextStyle(fontSize: 20),
                                      )
                                    : null,
                              ),
                              title: Text(
                                student.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.cake_outlined,
                                        size: 16,
                                        color: Colors.grey.shade600,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        student.birthDate.toDateWithAge(),
                                        style: TextStyle(
                                          color: Colors.grey.shade600,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (_studentPhones[student.id] != null &&
                                      _studentPhones[student.id]!.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.phone_outlined,
                                          size: 16,
                                          color: Colors.grey.shade600,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          _studentPhones[student.id]!,
                                          style: TextStyle(
                                            color: Colors.grey.shade600,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () {
                                _showStudentDetail(student);
                              },
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Future<void> _showStudentDetail(StudentModel student) async {

    // 顯示載入對話框
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      final detail = await _studentRepo.fetchStudentDetail(student.id);
      
      // 關閉載入對話框
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }

      if (!mounted) return;

      final bookingsRaw = detail['bookings'] as List;
      
      // 安全地解析 bookings，添加錯誤處理
      final List<BookingModel> bookings = [];
      for (var bookingData in bookingsRaw) {
        try {
          // 檢查必要的數據是否存在
          if (bookingData['sessions'] == null) {
            print('⚠️ 警告：booking ${bookingData['id']} 缺少 sessions 數據');
            continue;
          }
          
          final booking = BookingModel.fromJson(bookingData);
          bookings.add(booking);
        } catch (e) {
          print('❌ 解析 booking 失敗: $e');
          print('📦 數據內容: $bookingData');
          // 繼續處理其他 booking，不中斷整個流程
        }
      }
      
      // 按時間排序（最新的在前）
      bookings.sort((a, b) => b.session.startTime.compareTo(a.session.startTime));

      // 導航到詳情頁
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => StudentDetailScreen(
              student: student,
              parentPhone: detail['parentPhone'] as String?,
              parentName: detail['parentName'] as String?,
              bookings: bookings,
            ),
          ),
        );
      }
    } catch (e, stackTrace) {
      // 確保關閉載入對話框
      if (mounted) {
        // 使用 rootNavigator 確保關閉正確的 dialog
        final navigator = Navigator.of(context, rootNavigator: true);
        if (navigator.canPop()) {
          navigator.pop();
        }
        
        print('❌ 載入學員詳情錯誤: $e');
        print('📚 Stack trace: $stackTrace');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('載入詳情失敗: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }
}

class StudentDetailScreen extends StatelessWidget {
  final StudentModel student;
  final String? parentPhone;
  final String? parentName;
  final List<BookingModel> bookings;

  const StudentDetailScreen({
    super.key,
    required this.student,
    this.parentPhone,
    this.parentName,
    required this.bookings,
  });

  // 將 DateFormat 設為靜態常量，避免每次 build 都創建新實例
  static final _dateFormat = DateFormat('yyyy/MM/dd (E)', 'zh_TW');
  static final _timeFormat = DateFormat('HH:mm');

  @override
  Widget build(BuildContext context) {
    // 判斷學員是否為本人（註冊者）
    // 如果 student.name == parentName，則為本人
    final isSelf = parentName != null && 
                  parentName!.trim().isNotEmpty &&
                  student.name.trim() == parentName!.trim();

    return Scaffold(
      appBar: AppBar(
        title: Text(student.name),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      backgroundColor: Colors.grey.shade100,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 學員基本資訊卡片
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _StudentAvatar(
                        avatarUrl: student.avatarUrl,
                        name: student.name,
                        radius: 40,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              student.name,
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(
                                  Icons.cake_outlined,
                                  size: 16,
                                  color: Colors.grey.shade600,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  student.birthDate.toDateWithAge(),
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 32),
                  // 如果是本人，只顯示電話；如果不是本人，顯示家長電話和家長姓名
                  _InfoRow(
                    icon: Icons.phone,
                    label: isSelf ? '電話' : '家長電話',
                    value: parentPhone ?? '未提供',
                  ),
                  if (!isSelf) ...[
                    const SizedBox(height: 12),
                    _InfoRow(
                      icon: Icons.person,
                      label: '家長姓名',
                      value: parentName ?? '未提供',
                    ),
                  ],
                  if (student.medical_note != null && student.medical_note!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _InfoRow(
                      icon: Icons.medical_information,
                      label: '醫療備註',
                      value: student.medical_note!,
                    ),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // 報名課程列表
          Text(
            '報名課程 (${bookings.length})',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 12),

          if (bookings.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Center(
                  child: Text(
                    '尚未報名任何課程',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ),
              ),
            )
          else
            ...bookings.map((booking) {
              final session = booking.session;
              final course = session.course;
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                elevation: 1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: course != null
                      ? () {
                          // 直接打開該場次的對話框
                          final category = course.category;
                          showDialog(
                            context: context,
                            builder: (dialogContext) => SessionEditDialog(
                              session: session,
                              category: category,
                            ),
                          );
                        }
                      : null,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                course?.title ?? '未知課程',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            if (course != null)
                              const Icon(
                                Icons.arrow_forward_ios,
                                size: 16,
                                color: Colors.blue,
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(
                              Icons.calendar_today,
                              size: 16,
                              color: Colors.grey.shade600,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${_dateFormat.format(session.startTime)} ${_timeFormat.format(session.startTime)} - ${_timeFormat.format(session.endTime)}',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.attach_money,
                              size: 16,
                              color: Colors.grey.shade600,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '\$${booking.price_snapshot}',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 14,
                              ),
                            ),
                            const Spacer(),
                            _StatusChip(status: booking.attendanceStatus),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey.shade600),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: TextStyle(
            color: Colors.grey.shade600,
            fontSize: 14,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;

  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    String text;

    switch (status) {
      case 'attended':
        color = Colors.green;
        text = '已出席';
        break;
      case 'absent':
        color = Colors.red;
        text = '缺席';
        break;
      case 'leave':
        color = Colors.orange;
        text = '請假';
        break;
      default:
        color = Colors.grey;
        text = '待上課';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

// 獨立的 Avatar Widget，避免 NetworkImage 導致持續 rebuild
class _StudentAvatar extends StatelessWidget {
  final String? avatarUrl;
  final String name;
  final double radius;

  const _StudentAvatar({
    required this.avatarUrl,
    required this.name,
    required this.radius,
  });

  @override
  Widget build(BuildContext context) {
    if (avatarUrl != null && avatarUrl!.isNotEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundImage: NetworkImage(avatarUrl!),
        onBackgroundImageError: (exception, stackTrace) {
          // 圖片加載失敗時使用默認顯示
        },
        child: null, // 有圖片時不顯示文字
      );
    } else {
      return CircleAvatar(
        radius: radius,
        backgroundColor: Colors.grey.shade300,
        child: Text(
          name.isNotEmpty ? name[0] : '?',
          style: TextStyle(fontSize: radius * 0.8),
        ),
      );
    }
  }
}
