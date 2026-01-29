import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:ttmastiff/main.dart';
import 'package:ttmastiff/core/utils/util.dart';
import 'package:ttmastiff/ui/admin/courses/widgets/session_edit_dialog.dart';
// Models
import '../../../../data/models/session_model.dart';

class CoachWeeklyMatrixScreen extends StatefulWidget {
  const CoachWeeklyMatrixScreen({super.key});

  @override
  State<CoachWeeklyMatrixScreen> createState() =>
      _CoachWeeklyMatrixScreenState();
}

class _CoachWeeklyMatrixScreenState extends State<CoachWeeklyMatrixScreen> {
  // 狀態變數
  DateTime _startDate = DateTime.now();
  bool _isLoading = true;

  // 資料
  List<SessionModel> _weekSessions = [];
  List<Map<String, dynamic>> _allCoaches = [];
  Set<String> _selectedCoachIds = {};

  // 設定
  final double _rowHeight = 300.0;
  final double _dateColWidth = 80.0; // 左側日期欄固定寬度
  final double _startHour = 8.0;
  final double _endHour = 22.0;

  // 🔥 捲動控制器 (四個部分連動)
  late ScrollController _headerHorzCtrl; // 上方教練列 (水平)
  late ScrollController _dateVertCtrl; // 左側日期列 (垂直)
  late ScrollController _gridHorzCtrl; // 主格子 (水平)
  late ScrollController _gridVertCtrl; // 主格子 (垂直)

