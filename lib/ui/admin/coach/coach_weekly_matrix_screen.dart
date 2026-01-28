import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:ttmastiff/main.dart'; // 取得全域 repository (sessionRepo, tableRepo, coachRepo)
import 'package:ttmastiff/core/utils/util.dart'; // 取得 showErrorDialog

// Models
import '../../../../data/models/session_model.dart';
import '../../../../data/models/table_model.dart';

// Widgets
import '../courses/widgets/session_edit_dialog.dart';

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

  // 資料快取
  List<SessionModel> _weekSessions = [];
  List<TableModel> _tables = [];
  List<Map<String, dynamic>> _allCoaches = []; // 假設 Repository 回傳 List<Map>

  // 營業時間設定 (可改為讀取設定檔)
  final int _startHour = 9;
  final int _endHour = 22;

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  // 🔄 載入所有資料
  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);
    try {
      // 計算本週範圍
      final start = DateTime(_startDate.year, _startDate.month, _startDate.day);
      final end = start.add(const Duration(days: 7));

      // 平行執行：抓課程 + 抓桌子 + 抓教練
      final results = await Future.wait([
        sessionRepository.fetchSessionsByRange(start, end),
        tableRepository.getTables(),
        coachRepository.getCoaches(),
      ]);

      if (mounted) {
        setState(() {
          _weekSessions = results[0] as List<SessionModel>;
          _tables = results[1] as List<TableModel>;
          // 假設 getCoaches 回傳 List<Map<String, dynamic>>，若回傳 Model 請自行調整
          _allCoaches = List<Map<String, dynamic>>.from(results[2] as List);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        // 🔥 使用 util.dart 的錯誤處理
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
    // 根據標籤篩選教練
    final filteredCoaches = _allCoaches;

    return Scaffold(
      appBar: AppBar(
        title: const Text('教練週排班矩陣'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadAllData),
        ],
      ),
      body: Column(
        children: [
          _buildDateControlBar(),
          const Divider(height: 1),

          // 下方主要內容區域
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : filteredCoaches.isEmpty
                ? const Center(child: Text('沒有符合條件的教練'))
                : _buildMatrixBody(filteredCoaches),
          ),
        ],
      ),
    );
  }

  // 1. 日期控制列
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

  // 3. 矩陣主體 (包含左側固定欄位與右側滑動區)
  Widget _buildMatrixBody(List<Map<String, dynamic>> coaches) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // 判斷是否為寬螢幕 (電腦/平板)
        final bool isWideScreen = constraints.maxWidth > 900;

        // 🔥 這裡設定左側欄位的寬度
        // 手機版縮小為 90，電腦版維持 140
        final double coachColWidth = isWideScreen ? 140.0 : 90.0;

        // 計算右側每個格子的寬度
        final double cellWidth = isWideScreen
            ? (constraints.maxWidth - coachColWidth) /
                  7 // 扣掉左側寬度後平分
            : 140.0; // 手機版右側格子維持好按的大小

        return SingleChildScrollView(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // A. 左側教練欄 (傳入動態寬度)
              _buildCoachColumn(
                coaches,
                coachColWidth,
                isCompact: !isWideScreen,
              ),

              // B. 右側時間格
              Expanded(
                child: isWideScreen
                    ? _buildTimeGrid(
                        coaches,
                        cellWidth,
                        isWideScreen,
                        coachColWidth,
                      )
                    : SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: SizedBox(
                          // 手機版總寬度 = 單格寬度 * 7
                          width: cellWidth * 7,
                          child: _buildTimeGrid(
                            coaches,
                            cellWidth,
                            isWideScreen,
                            coachColWidth,
                          ),
                        ),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  // A. 左側教練列表 UI
  Widget _buildCoachColumn(
    List<Map<String, dynamic>> coaches,
    double width, {
    bool isCompact = false, // 新增參數來控制顯示詳細程度
  }) {
    return Container(
      width: width, // 🔥 使用動態寬度
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(right: BorderSide(color: Colors.grey.shade300)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(4, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          // 表頭
          Container(
            height: 50,
            alignment: Alignment.center,
            color: Colors.grey.shade50,
            child: Text(
              isCompact ? '教練' : '教練 / 日期', // 手機版精簡文字
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
          const Divider(height: 1),

          // 教練名單
          ...coaches.map((coach) {
            final String fullName = coach['full_name'] as String? ?? '未知';
            final String avatarUrl = coach['avatar_url'] as String? ?? '';
            final String firstLetter = fullName.isNotEmpty ? fullName[0] : '?';
            final List<String> tags =
                (coach['tags'] as List?)?.map((e) => e.toString()).toList() ??
                [];

            return Container(
              height: 120, // 固定高度
              width: width,
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // 頭像
                  CircleAvatar(
                    // 🔥 手機版頭像縮小 (半徑 24 -> 20)
                    radius: isCompact ? 20 : 24,
                    backgroundImage: avatarUrl.isNotEmpty
                        ? NetworkImage(avatarUrl)
                        : null,
                    backgroundColor: Colors.blue.shade100,
                    child: avatarUrl.isEmpty
                        ? Text(
                            firstLetter,
                            style: TextStyle(
                              color: Colors.blue.shade800,
                              fontSize: isCompact ? 14 : 16,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(height: 6),

                  // 姓名
                  Text(
                    fullName,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: isCompact ? 12 : 13, // 手機版字體縮小
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),

                  // Tags (手機版空間如果不夠，可以選擇隱藏，或者只顯示一個)
                  if (!isCompact && tags.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        tags.join(', '),
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey.shade600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                    ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // B. 右側日期矩陣 UI
  Widget _buildTimeGrid(
    List<Map<String, dynamic>> coaches,
    double cellWidth,
    bool isWideScreen,
    double coachColWidth,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. X軸：日期 Header
        Row(
          // 如果是寬螢幕，用 mainAxisAlignment.spaceEvenly 或讓子元件 Expanded
          // 這裡我們直接用 Container 指定寬度 (上面的 cellWidth 已經算好了)
          children: List.generate(7, (index) {
            final date = _startDate.add(Duration(days: index));
            final isToday = DateUtils.isSameDay(date, DateTime.now());

            return Container(
              // 🔥 關鍵修改：如果是寬螢幕，這裡的寬度是動態計算的；否則是固定的
              width: cellWidth,
              height: 50,
              alignment: Alignment.center,

              // 🔥 修正 Color 報錯：color 必須放在 BoxDecoration 裡面
              decoration: BoxDecoration(
                color: isToday ? Colors.orange.shade50 : Colors.grey.shade50,
                border: Border(
                  bottom: BorderSide(color: Colors.grey.shade300),
                  right: BorderSide(color: Colors.grey.shade200),
                ),
              ),

              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    DateFormat('MM/dd').format(date),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isToday ? Colors.deepOrange : Colors.black87,
                    ),
                  ),
                  Text(
                    _weekdayName(date.weekday),
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                ],
              ),
            );
          }),
        ),

        // 2. 內容格子 (Y軸：教練 x X軸：日期)
        ...coaches.map((coach) {
          return Row(
            children: List.generate(7, (dayIndex) {
              final date = _startDate.add(Duration(days: dayIndex));
              // 傳入動態寬度
              return _buildCell(coach, date, cellWidth);
            }),
          );
        }),
      ],
    );
  }

  // 修改 _buildCell 以接收寬度
  Widget _buildCell(Map<String, dynamic> coach, DateTime date, double width) {
    final availableSlots = _calculateAvailableSlots(coach['id'], date);

    return Container(
      width: width, // 🔥 使用傳入的寬度
      height: 120,
      decoration: BoxDecoration(
        border: Border(
          right: BorderSide(color: Colors.grey.shade100),
          bottom: BorderSide(color: Colors.grey.shade100),
        ),
      ),
      padding: const EdgeInsets.all(6),
      child: availableSlots.isEmpty
          ? Center(
              child: Text('-', style: TextStyle(color: Colors.grey.shade300)),
            )
          : SingleChildScrollView(
              // 這裡保留 ScrollView 防止按鈕太多爆版
              child: Wrap(
                alignment: WrapAlignment.center, // 讓按鈕置中比較好看
                spacing: 6,
                runSpacing: 6,
                children: availableSlots.map((time) {
                  return InkWell(
                    onTap: () => _handleSlotClick(coach, date, time),
                    borderRadius: BorderRadius.circular(4),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: Text(
                        '${time.hour.toString().padLeft(2, '0')}:00',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade800,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
    );
  }

  // 🧮 核心演算法：計算空檔
  List<TimeOfDay> _calculateAvailableSlots(String coachId, DateTime date) {
    List<TimeOfDay> slots = [];
    final totalTables = _tables.length;

    for (int hour = _startHour; hour < _endHour; hour++) {
      // 確保將 slot 時間也轉為 Local，避免與 DB 傳來的 UTC 發生誤差
      final slotStart = DateTime(date.year, date.month, date.day, hour);
      final slotEnd = slotStart.add(const Duration(hours: 1));

      // 檢查 1: 該教練這小時是否忙碌
      final isCoachBusy = _weekSessions.any((s) {
        if (!s.coachIds.contains(coachId)) return false;

        // 🔄 修正邏輯：計算「重疊時間」長度
        // 1. 找出重疊區間的開始與結束
        final overlapStart = s.startTime.isAfter(slotStart)
            ? s.startTime
            : slotStart;
        final overlapEnd = s.endTime.isBefore(slotEnd) ? s.endTime : slotEnd;

        // 2. 如果「重疊結束時間」大於「重疊開始時間」，代表有實際的時間重疊
        //    (這裡可以容許 0 秒的接觸，例如剛好 19:00 結束與 19:00 開始不算重疊)
        return overlapEnd.isAfter(overlapStart);
      });

      if (isCoachBusy) continue;

      // 檢查 2: 全場館桌子是否滿了 (邏輯同上)
      final activeSessionsCount = _weekSessions.where((s) {
        final overlapStart = s.startTime.isAfter(slotStart)
            ? s.startTime
            : slotStart;
        final overlapEnd = s.endTime.isBefore(slotEnd) ? s.endTime : slotEnd;
        return overlapEnd.isAfter(overlapStart);
      }).length;

      if (activeSessionsCount >= totalTables) continue;

      slots.add(TimeOfDay(hour: hour, minute: 0));
    }
    return slots;
  }

  // 📝 點擊動作：建立新課程 (預填教練、時間、無桌號)
  void _handleSlotClick(
    Map<String, dynamic> coach,
    DateTime date,
    TimeOfDay time,
  ) async {
    final startDateTime = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    final endDateTime = startDateTime.add(const Duration(hours: 1));

    // 🔥 建立符合您 Model 定義的物件
    final newSession = SessionModel(
      id: '', // 新增時為空
      courseId: '', // 待選
      startTime: startDateTime,
      endTime: endDateTime,
      location: '未指定',
      maxCapacity: 1,

      // 關鍵設定：不指定桌子
      tableIds: [],
      tables: [],

      // 自動帶入教練
      coachIds: [coach['id']],
      coachName: coach['full_name'],

      bookingsCount: 0,
      studentNames: [], // 必填空陣列
      sessionPrice: null,
    );

    // 開啟編輯視窗
    final result = await showDialog(
      context: context,
      builder: (context) => SessionEditDialog(
        session: newSession,
        category: 'personal', // 假設電話預約通常是私教
      ),
    );

    // 如果新增成功，重整矩陣
    if (result == true) {
      _loadAllData();
    }
  }

  String _weekdayName(int day) {
    const names = ['週一', '週二', '週三', '週四', '週五', '週六', '週日'];
    return names[day - 1];
  }
}
