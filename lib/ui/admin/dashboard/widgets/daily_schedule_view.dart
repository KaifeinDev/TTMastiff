import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:ttmastiff/main.dart'; // 取得全域 supabase/sessionRepository
import '../../../../data/models/session_model.dart';
import '../../../../data/models/table_model.dart';
import '../../courses/widgets/session_edit_dialog.dart';

class DailyScheduleView extends StatefulWidget {
  const DailyScheduleView({super.key});

  @override
  State<DailyScheduleView> createState() => _DailyScheduleViewState();
}

class _DailyScheduleViewState extends State<DailyScheduleView> {
  // 狀態變數
  Map<String, String> _coachMap = {}; // ID -> Name
  DateTime _selectedDate = DateTime.now();
  List<TableModel> _tables = [];
  List<SessionModel> _sessions = [];
  bool _isLoading = true;

  // 🔥 [UI 參數設定] 加大尺寸，讓畫面更清楚
  final double _hourHeight = 110.0; // 每小時的高度 (原本 80 -> 110)
  final double _headerHeight = 50.0; // 桌名列高度
  final double _timeColumnWidth = 60.0; // 左側時間欄寬度
  final double _tableColumnWidth = 160.0; // 每一桌的寬度 (原本 120 -> 160)
  final int _startHour = 8; // 顯示起始時間 (08:00)
  final int _endHour = 23; // 顯示結束時間 (23:00)

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  /// 🔄 載入資料
  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      // 1. 載入所有桌子 (作為行事曆的 Columns)
      final tablesData = await tableRepository.getTables();

      final activeTables = tablesData.where((t) => t.isActive).toList();

      // 2. 載入當日課程
      // 🔥 改用 Repository 載入，因為它處理了 table_ids 的手動關聯 (Manual Join)
      final sessions = await sessionRepository.fetchSessionsByDate(
        _selectedDate,
      );

      // 3. 載入教練名稱 (為了在卡片上顯示人名)
      final Set<String> allCoachIds = {};
      for (var s in sessions) {
        allCoachIds.addAll(s.coachIds);
      }

      final coachesList = await coachRepository.getCoaches();
      final Map<String, String> coachMap = {};

      for (var coach in coachesList) {
        // 依照您的 Repository 回傳格式調整
        // 假設是 Map: coach['id'], coach['full_name']
        // 假設是 Model: coach.id, coach.name
        final id = coach['id'] as String;
        final name = coach['full_name'] as String? ?? '未知教練';
        coachMap[id] = name;
      }

