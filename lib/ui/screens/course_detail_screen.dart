import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
// 記得引入你的 Repository 和 Model
import '../../data/services/session_repository.dart';
import '../../data/services/student_repository.dart';

class CourseDetailScreen extends StatefulWidget {
  // 1. 修改這裡：改成接收 SessionModel
  final SessionModel session;

  const CourseDetailScreen({
    super.key, 
    required this.session,
  });

  @override
  State<CourseDetailScreen> createState() => _CourseDetailScreenState();
}

class _CourseDetailScreenState extends State<CourseDetailScreen> {
  final _studentRepo = StudentRepository(Supabase.instance.client);
  final _sessionRepo = SessionRepository(Supabase.instance.client);

  // 🛍️ 搬過來的預約邏輯
  void _onBookPressed() async {
    // 使用 widget.session 來獲取傳入的資料
    final session = widget.session; 

    try {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      final students = await _studentRepo.getMyStudents();
      
      if (!mounted) return;

      if (students.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('請先至「我的 -> 學員管理」新增學員')),
        );
        return;
      }

      showModalBottomSheet(
        context: context,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder: (context) {
          return Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '要幫誰報名 ${session.courseTitle}？',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                ...students.map((student) => ListTile(
                      leading: const CircleAvatar(child: Icon(Icons.person)),
                      title: Text(student.name),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () async {
                        Navigator.pop(context);
                        await Future.delayed(const Duration(milliseconds: 200));
                        if (mounted) {
                          _confirmBooking(session, student.id, student.name);
                        }
                      },
                    )),
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('讀取學員失敗: $e')),
        );
      }
    }
  }

  // 📝 確認預約邏輯
  Future<void> _confirmBooking(SessionModel session, String studentId, String studentName) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      await _sessionRepo.createBooking(sessionId: session.id, studentId: studentId);

      if (!mounted) return;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          if (Navigator.of(context, rootNavigator: true).canPop()) {
            Navigator.of(context, rootNavigator: true).pop();
          }

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ 報名成功！已幫 $studentName 預約'),
              backgroundColor: Colors.green,
            ),
          );
          
          // 預約成功後，可以選擇 pop 回上一頁，或是留在這頁並更新狀態
           Navigator.pop(context);
        }
      });
    } catch (e) {
      if (!mounted) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          if (Navigator.of(context, rootNavigator: true).canPop()) {
            Navigator.of(context, rootNavigator: true).pop();
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('報名失敗: $e'), backgroundColor: Colors.red),
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // 取得傳入的資料
    final session = widget.session;
    final timeFormat = DateFormat('HH:mm');
    final dateStr = DateFormat('yyyy/MM/dd (E)', 'zh_TW').format(session.startTime);

    return Scaffold(
      appBar: AppBar(
        title: const Text('課程詳情'),
      ),
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
                    "這裡可以顯示更多關於此課程的描述、注意事項或是場地資訊。目前暫無詳細說明。",
                    style: TextStyle(color: Colors.grey.shade600, height: 1.5),
                  ),
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
                  onPressed: _onBookPressed,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: const Text(
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
        Text(value, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 15)),
      ],
    );
  }
}
