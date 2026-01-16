import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:ttmastiff/main.dart';

// 🔥 引入 Models
import '../../../../data/models/course_model.dart';
import '../../../../data/models/session_model.dart';

// 引入 Widgets
import 'widgets/batch_session_dialog.dart';
import 'widgets/session_edit_dialog.dart';
import 'widgets/batch_enroll_dialog.dart';

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
  List<SessionModel> _upcomingSessions = []; // 未來
  List<SessionModel> _historySessions = []; // 歷史
  Map<dynamic, String> _coachMap = {};

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
    if (widget.initialData == null || mounted) {
      setState(() => _isLoading = true);
    }

    try {
      // 1. 如果沒有 initialData，需重新抓取 Course 資訊
      if (widget.initialData == null) {
        final course = await courseRepository.getCourseById(widget.courseId);
        _courseData = course;
      }

      // 2. 抓取 Sessions (Repo 現在回傳 List<SessionModel>)
      final sessions = await sessionRepository.getSessionsByCourse(
        widget.courseId,
      );

      final coachesList = await coachRepository.getCoaches();
      final coachMap = {
        for (var c in coachesList) c['id']: c['full_name'] as String,
      };

      final now = DateTime.now();

      // A. 未來課程：時間 >= 現在
      final upcoming = sessions
          .where((s) => !s.startTime.isBefore(now))
          .toList();
      // 排序：越近的越上面 (升冪)
      upcoming.sort((a, b) => a.startTime.compareTo(b.startTime));

      // B. 歷史課程：時間 < 現在
      final history = sessions.where((s) => s.startTime.isBefore(now)).toList();
      // 排序：剛結束的越上面 (降冪)
      history.sort((a, b) => b.startTime.compareTo(a.startTime));

      if (mounted) {
        setState(() {
          _upcomingSessions = upcoming;
          _historySessions = history;
          _coachMap = coachMap;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('載入失敗: $e')));
      }
    } finally {
      if (mounted) {
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
  // 參數直接接收 SessionModel
  void _editSession(SessionModel s) async {
    final session = s.copyWith(course: _courseData);
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
        await sessionRepository.deleteSession(sessionId);
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

  Future<void> _showBatchEnrollDialog() async {
    if (_upcomingSessions.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('沒有未來的場次可供報名')));
      return;
    }

    final result = await showDialog(
      context: context,
      barrierDismissible: false, // 避免誤觸關閉
      builder: (context) => BatchEnrollDialog(
        courseId: widget.courseId,
        courseTitle: _courseData.title,
        pricePerSession: _courseData.price,
        upcomingSessions: _upcomingSessions, // 只傳入未來場次
      ),
    );

    // 如果有成功報名，刷新頁面資料 (更新人數)
    if (result == true) {
      await _refreshData();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && widget.initialData == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.grey.shade50, // 讓背景稍微灰一點，突顯白色卡片
        appBar: AppBar(
          title: Text(_courseData.title),
          backgroundColor: Colors.white,
          elevation: 0,
          foregroundColor: Colors.black, // 標題黑色
          actions: [
            // 🔥 新增：AppBar 上的批次報名按鈕
            IconButton(
              icon: const Icon(Icons.person_add_alt_1_outlined), // 加入學生的圖示
              tooltip: '批次幫學生報名',
              onPressed: _showBatchEnrollDialog, // 綁定事件
            ),
            const SizedBox(width: 8),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: _openBatchGenerator,
          tooltip: '批量排課', // 滑鼠靠上去會顯示這個文字
          backgroundColor: Colors.blue.shade50, // 建議用顯眼的顏色
          child: const Icon(Icons.add),
        ),
        body: Column(
          children: [
            // 1. 頂部資訊儀表板 (新增的)
            _buildSummaryHeader(),

            // 2. TabBar
            Container(
              color: Colors.white,
              child: const TabBar(
                labelColor: Colors.blue,
                unselectedLabelColor: Colors.grey,
                indicatorColor: Colors.blue,
                tabs: [
                  Tab(text: '即將開始'),
                  Tab(text: '歷史紀錄'),
                ],
              ),
            ),

            // 3. 列表內容
            Expanded(
              child: TabBarView(
                children: [
                  _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _buildSessionList(_upcomingSessions, isHistory: false),
                  _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _buildSessionList(_historySessions, isHistory: true),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSessionCard(SessionModel s, bool isHistory) {
    // 處理教練名字 (若有)
    final coachNames = s.coachIds.map((id) => _coachMap[id] ?? '未知').join(', ');
    final hasCoach = s.coachIds.isNotEmpty;
    final hasStudents = s.studentNames.isNotEmpty;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shadowColor: Colors.black12,
      color: isHistory ? Colors.grey.shade50 : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isHistory ? Colors.transparent : Colors.grey.shade200,
        ),
      ),
      child: Column(
        children: [
          // ─── 卡片 Header (日期與地點) ───
          // 這裡就是原本消失的日期區塊
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              // 歷史紀錄用灰色頭，一般用淡藍色頭
              color: isHistory ? Colors.grey.shade200 : Colors.blue.shade50,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // 左邊：日期
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today,
                      size: 16,
                      color: isHistory ? Colors.grey : Colors.blue.shade700,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      // 記得引入 intl 套件
                      DateFormat('yyyy/MM/dd (E)', 'zh_TW').format(s.startTime),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: isHistory
                            ? Colors.grey.shade600
                            : Colors.blue.shade900,
                      ),
                    ),
                  ],
                ),

                // 右邊：地點 Tag (有最大寬度限制)
                Container(
                  constraints: const BoxConstraints(maxWidth: 140),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.table_restaurant,
                        size: 14,
                        color: Colors.grey.shade600,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        s.tableNames, // ✅ 自動顯示 "A桌、B桌" 或 "未指定"
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ─── 2. 卡片內容 (時間、名額、教練) ───
          Padding(
            padding: const EdgeInsets.all(16),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 左邊區塊：時間與名額
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.access_time,
                              size: 18,
                              color: Colors.black54,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${DateFormat('HH:mm').format(s.startTime)} - ${DateFormat('HH:mm').format(s.endTime)}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(
                              Icons.group,
                              size: 18,
                              color: Colors.black54,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '名額: ${s.maxCapacity} 人',
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // 中間分隔線 (高度會自動跟隨)
                  Container(
                    width: 1,
                    color: Colors.grey.shade200,
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                  ),

                  // 右邊區塊：教練資訊
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '教練',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        hasCoach
                            ? Text(
                                coachNames,
                                style: const TextStyle(
                                  color: Colors.black87,
                                  height: 1.3,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              )
                            : Row(
                                children: [
                                  Icon(
                                    Icons.warning_amber_rounded,
                                    size: 14,
                                    color: Colors.orange.shade300,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '未指定',
                                    style: TextStyle(
                                      color: Colors.orange.shade300,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ─── 3. 底部操作按鈕 (僅非歷史紀錄顯示) ───
          if (hasStudents) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.blue.shade50.withOpacity(0.3), // 淡淡的背景色區隔
                border: Border(top: BorderSide(color: Colors.grey.shade100)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.people_alt,
                        size: 14,
                        color: Colors.blue.shade300,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '已報名學員 (${s.studentNames.length})',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  // 使用 Wrap 自動換行顯示學生名字
                  Wrap(
                    spacing: 8.0, // 水平間距
                    runSpacing: 4.0, // 垂直間距
                    children: s.studentNames.map((name) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: Colors.blue.shade100),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          name,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blue.shade800,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ] else if (!isHistory) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: Colors.grey.shade100)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  Icon(Icons.people_alt, size: 14, color: Colors.grey.shade300),
                  const SizedBox(width: 6),
                  Text(
                    '尚無學員報名',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                  ),
                ],
              ),
            ),
          ],
          if (!isHistory) ...[
            const Divider(height: 1), // 分隔線
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: const Text('編輯'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.grey.shade700,
                    ),
                    onPressed: () => _editSession(s),
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: const Text('刪除'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.red.shade400,
                    ),
                    onPressed: () => _deleteSession(s.id),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // 修改 _buildSessionList，讓它使用新的卡片
  Widget _buildSessionList(
    List<SessionModel> sessions, {
    bool isHistory = false,
  }) {
    if (sessions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_busy, size: 64, color: Colors.grey.shade200),
            const SizedBox(height: 16),
            Text(
              isHistory ? '沒有歷史課程紀錄' : '目前沒有排定的課程',
              style: TextStyle(color: Colors.grey.shade500),
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      // 改用 builder 比較乾淨
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
      itemCount: sessions.length,
      itemBuilder: (context, index) {
        return _buildSessionCard(sessions[index], isHistory);
      },
    );
  }

  Widget _buildSummaryHeader() {
    // 計算統計數據
    final total = _upcomingSessions.length + _historySessions.length;
    final upcoming = _upcomingSessions.length;
    final history = _historySessions.length;

    return Container(
      // 移除過大的 padding 和陰影，改成底色區隔
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          // 1. 課程類型與價格 (左側)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: _courseData.category == 'group'
                          ? Colors.orange.shade50
                          : Colors.purple.shade50,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: _courseData.category == 'group'
                            ? Colors.orange.shade200
                            : Colors.purple.shade200,
                      ),
                    ),
                    child: Text(
                      _courseData.category == 'group' ? '團體班' : '個人班',
                      style: TextStyle(
                        fontSize: 11,
                        color: _courseData.category == 'group'
                            ? Colors.orange.shade800
                            : Colors.purple.shade800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '\$${_courseData.price}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Colors.black87,
                    ),
                  ),
                  const Text(
                    '/堂',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ],
          ),

          // 中間格線
          Container(
            height: 24,
            width: 1,
            color: Colors.grey.shade300,
            margin: const EdgeInsets.symmetric(horizontal: 16),
          ),

          // 2. 統計數據 (右側 - 緊湊排列)
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildCompactStat('總場次', '$total'),
                _buildCompactStat(
                  '待進行',
                  '$upcoming',
                  color: Colors.blue.shade700,
                ),
                _buildCompactStat('已結束', '$history', color: Colors.grey),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 統計小元件
  Widget _buildCompactStat(String label, String value, {Color? color}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color ?? Colors.black87,
          ),
        ),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
      ],
    );
  }
}