      if (mounted) {
        setState(() {
          _tables = activeTables;
          _sessions = sessions;
          _coachMap = coachMap;
        });
      }
    } catch (e) {
      debugPrint('Error loading schedule: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('載入失敗: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 📅 選擇日期 (日曆彈窗)
  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2024),
      lastDate: DateTime(2030),
      locale: const Locale('zh', 'TW'),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
      _loadData();
    }
  }

  void _changeDate(int days) {
    setState(() => _selectedDate = _selectedDate.add(Duration(days: days)));
    _loadData();
  }

  // ✏️ 開啟編輯視窗
  void _openSessionEdit(SessionModel session) async {
    final result = await showDialog(
      context: context,
      builder: (_) =>
          SessionEditDialog(session: session, category: session.category),
    );

    // 如果有修改或刪除，重新整理
    if (result == true) {
      _loadData();
    }
  }

  // 取得教練名稱字串
  String _getCoachNames(SessionModel session) {
    // 情況 A: Repository 已經幫忙 Join 好 CoachModel 了 (最好的情況)
    if (session.coaches.isNotEmpty) {
      return session.coaches.map((c) => c.name).join(', ');
    }

    // 情況 B: 只有 coachIds，需要去查 _coachMap (次佳方案)
    if (session.coachIds.isNotEmpty) {
      return session.coachIds.map((id) => _coachMap[id] ?? '未知教練').join(', ');
    }

    return '未指定教練';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_tables.isEmpty) return const Center(child: Text('無桌次資料'));

    final totalHours = _endHour - _startHour;
    final contentHeight = totalHours * _hourHeight;
    final totalWidth = _timeColumnWidth + (_tables.length * _tableColumnWidth);

    String _weekdayName(int day) {
      const names = ['一', '二', '三', '四', '五', '六', '日'];
      return names[day - 1];
    }

    return Column(
      children: [
        // --- 頂部：日期控制列 ---
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: Colors.white,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: () => _changeDate(-1),
              ),
              InkWell(
                onTap: _pickDate,
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      '${_selectedDate.year}/${_selectedDate.month}/${_selectedDate.day} (${_weekdayName(_selectedDate.weekday)})',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18, // 字體加大
                      ),
                    ),
                    if (_selectedDate.day == DateTime.now().day)
                      const Padding(
                        padding: EdgeInsets.only(left: 8.0),
                        child: Text(
                          '(今天)',
                          style: TextStyle(
                            color: Colors.blue,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: () => _changeDate(1),
              ),
              IconButton(
                icon: const Icon(Icons.refresh, size: 20),
                onPressed: _loadData,
                tooltip: '刷新',
              ),
            ],
          ),
        ),

        // --- 主內容：行事曆表格 ---
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.vertical,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: totalWidth,
                height: _headerHeight + contentHeight,
                child: Stack(
                  children: [
                    // 1. Header (桌名)
                    Positioned(
                      top: 0,
                      left: _timeColumnWidth,
                      right: 0,
                      height: _headerHeight,
                      child: Row(
                        children: _tables
                            .map(
                              (t) => Container(
                                width: _tableColumnWidth,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  border: Border(
                                    right: BorderSide(
                                      color: Colors.grey.shade300,
                                    ),
                                    bottom: BorderSide(
                                      color: Colors.grey.shade300,
                                    ),
                                  ),
                                ),
                                child: Text(
                                  t.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ),

                    // 2. 時間軸 (左側)
                    Positioned(
                      top: _headerHeight,
                      left: 0,
                      width: _timeColumnWidth,
                      height: contentHeight,
                      child: Column(
                        children: List.generate(
                          totalHours,
                          (i) => Container(
                            height: _hourHeight,
                            alignment: Alignment.topCenter,
                            padding: const EdgeInsets.only(top: 4),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              border: Border(
                                top: BorderSide(color: Colors.grey.shade200),
                              ),
                            ),
                            child: Text(
                              '${_startHour + i}:00',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                    // 3. 格線與內容
                    Positioned(
                      top: _headerHeight,
                      left: _timeColumnWidth,
                      width: totalWidth - _timeColumnWidth,
                      height: contentHeight,
                      child: Stack(
                        children: [
                          // 背景格線
                          Column(
                            children: List.generate(
                              totalHours,
                              (i) => Container(
                                height: _hourHeight,
                                decoration: BoxDecoration(
                                  border: Border(
                                    top: BorderSide(
                                      color: Colors.grey.shade200,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Row(
                            children: _tables
                                .map(
                                  (_) => Container(
                                    width: _tableColumnWidth,
                                    decoration: BoxDecoration(
                                      border: Border(
                                        right: BorderSide(
                                          color: Colors.grey.shade100,
                                        ),
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                          ),

                          // 🔥 4. 課程卡片 (支援一堂課佔用多桌)
                          ..._sessions.expand((session) {
                            // 防呆：如果這堂課沒有桌子資料，就不畫
                            if (session.tables.isEmpty) return <Widget>[];

                            // 針對這堂課的「每一張桌子」，都生成一個 Positioned Card
                            return session.tables.map((table) {
                              // A. 找出這張桌子是第幾欄 (用來計算水平 left 位置)
                              final tableIdx = _tables.indexWhere(
                                (t) => t.id == table.id,
                              );

                              // 如果這張桌子不在目前顯示的 columns 裡 (例如已被停用)，就不畫
                              if (tableIdx == -1) return const SizedBox();

                              // B. 計算垂直位置 (top) 與高度 (height)
                              final localStart = session.startTime.toLocal();
                              final localEnd = session.endTime.toLocal();

                              final startMin =
                                  (localStart.hour - _startHour) * 60 +
                                  localStart.minute;
                              final durationMin = localEnd
                                  .difference(localStart)
                                  .inMinutes;

                              // C. 準備顯示內容
                              final coachNames = session.coachIds.isEmpty
                                  ? '未排'
                                  : session.coachIds
                                        .map((id) => _coachMap[id] ?? '未知')
                                        .join('、');

                              // 顏色區分
                              final double left = tableIdx * _tableColumnWidth;
                              final double top = (startMin / 60) * _hourHeight;
                              final double width =
                                  _tableColumnWidth - 4; // 留一點縫隙 (-4)
                              final double height =
                                  (durationMin / 60) * _hourHeight -
                                  4; // 留一點縫隙 (-4)
                              final isPersonal = session.category == 'personal';
                              final accentColor = isPersonal
                                  ? Colors.purple.shade600
                                  : Colors.blue.shade700;
                              final isFull = session.isFull;

                              // D. 繪製卡片
                              return Positioned(
                                top: top,
                                left: left,
                                width: width,
                                height: height,
                                child: GestureDetector(
                                  onTap: () => _openSessionEdit(session),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      // 1. 顏色處理：根據課程類別給色 (或是用 CourseModel 裡的顏色)
                                      color: session.category == 'personal'
                                          ? Colors.orange.withOpacity(0.2)
                                          : Colors.blue.withOpacity(0.2),
                                      border: Border.all(
                                        color: session.category == 'personal'
                                            ? Colors.orange
                                            : Colors.blue,
                                      ),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min, // 內容盡量緊湊
                                      children: [
                                        // 2. 課程名稱 (使用 Getter: courseTitle)
                                        Text(
                                          session.courseTitle,
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.black87,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),

                                        // 3. 教練姓名
                                        // 邏輯：如果 session.coaches 有資料就用它，不然就用 coachIds 去查 _coachMap
                                        Row(
                                          children: [
                                            // 顯示一個小人像 Icon
                                            Icon(
                                              Icons
                                                  .person, // 或是 Icons.sports_gymnastics, Icons.face
                                              size: 12, // 大小跟文字差不多即可
                                              color: Colors.grey.shade700,
                                            ),
                                            const SizedBox(
                                              width: 2,
                                            ), // Icon 跟文字中間留一點縫隙
                                            // 使用 Expanded 讓文字過長時自動省略 (...)
                                            Expanded(
                                              child: Text(
                                                _getCoachNames(session),
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  color: Colors
                                                      .grey
                                                      .shade700, // 稍微加深一點點比較好讀
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const Spacer(), // 把人數推到底部
                                        // 4. 人數統計 (您原本可能有寫，這裡統一用 Model)
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.end,
                                          children: [
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 4,
                                                    vertical: 1,
                                                  ),
                                              decoration: BoxDecoration(
                                                // 額滿變紅色
                                                color:
                                                    session.remainingCapacity ==
                                                        0
                                                    ? Colors.red
                                                    : Colors.transparent,
                                                border: Border.all(
                                                  color:
                                                      session.remainingCapacity ==
                                                          0
                                                      ? Colors.red
                                                      : Colors.grey,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                '${session.bookingsCount}/${session.maxCapacity}',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  // 額滿時文字變白
                                                  color:
                                                      session.remainingCapacity ==
                                                          0
                                                      ? Colors.white
                                                      : Colors.grey.shade700,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            });
                          }).toList(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
