import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:ttmastiff/main.dart';

import '../../../data/models/student_model.dart';
import '../../../data/models/course_model.dart';
import '../../../data/models/session_model.dart';
import '../../../data/models/booking_model.dart';
import '../../../core/utils/util.dart';

class UserListScreen extends StatefulWidget {
  const UserListScreen({super.key});

  @override
  State<UserListScreen> createState() => _UserListScreenState();
}

class _UserListScreenState extends State<UserListScreen> {
  // 篩選狀態
  List<CourseModel> _courses = [];
  CourseModel? _selectedCourse;
  List<SessionModel> _sessions = [];
  SessionModel? _selectedSession;
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();

  // 學員列表（包含完整資訊）
  List<Map<String, dynamic>> _studentDataList = []; // 存儲完整的學員數據
  bool _isLoading = false;
  bool _isLoadingFilter = false;

  @override
  void initState() {
    super.initState();
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
      final courses = await courseRepository.getCourses();
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
      // 查詢該課程的所有場次
      final sessions = await sessionRepository.getSessionsByCourse(courseId);
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
      _studentDataList = [];
    });

    try {
      // 查詢時就包含完整資訊（包括報名課程）
      final results = await studentRepository.fetchStudentsByFilter(
        courseId: _selectedCourse?.id,
        sessionId: _selectedSession?.id,
        name: _nameController.text.trim().isEmpty
            ? null
            : _nameController.text.trim(),
        phone: _phoneController.text.trim().isEmpty
            ? null
            : _phoneController.text.trim(),
        includeBookings: true, // 列表頁就包含報名課程，詳情頁直接使用
      );

      if (mounted) {
        setState(() {
          _studentDataList = results;
          _isLoading = false;
        });
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

  Widget _buildFilterSection() {
    final screenWidth = MediaQuery.of(context).size.width;
    final bool isDesktop = screenWidth > 900;

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '篩選條件',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 16),
          if (isDesktop)
            // 電腦版：所有條件和搜尋按鈕同一行
            Row(
              children: [
                SizedBox(
                  width: 150, // 課程選擇器固定寬度
                  child: _buildCourseSelector(),
                ),
                const SizedBox(width: 16),
                if (_selectedCourse != null) ...[
                  SizedBox(
                    width: 280, // 場次選擇器固定寬度
                    child: _buildSessionSelector(),
                  ),
                  const SizedBox(width: 16),
                ],
                Flexible(
                  child: _buildNameField(),
                ),
                const SizedBox(width: 16),
                Flexible(
                  child: _buildPhoneField(),
                ),
                const SizedBox(width: 16),
                _buildSearchButton(),
              ],
            )
          else
            // 手機版：垂直佈局
            Column(
              children: [
                _buildCourseSelector(isMobile: true),
                const SizedBox(height: 16),
                if (_selectedCourse != null) ...[
                  _buildSessionSelector(isMobile: true),
                  const SizedBox(height: 16),
                ],
                _buildNameField(isMobile: true),
                const SizedBox(height: 16),
                _buildPhoneField(isMobile: true),
                const SizedBox(height: 16),
                _buildSearchButton(),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildCourseSelector({bool isMobile = false}) {
    return DropdownButtonFormField<CourseModel?>(
      value: _selectedCourse,
      isExpanded: true, // 桌面版也需要 isExpanded 來正確截斷文字
      dropdownColor: Colors.white,
      decoration: InputDecoration(
        labelText: '選擇課程',
        border: const OutlineInputBorder(),
        prefixIcon: const Icon(Icons.book),
      ),
      items: [
        const DropdownMenuItem<CourseModel?>(
          value: null,
          child: Text('全部課程'),
        ),
        ..._courses.map((course) => DropdownMenuItem<CourseModel?>(
              value: course,
              child: Text(
                course.title,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            )),
      ],
      onChanged: _onCourseChanged,
    );
  }

  Widget _buildSessionSelector({bool isMobile = false}) {
    return DropdownButtonFormField<SessionModel?>(
      value: _selectedSession,
      isExpanded: true, // 桌面版也需要 isExpanded 來正確截斷文字
      dropdownColor: Colors.white,
      decoration: InputDecoration(
        labelText: '選擇場次',
        border: const OutlineInputBorder(),
        prefixIcon: _isLoadingFilter
            ? const SizedBox(
                width: 30,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.calendar_today),
        constraints: isMobile ? null : const BoxConstraints(minWidth: 200),
      ),
      selectedItemBuilder: (context) {
        // 自定義選中項的顯示，確保文字可以截斷
        return [
          const Text('全部場次', overflow: TextOverflow.ellipsis),
          ..._sessions.map((session) {
            final dateFormat = DateFormat('MM/dd (E) HH:mm', 'zh_TW');
            return Text(
              '${dateFormat.format(session.startTime)} - ${DateFormat('HH:mm').format(session.endTime)}',
              overflow: TextOverflow.ellipsis,
            );
          }),
        ];
      },
      items: [
        const DropdownMenuItem<SessionModel?>(
          value: null,
          child: Text('全部場次'),
        ),
        ..._sessions.map((session) {
          final dateFormat = DateFormat('MM/dd (E) HH:mm', 'zh_TW');
          return DropdownMenuItem<SessionModel?>(
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
    );
  }

  Widget _buildNameField({bool isMobile = false}) {
    return isMobile
        ? TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: '姓名（選填）',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.person),
              hintText: '輸入姓名進行模糊搜尋',
            ),
            textInputAction: TextInputAction.next,
          )
        : IntrinsicWidth(
            child: TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: '姓名（選填）',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
                hintText: '輸入姓名進行模糊搜尋',
              ),
              textInputAction: TextInputAction.next,
            ),
          );
  }

  Widget _buildPhoneField({bool isMobile = false}) {
    return isMobile
        ? TextField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: '電話（選填）',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.phone),
              hintText: '輸入電話進行模糊搜尋',
            ),
            textInputAction: TextInputAction.done,
          )
        : IntrinsicWidth(
            child: TextField(
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
          );
  }

  Widget _buildSearchButton() {
    final screenWidth = MediaQuery.of(context).size.width;
    final bool isDesktop = screenWidth > 900;
    
    return isDesktop
        ? IconButton(
            onPressed: _isLoading ? null : _searchStudents,
            icon: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.search),
            style: IconButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.all(2),
            ),
          )
        : SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _isLoading ? null : _searchStudents,
              icon: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.search),
              label: _isLoading
                  ? const SizedBox.shrink()
                  : const Text(
                      '查詢',
                      style: TextStyle(fontSize: 16),
                    ),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
              ),
            ),
          );
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
      backgroundColor: Colors.grey.shade50,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _studentDataList.isEmpty && !_isLoading
              ? SingleChildScrollView(
                  child: Column(
                    children: [
                      // 篩選區域（可滾動）
                      _buildFilterSection(),
                      // 空狀態
                      SizedBox(
                        height: MediaQuery.of(context).size.height * 0.4,
                        child: Center(
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
                        ),
                      ),
                    ],
                  ),
                )
              : ListView(
                  children: [
                    // 篩選區域（可滾動）
                    _buildFilterSection(),
                    // 學員列表區域（淺灰背景）
                    Container(
                      color: Colors.grey.shade50,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Column(
                        children: [
                          ..._studentDataList.map((studentData) {
                            final student = studentData['student'] as StudentModel;
                            final parentPhone = studentData['parentPhone'] as String?;
                            final isPrimary = student.isPrimary;
                            final name = student.name.trim();
                            final initials = name.isEmpty
                                ? '?'
                                : (name.length >= 2
                                    ? name.substring(name.length - 2)
                                    : name);

                            return Card(
                              margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: ListTile(
                                leading: CircleAvatar(
                                  radius: 25,
                                  backgroundColor: isPrimary
                                      ? Theme.of(context).colorScheme.primary
                                      : Theme.of(context)
                                          .colorScheme
                                          .primary
                                          .withOpacity(0.12),
                                  child: Text(
                                    initials,
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                      color: isPrimary
                                          ? Colors.white
                                          : Theme.of(context).colorScheme.primary,
                                    ),
                                  ),
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
                                    if (parentPhone != null &&
                                        parentPhone.isNotEmpty) ...[
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
                                            parentPhone,
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
                                  _showStudentDetail(studentData);
                                },
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }

  void _showStudentDetail(Map<String, dynamic> studentData) {
    // 直接使用列表頁已有的完整數據，無需再次調用 API
    final student = studentData['student'] as StudentModel;
    final parentPhone = studentData['parentPhone'] as String?;
    final parentName = studentData['parentName'] as String?;
    final bookingsRaw = studentData['bookings'] as List?;

    // 安全地解析 bookings，添加錯誤處理
    final List<BookingModel> bookings = [];
    if (bookingsRaw != null) {
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
      bookings.sort(
        (a, b) => b.session.startTime.compareTo(a.session.startTime),
      );
    }

    // 直接導航到詳情頁
    context.go(
      '/admin/users/${student.id}', // 對應剛剛設定的 path
      extra: {
        'student': student,
        'parentName': parentName,
        'parentPhone': parentPhone,
      },
    );
  }
}
