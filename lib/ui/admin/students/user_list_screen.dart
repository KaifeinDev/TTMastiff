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
        showErrorSnackBar(context, e, prefix: '載入課程失敗：');
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
        showErrorSnackBar(context, e, prefix: '載入場次失敗：');
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
        showErrorSnackBar(context, e, prefix: '查詢失敗：');
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
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
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
                        final dateFormat = DateFormat(
                          'MM/dd (E) HH:mm',
                          'zh_TW',
                        );
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
                : _studentDataList.isEmpty
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
                    itemCount: _studentDataList.length,
                    itemBuilder: (context, index) {
                      final studentData = _studentDataList[index];
                      final student = studentData['student'] as StudentModel;
                      final parentPhone = studentData['parentPhone'] as String?;

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
                    },
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
            logError('警告：booking ${bookingData['id']} 缺少 sessions 數據');
            continue;
          }

          final booking = BookingModel.fromJson(bookingData);
          bookings.add(booking);
        } catch (e, st) {
          logError('解析 booking 失敗: $bookingData — $e', st);
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
