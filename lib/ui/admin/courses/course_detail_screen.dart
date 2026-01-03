import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:ttmastiff/main.dart';

// 🔥 引入 Models
import '../../../../data/models/course_model.dart';
import '../../../../data/models/session_model.dart';

// 引入 Widgets
import 'widgets/batch_session_dialog.dart';
import 'widgets/session_edit_dialog.dart';

class AdminCourseDetailScreen extends StatefulWidget {
  final String courseId;
  // 🔥 改動 1: 這裡接收 CourseModel
  final CourseModel? initialData;

  const AdminCourseDetailScreen({
    super.key,
    required this.courseId,
    this.initialData,
  });

  @override
  State<AdminCourseDetailScreen> createState() =>
      _AdminCourseDetailScreenState();
}

class _AdminCourseDetailScreenState extends State<AdminCourseDetailScreen> {
  // 🔥 改動 2: 使用 Model 儲存狀態
  late CourseModel _courseData;
  List<SessionModel> _sessions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    // 如果有從上一頁傳來資料，先顯示
    if (widget.initialData != null) {
      _courseData = widget.initialData!;
      // 如果有初始資料，就不需要全畫面 Loading，只要 Loading sessions 列表即可
      // 但為了簡單起見，我們還是會在 refreshData 裡設 isLoading
    }
    _refreshData();
  }

  Future<void> _refreshData() async {
    // 如果沒有初始資料，才顯示全頁 loading，否則會有畫面閃爍
    if (widget.initialData == null) {
      setState(() => _isLoading = true);
    }

    try {
      // 1. 如果沒有 initialData，需重新抓取 Course 資訊
      if (widget.initialData == null) {
        final course = await adminRepository.getCourseById(widget.courseId);
        _courseData = course;
      }

      // 2. 抓取 Sessions (Repo 現在回傳 List<SessionModel>)
      final sessions = await adminRepository.getSessionsByCourse(
        widget.courseId,
      );

      if (mounted) {
        setState(() {
          _sessions = sessions;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('載入失敗: $e')));
        setState(() => _isLoading = false);
      }
    }
  }

  // 開啟批次排課對話框
  void _openBatchGenerator() async {
    // Model 的 startTime 是 DateTime，轉成 TimeOfDay
    final defaultStart = TimeOfDay.fromDateTime(_courseData.defaultStartTime);
    final defaultEnd = TimeOfDay.fromDateTime(_courseData.defaultEndTime);

    final result = await showDialog(
      context: context,
      builder: (context) => BatchSessionDialog(
        courseId: widget.courseId,
        defaultStartTime: defaultStart,
        defaultEndTime: defaultEnd,
        category: _courseData.category,
        defaultPrice: _courseData.price,
      ),
    );

    if (result == true) _refreshData();
  }

  // 開啟單場編輯對話框
  // 🔥 改動 3: 參數直接接收 SessionModel
  void _editSession(SessionModel session) async {
    final result = await showDialog(
      context: context,
      builder: (context) =>
          SessionEditDialog(session: session, category: _courseData.category),
    );

    if (result == true) _refreshData();
  }

  // 刪除單場
  Future<void> _deleteSession(String sessionId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('刪除場次'),
        content: const Text('確定要刪除此場次嗎？已報名的學員資料將會受到影響。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('刪除'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await adminRepository.deleteSession(sessionId);
        _refreshData();
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('已刪除場次')));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('刪除失敗: $e')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // 若尚未載入完成且無初始資料
    if (_isLoading && widget.initialData == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // 安全防護：萬一 _courseData 還沒初始化 (雖然邏輯上不該發生)
    // 可以加個簡單判斷或在變數宣告時加上 late 的處理
    // 這裡依賴 initState 的邏輯

    return Scaffold(
      appBar: AppBar(
        title: Text(_courseData.title), // 直接使用屬性
      ),
      body: Column(
        children: [
          // 頂部資訊區
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Colors.blue.shade50,
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${_courseData.category == 'group' ? '團體課' : '個人課'} | \$${_courseData.price}',
                        style: TextStyle(color: Colors.blue.shade700),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '已排定場次：${_sessions.length} 堂',
                        style: TextStyle(
                          color: Colors.blue.shade900,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.calendar_month, size: 18),
                  label: const Text('批次排課'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: _openBatchGenerator,
                ),
              ],
            ),
          ),

          // 列表區
          Expanded(
            child: _sessions.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.event_busy,
                          size: 64,
                          color: Colors.grey.shade300,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          '目前沒有排定的上課日期',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(8),
                    itemCount: _sessions.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final s = _sessions[index];
                      // 🔥 Model 的時間直接是 DateTime，不需要 parse
                      final start = s.startTime;
                      final end = s.endTime;

                      return Card(
                        elevation: 0,
                        color: Colors.white,
                        shape: RoundedRectangleBorder(
                          side: BorderSide(color: Colors.grey.shade200),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.blue.shade100,
                            foregroundColor: Colors.blue.shade800,
                            child: Text(
                              '${start.day}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          title: Text(
                            DateFormat(
                              'yyyy/MM/dd (E)',
                              'zh_TW',
                            ).format(start), // 建議加上 locale
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Text(
                                '${DateFormat('HH:mm').format(start)} - ${DateFormat('HH:mm').format(end)}',
                              ),
                              Text(
                                '桌次: ${s.location ?? "未定"} | 名額: ${s.maxCapacity}',
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          isThreeLine: true,
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(
                                  Icons.edit,
                                  color: Colors.grey,
                                ),
                                onPressed: () => _editSession(s),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete,
                                  color: Colors.redAccent,
                                ),
                                onPressed: () => _deleteSession(s.id),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
