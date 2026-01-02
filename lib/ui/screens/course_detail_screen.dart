import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/services/booking_repository.dart';
import '../../data/services/student_repository.dart';
import '../../data/services/course_repository.dart'; // 需擴充 fetchSessionsByCourseId
import '../../data/models/session_model.dart';
import '../../data/models/student_model.dart';
import '../../data/models/course_model.dart'; // 需引入 CourseModel

class CourseDetailScreen extends StatefulWidget {
  // 🔥 改動 1: 這裡接收 courseId，而不是 sessionId
  // 因為我們要顯示這個課程的"所有"未來場次
  final String courseId;

  const CourseDetailScreen({super.key, required this.courseId});

  @override
  State<CourseDetailScreen> createState() => _CourseDetailScreenState();
}

class _CourseDetailScreenState extends State<CourseDetailScreen> {
  // ... Repositories (同前) ...
  late final StudentRepository _studentRepo;
  late final BookingRepository _bookingRepo;
  late final CourseRepository _courseRepo; // 假設您已在 Repo 加入 fetchSessionsByCourseId

  CourseModel? _course;
  List<SessionModel> _upcomingSessions = []; // 未來的場次列表
  List<StudentModel> _myStudents = [];

  bool _isLoading = true;
  bool _isBooking = false;

  // 🔥 狀態管理：使用者勾選了哪些？
  final Set<String> _selectedStudentIds = {};
  final Set<String> _selectedSessionIds = {};

  @override
  void initState() {
    super.initState();
    // 初始化 Repo ...
    final client = Supabase.instance.client;
    _studentRepo = StudentRepository(client);
    _bookingRepo = BookingRepository(client);
    _courseRepo = CourseRepository(client); // 需實作相關方法

    _loadData();
  }

  Future<void> _loadData() async {
    try {
      // 1. 平行讀取：課程資訊、未來場次、我的學員
      final results = await Future.wait([
        _courseRepo.fetchCourseById(widget.courseId), // 需實作
        _courseRepo.fetchUpcomingSessionsByCourseId(widget.courseId), // 需實作
        _studentRepo.getMyStudents(),
      ]);

      if (mounted) {
        setState(() {
          _course = results[0] as CourseModel;
          _upcomingSessions = results[1] as List<SessionModel>;
          _myStudents = results[2] as List<StudentModel>;
          
          // 預設全選未來 4 週的場次 (提升體驗)
          // _selectedSessionIds.addAll(_upcomingSessions.take(4).map((e) => e.id));
          
          // 預設選取主要學員
          final primaryStudent = _myStudents.firstWhere((s) => s.isPrimary, orElse: () => _myStudents.first);
          _selectedStudentIds.add(primaryStudent.id);

          _isLoading = false;
        });
      }
    } catch (e) {
      if(mounted) setState(() => _isLoading = false);
      debugPrint("Error: $e");
    }
  }

  // 執行批量報名
  Future<void> _onBatchBookPressed() async {
    if (_selectedStudentIds.isEmpty || _selectedSessionIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('請至少選擇一位學員和一堂課程')));
      return;
    }

    setState(() => _isBooking = true);

    try {
      // 計算總金額 (給用戶確認用，或是顯示在 Log)
      final totalCost = _selectedStudentIds.length * _selectedSessionIds.length * _course!.price;
      print("預計扣款/花費: $totalCost");

      await _bookingRepo.createBatchBooking(
        sessionIds: _selectedSessionIds.toList(),
        studentIds: _selectedStudentIds.toList(),
        priceSnapshot: _course!.price,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('成功報名 ${_selectedSessionIds.length} 堂課 x ${_selectedStudentIds.length} 位學員！'),
            backgroundColor: Colors.green,
          )
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if(mounted) {
        setState(() => _isBooking = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('報名失敗: $e'), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_course == null) return const Scaffold(body: Center(child: Text('課程不存在')));

    final dateFormat = DateFormat('MM/dd (E)', 'zh_TW');
    final timeFormat = DateFormat('HH:mm');

    return Scaffold(
      appBar: AppBar(title: Text(_course!.title)),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // 1. 課程資訊區塊 (略，可參考之前的設計)
                Text("選擇上課學員", style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                
                // 2. 多選學員區塊
                Wrap(
                  spacing: 8,
                  children: _myStudents.map((student) {
                    final isSelected = _selectedStudentIds.contains(student.id);
                    return FilterChip(
                      label: Text(student.name),
                      selected: isSelected,
                      avatar: CircleAvatar(child: Text(student.name[0])),
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            _selectedStudentIds.add(student.id);
                          } else {
                            _selectedStudentIds.remove(student.id);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),

                const Divider(height: 32),
                
                Text("選擇上課日期", style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),

                // 3. 多選場次列表
                if (_upcomingSessions.isEmpty) 
                  const Text("目前沒有排定未來場次", style: TextStyle(color: Colors.grey)),
                  
                ..._upcomingSessions.map((session) {
                  final isSelected = _selectedSessionIds.contains(session.id);
                  return CheckboxListTile(
                    title: Text(dateFormat.format(session.startTime)),
                    subtitle: Text("${timeFormat.format(session.startTime)} - ${timeFormat.format(session.endTime)}"),
                    secondary: Text("\$${_course!.price}"),
                    value: isSelected,
                    onChanged: (val) {
                      setState(() {
                        if (val == true) {
                          _selectedSessionIds.add(session.id);
                        } else {
                          _selectedSessionIds.remove(session.id);
                        }
                      });
                    },
                  );
                }),
              ],
            ),
          ),
          
          // 底部按鈕
          SafeArea(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(blurRadius: 5, color: Colors.black12)]),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text("已選: ${_selectedStudentIds.length} 人 x ${_selectedSessionIds.length} 堂"),
                        Text("總計: \$${_selectedStudentIds.length * _selectedSessionIds.length * _course!.price}", 
                             style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.green)),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    onPressed: _isBooking ? null : _onBatchBookPressed,
                    child: _isBooking 
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) 
                      : const Text("批量報名"),
                  )
                ],
              ),
            ),
          )
        ],
      ),
    );
  }
}
