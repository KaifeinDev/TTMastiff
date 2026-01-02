import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // 記得 pubspec.yaml 要有 intl
import 'package:supabase_flutter/supabase_flutter.dart';

// Repositories
import '../../data/services/booking_repository.dart';
import '../../data/services/student_repository.dart';
import '../../data/services/course_repository.dart';
// Models
import '../../data/models/session_model.dart';
import '../../data/models/student_model.dart';

class CourseDetailScreen extends StatefulWidget {
  final String sessionId;

  const CourseDetailScreen({
    super.key, 
    required this.sessionId,
  });

  @override
  State<CourseDetailScreen> createState() => _CourseDetailScreenState();
}

class _CourseDetailScreenState extends State<CourseDetailScreen> {
  late final StudentRepository _studentRepo;
  late final BookingRepository _bookingRepo;
  late final CourseRepository _courseRepo;

  SessionModel? _session;
  bool _isLoading = true;
  bool _isBooking = false;
  String? _errorMsg;

  @override
  void initState() {
    super.initState();
    final client = Supabase.instance.client;
    _studentRepo = StudentRepository(client);
    _bookingRepo = BookingRepository(client);
    _courseRepo = CourseRepository(client);
    
    _loadSessionData();
  }

  Future<void> _loadSessionData() async {
    try {
      final data = await _courseRepo.fetchSessionDetail(widget.sessionId);
      if (mounted) {
        setState(() {
          _session = data;
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

  // 🛍️ 點擊立即預約
  void _onBookPressed() async {
    if (_session == null) return;

    try {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      // 1. 讀取學員
      final students = await _studentRepo.getMyStudents();
      
      if (!mounted) return;

      if (students.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('請先至「我的 -> 學員管理」新增學員')),
        );
        return;
      }
      // 2. 顯示選擇學員視窗
      _showStudentSelectionSheet(students);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('讀取學員失敗: $e')),
        );
      }
    }
  }

  void _showStudentSelectionSheet(List<StudentModel> students) {
    showModalBottomSheet(
        context: context,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (context) {
          return Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('要幫誰報名 ${_session!.courseTitle}？',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                ...students.map((student) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundColor: Colors.blue.shade100,
                        child: Text(student.name[0], style: TextStyle(color: Colors.blue.shade800)),
                      ),
                      title: Text(student.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(student.isPrimary ? '本人' : '學員'),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () async {
                        Navigator.pop(context);

                        await Future.delayed(const Duration(milliseconds: 300));

                        if(mounted){
                            _confirmBooking(student.id, student.name);
                        }
                      },
                    )),
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      );
  }

  Future<void> _confirmBooking(String studentId, String studentName) async {
    setState(() {
      _isBooking = true;
    });

    try {
      await _bookingRepo.createBooking(
        sessionId: _session!.id, 
        studentId: studentId,
        priceSnapshot: _session!.price 
      );
      
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('成功幫 $studentName 報名！'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          )
        );
        Navigator.pop(context); // 回到上一頁 (或首頁)
      }
    } catch (e) {
      if(mounted) {
        setState(() {
          _isBooking = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: Colors.red,
          )
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_errorMsg != null) return Scaffold(appBar: AppBar(), body: Center(child: Text('發生錯誤: $_errorMsg')));
    if (_session == null) return const Scaffold(body: Center(child: Text('找不到課程資料')));

    final session = _session!;
    
    // 格式化日期時間
    final dateFormat = DateFormat('yyyy/MM/dd (E)', 'zh_TW'); // 需要 intl 初始化 locale，若沒設可先用英文格式
    final timeFormat = DateFormat('HH:mm');
    final dateStr = dateFormat.format(session.startTime);

    return Scaffold(
      appBar: AppBar(title: Text(session.courseTitle)),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 課程標題
                  Text(
                    session.courseTitle,
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  
                  // 價格標籤
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Text(
                      '\$${session.price}',
                      style: TextStyle(
                        fontSize: 18, 
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade800
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 資訊卡片
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      children: [
                        _DetailRow(icon: Icons.calendar_today, label: '日期', value: dateStr),
                        const Divider(height: 24),
                        _DetailRow(
                          icon: Icons.access_time, 
                          label: '時間', 
                          value: '${timeFormat.format(session.startTime)} - ${timeFormat.format(session.endTime)}'
                        ),
                        const Divider(height: 24),
                        // 這裡會顯示我們剛剛新增的教練名字
                        _DetailRow(icon: Icons.person, label: '教練', value: session.coachesText),
                        const Divider(height: 24),
                        _DetailRow(
                          icon: Icons.category, 
                          label: '類型', 
                          value: session.category == 'personal' ? '個人班' : '團體班'
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  const Text(
                    "課程說明",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    // 這裡改為讀取 DB 中的 description，若無則顯示預設文字
                    (session.description != null && session.description!.isNotEmpty) 
                        ? session.description! 
                        : "目前暫無詳細說明。",
                    style: TextStyle(color: Colors.grey.shade600, height: 1.5),
                  ),
                  
                  // 底部留白，避免內容被按鈕遮住
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),

          // 底部固定按鈕
          SafeArea(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isBooking ? null : _onBookPressed,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: _isBooking ?
                  const SizedBox(
                    width: 24, height: 24,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                  )
                  :
                  const Text(
                    "立即預約",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// 提取出來的 Widget，避免 build 方法太亂
class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey.shade600),
        const SizedBox(width: 12),
        Text(
          label,
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey.shade600,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