  // 防止無窮迴圈的鎖
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    _initControllers();
    _loadAllData();
  }

  void _initControllers() {
    _headerHorzCtrl = ScrollController();
    _dateVertCtrl = ScrollController();
    _gridHorzCtrl = ScrollController();
    _gridVertCtrl = ScrollController();

    // 1. 水平同步：上方 Header <-> 主格子
    _headerHorzCtrl.addListener(
      () => _syncScroll(_headerHorzCtrl, _gridHorzCtrl),
    );
    _gridHorzCtrl.addListener(
      () => _syncScroll(_gridHorzCtrl, _headerHorzCtrl),
    );

    // 2. 垂直同步：左側日期 <-> 主格子
    _dateVertCtrl.addListener(() => _syncScroll(_dateVertCtrl, _gridVertCtrl));
    _gridVertCtrl.addListener(() => _syncScroll(_gridVertCtrl, _dateVertCtrl));
  }

  // 🔄 通用同步邏輯
  void _syncScroll(ScrollController source, ScrollController target) {
    if (_isSyncing) return; // 如果正在同步中，跳過
    if (!source.hasClients || !target.hasClients) return;

    if (source.offset != target.offset) {
      _isSyncing = true;
      target.jumpTo(source.offset);
      _isSyncing = false;
    }
  }

  @override
  void dispose() {
    _headerHorzCtrl.dispose();
    _dateVertCtrl.dispose();
    _gridHorzCtrl.dispose();
    _gridVertCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);
    try {
      final start = DateTime(_startDate.year, _startDate.month, _startDate.day);
      final end = start.add(const Duration(days: 7));

      final results = await Future.wait([
        sessionRepository.fetchSessionsByRange(start, end),
        coachRepository.getCoaches(),
      ]);

      if (mounted) {
        setState(() {
          _weekSessions = results[0] as List<SessionModel>;
          _allCoaches = List<Map<String, dynamic>>.from(results[1] as List);
          // 🔥 新增：如果是第一次載入（或名單原本是空的），預設全選
          if (_selectedCoachIds.isEmpty && _allCoaches.isNotEmpty) {
            _selectedCoachIds = _allCoaches
                .map((c) => c['id'].toString())
                .toSet();
          } else {
            // 如果已經有選過的紀錄，要確保選單裡面的 ID 還在最新的教練列表中
            // (這步是防呆，避免刪除教練後 ID 還殘留)
            final allIds = _allCoaches.map((c) => c['id'].toString()).toSet();
            _selectedCoachIds = _selectedCoachIds.intersection(allIds);

            // 如果交集後變空了(例如原本選的都被刪了)，那就全選回來
            if (_selectedCoachIds.isEmpty) {
              _selectedCoachIds = allIds;
            }
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        showErrorDialog(context, e, title: '載入資料失敗');
      }
    }
  }

  void _changeWeek(int days) {
    setState(() {
      _startDate = _startDate.add(Duration(days: days));
    });
    _loadAllData();
  }

  @override
  Widget build(BuildContext context) {
    final filteredCoaches = _allCoaches
        .where((c) => _selectedCoachIds.contains(c['id']))
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('教練週排班矩陣'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list_alt),
            tooltip: '篩選教練',
            onPressed: _showCoachFilterDialog,
          ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadAllData),
        ],
      ),
      body: Column(
        children: [
          _buildDateControlBar(),
          const Divider(height: 1),

          // 主體區域
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : filteredCoaches.isEmpty
                ? const Center(child: Text('沒有符合條件的教練'))
                : _buildMatrixLayout(filteredCoaches),
          ),
        ],
      ),
    );
  }

  void _showCoachFilterDialog() {
    showDialog(
      context: context,
      builder: (context) {
        // 使用 StatefulBuilder 讓 Dialog 內部可以局部刷新 Checkbox
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('篩選顯示教練'),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 全選/全不選按鈕 (選用)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            child: const Text('全選'),
                            onPressed: () {
                              setStateDialog(() {
                                _selectedCoachIds = _allCoaches
                                    .map((c) => c['id'].toString())
                                    .toSet();
                              });
                            },
                          ),
                          TextButton(
                            child: const Text('清空'),
                            onPressed: () {
                              setStateDialog(() {
                                _selectedCoachIds.clear();
                              });
                            },
                          ),
                        ],
                      ),
                      const Divider(),
                      // 教練列表
                      ..._allCoaches.map((coach) {
                        final id = coach['id'];
                        final isSelected = _selectedCoachIds.contains(id);
                        return CheckboxListTile(
                          title: Text(coach['full_name'] ?? '未知'),
                          value: isSelected,
                          onChanged: (bool? value) {
                            setStateDialog(() {
                              if (value == true) {
                                _selectedCoachIds.add(id);
                              } else {
                                _selectedCoachIds.remove(id);
                              }
                            });
                          },
                        );
                      }),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    // 關閉 Dialog，並觸發主畫面 setState 更新
                    Navigator.of(context).pop();
                    this.setState(() {});
                  },
                  child: const Text('確定'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildDateControlBar() {
    final endDate = _startDate.add(const Duration(days: 6));
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () => _changeWeek(-7),
          ),
          InkWell(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _startDate,
                firstDate: DateTime(2023),
                lastDate: DateTime(2030),
              );
              if (picked != null) {
                setState(() => _startDate = picked);
                _loadAllData();
              }
            },
            child: Row(
              children: [
                const Icon(
                  Icons.calendar_month_outlined,
                  size: 20,
                  color: Colors.blue,
                ),
                const SizedBox(width: 8),
                Text(
                  '${DateFormat('MM/dd').format(_startDate)} - ${DateFormat('MM/dd').format(endDate)}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () => _changeWeek(7),
          ),
        ],
      ),
    );
  }

  // 🔥 核心佈局：凍結窗格結構
  Widget _buildMatrixLayout(List<Map<String, dynamic>> coaches) {
    final borderSide = BorderSide(color: Colors.grey.shade300, width: 1);

    return LayoutBuilder(
      builder: (context, constraints) {
        // 1. 取得右側可用總寬度
        double availableWidth = constraints.maxWidth - _dateColWidth;

        // 2. 設定最小寬度門檻 (例如每個教練至少要有 120~150px)
        const double minCellWidth = 140.0;

        // 3. 計算單格寬度邏輯
        double cellWidth;
        double totalCoachesMinWidth = coaches.length * minCellWidth;

        if (totalCoachesMinWidth <= availableWidth) {
          // A. 【電腦版/教練少】：如果所有教練排排站都還塞得進去
          // -> 直接平分剩餘空間，讓表格填滿畫面
          // (防呆：避免除以 0，雖然前面有檢查 isEmpty)
          cellWidth = availableWidth / (coaches.isEmpty ? 1 : coaches.length);
        } else {
          // B. 【手機版/教練多】：塞不下，需要捲動
          // -> 計算一頁能顯示幾個 (Mobile 至少顯示 2 個)
          int visibleCount = (availableWidth / minCellWidth).floor();
          if (visibleCount < 2) visibleCount = 2;

          cellWidth = availableWidth / visibleCount;
        }

        return Column(
          children: [
            // 1. 上方 Header Row (左上角固定塊 + 右側可滑動教練列)
            SizedBox(
              height: 50,
              child: Row(
                children: [
                  // 左上角固定塊
                  Container(
                    width: _dateColWidth,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      border: Border(bottom: borderSide, right: borderSide),
                    ),
                    child: const Text(
                      '日期',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ),
                  // 右側教練列表
                  Expanded(
                    child: SingleChildScrollView(
                      controller: _headerHorzCtrl,
                      scrollDirection: Axis.horizontal,
                      physics: const ClampingScrollPhysics(),
                      child: Row(
                        children: coaches.map((coach) {
                          return _buildCoachHeaderCell(
                            coach,
                            cellWidth,
                            borderSide,
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // 2. 下方 Body Row (左側日期列 + 右側雙向滑動矩陣)
            Expanded(
              child: Row(
                children: [
                  // 左側日期直欄
                  SizedBox(
                    width: _dateColWidth,
                    child: SingleChildScrollView(
                      controller: _dateVertCtrl,
                      scrollDirection: Axis.vertical,
                      physics: const ClampingScrollPhysics(),
                      child: Column(
                        children: List.generate(7, (index) {
                          return _buildDateCell(index, borderSide);
                        }),
                      ),
                    ),
                  ),

                  // 右側主矩陣
                  Expanded(
                    child: SingleChildScrollView(
                      controller: _gridVertCtrl,
                      scrollDirection: Axis.vertical,
                      physics: const ClampingScrollPhysics(),
                      child: SingleChildScrollView(
                        controller: _gridHorzCtrl,
                        scrollDirection: Axis.horizontal,
                        physics: const ClampingScrollPhysics(),
                        child: Column(
                          children: List.generate(7, (dayIndex) {
                            final date = _startDate.add(
                              Duration(days: dayIndex),
                            );
                            final isToday = DateUtils.isSameDay(
                              date,
                              DateTime.now(),
                            );

                            return Row(
                              children: coaches.map((coach) {
                                return _buildTimelineCell(
                                  coach,
                                  date,
                                  cellWidth,
                                  borderSide,
                                  isToday: isToday,
                                );
                              }).toList(),
                            );
                          }),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  // 元件：單個教練 Header
  Widget _buildCoachHeaderCell(
    Map<String, dynamic> coach,
    double width,
    BorderSide border,
  ) {
    return Container(
      width: width,
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        border: Border(bottom: border, right: border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 14,
            backgroundImage:
                (coach['avatar_url'] != null && coach['avatar_url'].isNotEmpty)
                ? NetworkImage(coach['avatar_url'])
                : null,
            child: (coach['avatar_url'] == null || coach['avatar_url'].isEmpty)
                ? Text(
                    coach['full_name']?[0] ?? '?',
                    style: const TextStyle(fontSize: 10),
                  )
                : null,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              coach['full_name'] ?? '未知',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // 元件：單個日期 Cell (包含 Apple Calendar 風格時間刻度)
  Widget _buildDateCell(int index, BorderSide border) {
    final date = _startDate.add(Duration(days: index));
    final isToday = DateUtils.isSameDay(date, DateTime.now());

    return Container(
      height: _rowHeight,
      width: _dateColWidth,
      decoration: BoxDecoration(
        color: isToday ? Colors.orange.shade50.withOpacity(0.5) : Colors.white,
        border: Border(bottom: border, right: border),
      ),
      child: Stack(
        // 2. 修改：允許溢出，解決底部時間被切掉的問題
        clipBehavior: Clip.none,
        children: [
          // 3. 修改：日期靠左，與右側的時間刻度拉開距離
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(left: 12.0), // 左側留點空隙
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center, // 日期本身還是置中對齊
                children: [
                  Text(
                    DateFormat('dd').format(date),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isToday ? Colors.deepOrange : Colors.black87,
                      fontSize: 18,
                    ),
                  ),
                  Text(
                    DateFormat('MM月').format(date),
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: isToday
                        ? BoxDecoration(
                            color: Colors.deepOrange,
                            borderRadius: BorderRadius.circular(10),
                          )
                        : null,
                    child: Text(
                      _weekdayName(date.weekday),
                      style: TextStyle(
                        fontSize: 11,
                        color: isToday ? Colors.white : Colors.grey.shade600,
                        fontWeight: isToday
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // 時間刻度 (右側)
          ..._buildSideTimeLabels(),
        ],
      ),
    );
  }

  List<Widget> _buildSideTimeLabels() {
    final double totalHours = _endHour - _startHour;
    List<Widget> labels = [];

    for (double h = _startHour; h <= _endHour; h += 2) {
      if (h == _startHour || h == _endHour) continue;
      final double top = (h - _startHour) / totalHours * _rowHeight;

      labels.add(
        Positioned(
          top: top - 6, // 讓文字中心對齊線條
          right: 6, // 保持右側間距
          child: Text(
            "${h.toInt()}",
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey.shade400,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      );
    }
    return labels;
  }

  // 元件：主內容格子
  Widget _buildTimelineCell(
    Map<String, dynamic> coach,
    DateTime date,
    double width,
    BorderSide border, {
    required bool isToday,
  }) {
    final coachSessions = _weekSessions.where((s) {
      return s.coachIds.contains(coach['id']) &&
          DateUtils.isSameDay(s.startTime, date);
    }).toList();

    return Container(
      width: width,
      height: _rowHeight,
      decoration: BoxDecoration(
        color: isToday ? Colors.orange.shade50.withOpacity(0.3) : Colors.white,
        border: Border(bottom: border, right: border),
      ),
      child: Stack(
        children: [
          _buildBackgroundGridLines(isToday: isToday),
          ...coachSessions.map(
            (session) => _buildSessionBlock(session, _rowHeight),
          ),
        ],
      ),
    );
  }

  Widget _buildBackgroundGridLines({required bool isToday}) {
    final double totalHours = _endHour - _startHour;
    List<Widget> lines = [];
    for (double h = _startHour; h <= _endHour; h += 2) {
      if (h == _startHour) continue;
      final double top = (h - _startHour) / totalHours * _rowHeight;
      lines.add(
        Positioned(
          top: top,
          left: 0,
          right: 0,
          child: Container(
            height: 1,
            color: isToday ? Colors.grey.shade200 : Colors.grey.shade100,
          ),
        ),
      );
    }
    return Stack(children: lines);
  }

  Widget _buildSessionBlock(SessionModel session, double totalHeight) {
    final double totalHours = _endHour - _startHour;
    double sessionStart =
        session.startTime.hour + (session.startTime.minute / 60.0);
    double sessionEnd = session.endTime.hour + (session.endTime.minute / 60.0);

    if (sessionStart < _startHour) sessionStart = _startHour;
    if (sessionEnd > _endHour) sessionEnd = _endHour;
    if (sessionStart >= sessionEnd) return const SizedBox();

    final double topPercent = (sessionStart - _startHour) / totalHours;
    final double durationPercent = (sessionEnd - sessionStart) / totalHours;
    final double blockHeight = durationPercent * totalHeight;

    final isPersonal = session.category == 'personal';
    final themeColor = isPersonal ? Colors.orange : Colors.blue;
    final bgColor = themeColor.withOpacity(0.15);
    final borderColor = themeColor.withOpacity(0.4);

    final String courseTimeStr =
        "${DateFormat('HH:mm').format(session.startTime)} - ${DateFormat('HH:mm').format(session.endTime)}";
    final String studentText = (session.studentNames.isNotEmpty)
        ? session.studentNames.join(', ')
        : '無指定學生';
    final String tooltipMsg =
        "${session.courseTitle}\n$courseTimeStr\n學生: $studentText";

    return Positioned(
      top: topPercent * totalHeight,
      height: blockHeight,
      left: 2,
      right: 2,
      child: Tooltip(
        message: tooltipMsg,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.black87,
          borderRadius: BorderRadius.circular(4),
        ),
        textStyle: const TextStyle(color: Colors.white, fontSize: 12),
        child: InkWell(
          onTap: () async {
            // 1. 開啟編輯視窗
            // 請確保你的 SessionEditDialog 支援傳入 session 進行編輯模式
            // 如果你的 Dialog 需要 'onSave' callback，也可以在這裡處理
            await showDialog(
              context: context,
              builder: (context) => SessionEditDialog(
                session: session,
                category: session.course!.category,
              ),
            );

            // 2. 視窗關閉後，重新載入資料 (因為可能被修改或刪除了)
            _loadAllData();
          },
          child: Container(
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: borderColor, width: 1),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Row(
                children: [
                  Container(
                    width: 3,
                    color: themeColor,
                    height: double.infinity,
                  ),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final h = constraints.maxHeight;
                        if (h < 18) return const SizedBox();
                        if (h < 32) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Row(
                              children: [
                                Text(
                                  courseTimeStr,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    session.courseTitle,
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.black87,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }
                        return Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 2,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                courseTimeStr,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                  height: 1.0,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                session.courseTitle,
                                style: TextStyle(
                                  fontSize: 9,
                                  color: Colors.black87,
                                  height: 1.0,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _weekdayName(int day) {
    const names = ['週一', '週二', '週三', '週四', '週五', '週六', '週日'];
    return names[day - 1];
  }
}
