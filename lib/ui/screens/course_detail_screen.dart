import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Repositories
import 'package:ttmastiff/data/services/course_repository.dart';
import 'package:ttmastiff/data/services/student_repository.dart';
// Models
import 'package:ttmastiff/data/models/session_model.dart';
import 'package:ttmastiff/data/models/student_model.dart';

class CourseDetailScreen extends StatefulWidget {
  final String sessionId;

  const CourseDetailScreen({super.key, required this.sessionId});

  @override
  State<CourseDetailScreen> createState() => _CourseDetailScreenState();
}

class _CourseDetailScreenState extends State<CourseDetailScreen> {
  late final CourseRepository _courseRepo;
  late final StudentRepository _studentRepo;
  
  SessionModel? _session;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final client = Supabase.instance.client;
    _courseRepo = CourseRepository(client);
    _studentRepo = StudentRepository(client);
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final session = await _courseRepo.fetchSessionDetail(widget.sessionId);
      if (mounted) {
        setState(() {
          _session = session;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  // --- 報名邏輯 ---
  void _onBookPressed() async {
    if (_session == null) return;
    
    // 1. 檢查額滿
    if (_session!.bookingsCount >= _session!.maxCapacity) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('課程已額滿')));
      return;
    }

    try {
      // 2. 讀取學員
      final students = await _studentRepo.getMyStudents();
      if (!mounted) return;

      if (students.isEmpty) {
         ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('查無學員資料，請先至個人檔案建立')),
        );
        return;
      }

      // 3. 顯示選擇選單
      _showStudentSelectionSheet(students);

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('無法取得學員資料: $e')),
      );
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
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('請選擇上課學員', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: students.length,
                  separatorBuilder: (_, __) => const Divider(),
                  itemBuilder: (context, index) {
                    final student = students[index];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundColor: Colors.blue[100],
                        child: Text(student.name.isNotEmpty ? student.name[0] : 'S',
                            style: TextStyle(color: Colors.blue[800])),
                      ),
                      title: Text(student.name, style: const TextStyle(fontSize: 16)),
                      subtitle: Text(student.isPrimary ? '本人' : '親友', style: const TextStyle(color: Colors.grey)),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                      onTap: () {
                        Navigator.pop(context); // 關閉 Sheet
                        _processBooking(student); 
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _processBooking(StudentModel student) async {
    // 這裡連接 BookingRepository (尚未實作，先顯示提示)
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('正在為 ${student.name} 報名... (功能開發中)')),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    
    if (_errorMessage != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('課程詳情')),
        body: Center(child: Text('讀取失敗: $_errorMessage')),
      );
    }
    
    final session = _session!;
    final course = session.course!;
    
    final dateFmt = DateFormat('yyyy/MM/dd (E)', 'zh_TW');
    final timeFmt = DateFormat('HH:mm');
    
    final dateStr = dateFmt.format(session.startTime);
    final timeStr = '${timeFmt.format(session.startTime)} - ${timeFmt.format(session.endTime)}';
    
    final coachNames = session.coaches.isNotEmpty
        ? session.coaches.map((c) => c.name).join(', ')
        : '待定';

    final bool isFull = session.bookingsCount >= session.maxCapacity;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // 頂部圖片 (保留 home.txt 的 Sliver 風格)
          SliverAppBar(
            expandedHeight: 250.0,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                course.title, 
                style: const TextStyle(
                  color: Colors.white, 
                  shadows: [Shadow(blurRadius: 10, color: Colors.black)]
                )
              ),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  course.imageUrl != null
                      ? Image.network(course.imageUrl!, fit: BoxFit.cover)
                      : Container(color: Colors.blueGrey),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.black54],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // 內容
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 標籤與價格
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.blue[100]!),
                        ),
                        child: Text(
                          course.category == 'personal' ? '一對一' : '團體課',
                          style: TextStyle(color: Colors.blue[800], fontSize: 14),
                        ),
                      ),
                      Text(
                        'NT\$ ${course.price}',
                        style: TextStyle(
                          fontSize: 22, 
                          fontWeight: FontWeight.bold, 
                          color: Theme.of(context).primaryColor
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // 資訊列 (使用下方的 _DetailRow 元件)
                  _DetailRow(icon: Icons.calendar_today, label: '日期', value: dateStr),
                  const SizedBox(height: 16),
                  _DetailRow(icon: Icons.access_time, label: '時間', value: timeStr),
                  const SizedBox(height: 16),
                  _DetailRow(icon: Icons.location_on, label: '地點', value: session.location ?? '地點未定'),
                  const SizedBox(height: 16),
                  _DetailRow(icon: Icons.person_outline, label: '教練', value: coachNames),
                  const SizedBox(height: 16),
                  
                  // 名額顯示 (如果是滿的顯示紅色)
                  Row(
                    children: [
                      Icon(Icons.group, size: 20, color: isFull ? Colors.red : Colors.grey),
                      const SizedBox(width: 12),
                      const Text('名額', style: TextStyle(color: Colors.grey, fontSize: 15)),
                      const Spacer(),
                      Text(
                        '${session.bookingsCount} / ${session.maxCapacity}',
                        style: TextStyle(
                          fontWeight: FontWeight.w500, 
                          fontSize: 15,
                          color: isFull ? Colors.red : Colors.black
                        ),
                      ),
                    ],
                  ),
                  
                  const Divider(height: 40),
                  
                  const Text('課程介紹', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(
                    course.description ?? '暫無詳細介紹',
                    style: TextStyle(fontSize: 15, color: Colors.grey[800], height: 1.6),
                  ),
                  
                  const SizedBox(height: 100), // 底部留白
                ],
              ),
            ),
          ),
        ],
      ),
      
      // 底部懸浮按鈕 (保留 home.txt 的風格)
      bottomNavigationBar: Container(
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
        child: SafeArea(
          child: SizedBox(
            height: 50,
            child: ElevatedButton(
              onPressed: isFull ? null : _onBookPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: isFull ? Colors.grey : Theme.of(context).primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: Text(
                isFull ? '已額滿' : '立即預約',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// 抽取出來的資訊列元件 (參考 home.txt)
class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey),
        const SizedBox(width: 12),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 15)),
        const Spacer(),
        Expanded(
          flex: 2,
          child: Text(
            value, 
            textAlign: TextAlign.end,
            style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 15)
          ),
        ),
      ],
    );
  }
}
