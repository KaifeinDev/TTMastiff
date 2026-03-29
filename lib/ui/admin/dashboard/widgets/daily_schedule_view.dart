import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:ttmastiff/core/utils/util.dart';
import 'package:ttmastiff/main.dart'; // 取得全域 supabase/sessionRepository
import '../../../../data/models/session_model.dart';
import '../../../../data/models/table_model.dart';
import '../../courses/widgets/session_edit_dialog.dart';
import 'dart:async';

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
  Timer? _timer;

  // 🔥 [UI 參數設定] 加大尺寸，讓畫面更清楚
  final double _hourHeight = 90.0; // 每小時的高度 (原本 80 -> 110)
  final double _headerHeight = 45.0; // 桌名列高度
  final double _timeColumnWidth = 50.0; // 左側時間欄寬度
  final double _tableColumnWidth = 110.0; // 每一桌的寬度 (原本 120 -> 160)
  final int _startHour = 8; // 顯示起始時間 (08:00)
  final int _endHour = 23; // 顯示結束時間 (23:00)

  // 🔄 [連動滾動控制器]
  late ScrollController _headerScrollCtrl; // 右上：桌名 (水平)
  late ScrollController _timeScrollCtrl; // 左下：時間 (垂直)
  late ScrollController _contentHorizCtrl; // 右下：內容 (水平)
  late ScrollController _contentVertCtrl; // 右下：內容 (垂直)

  @override
  void initState() {
    super.initState();
    // 初始化控制器
    _headerScrollCtrl = ScrollController();
    _timeScrollCtrl = ScrollController();
    _contentHorizCtrl = ScrollController();
    _contentVertCtrl = ScrollController();

    // 設定連動監聽
    // 1. 水平連動：標題 <-> 內容
    _headerScrollCtrl.addListener(() {
      if (_headerScrollCtrl.position.pixels !=
          _contentHorizCtrl.position.pixels) {
        _contentHorizCtrl.jumpTo(_headerScrollCtrl.position.pixels);
      }
    });
    _contentHorizCtrl.addListener(() {
      if (_contentHorizCtrl.position.pixels !=
          _headerScrollCtrl.position.pixels) {
        _headerScrollCtrl.jumpTo(_contentHorizCtrl.position.pixels);
      }
    });

    // 2. 垂直連動：時間 <-> 內容
    _timeScrollCtrl.addListener(() {
      if (_timeScrollCtrl.position.pixels != _contentVertCtrl.position.pixels) {
        _contentVertCtrl.jumpTo(_timeScrollCtrl.position.pixels);
      }
    });
    _contentVertCtrl.addListener(() {
      if (_contentVertCtrl.position.pixels != _timeScrollCtrl.position.pixels) {
        _timeScrollCtrl.jumpTo(_contentVertCtrl.position.pixels);
      }
    });
    _timer = Timer.periodic(const Duration(seconds: 60), (timer) {
      // 只有當選中的日期是今天，且在營業時間內才刷新，節省效能
      if (_isToday(_selectedDate) && mounted) {
        setState(() {});
      }
    });
    _loadData();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _headerScrollCtrl.dispose();
    _timeScrollCtrl.dispose();
    _contentHorizCtrl.dispose();
    _contentVertCtrl.dispose();
    super.dispose();
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  double _calculateCurrentTimeTop() {
    final now = DateTime.now();

    // 計算從 _startHour (例如 8:00) 開始，過了多少分鐘
    final int minutesFromStart = (now.hour - _startHour) * 60 + now.minute;

    // 將分鐘數轉換為像素高度
    // 公式：(經過的分鐘數 / 60) * 每小時高度
    return (minutesFromStart / 60.0) * _hourHeight;
  }

  bool _shouldShowCurrentTimeLine() {
    if (!_isToday(_selectedDate)) return false; // 如果看的不是今天，就不顯示

    final now = DateTime.now();
    // 如果現在時間早於營業開始，或晚於營業結束，就不顯示
    if (now.hour < _startHour || now.hour >= _endHour) return false;

    return true;
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
      if (mounted) {
        showErrorSnackBar(context, e, prefix: '載入失敗：');
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
    // 情況 A: Repository 已經幫忙填入 coachName 了 (最好的情況)
    if (session.coachName != null && session.coachName!.isNotEmpty) {
      return session.coachName!;
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
    final totalWidth = _timeColumnWidth + (_tables.length * _tableColumnWidth);
    final totalHeight = totalHours * _hourHeight;

    String _weekdayName(int day) {
      const names = ['一', '二', '三', '四', '五', '六', '日'];
      return names[day - 1];
    }

    final platform = Theme.of(context).platform;
    final bool isMobile =
        platform == TargetPlatform.android || platform == TargetPlatform.iOS;

    return Column(
      children: [
        // --- 頂部：日期控制列 ---
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 8,
          ), // 左右間距稍微縮小一點
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 2,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              // 1. 左側：回到今天按鈕
              IconButton(
                icon: const Icon(
                  Icons.today_outlined,
                  color: Colors.blue,
                ), // 用藍色凸顯功能
                tooltip: '回到今天',
                onPressed: () {
                  setState(() => _selectedDate = DateTime.now());
                  _loadData();
                },
              ),

              // 2. 中間：日期切換區 (使用 Expanded 佔滿剩餘空間並置中)
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center, // 讓 < 日期 > 嚴格置中
                  children: [
                    // 左箭頭
                    IconButton(
                      icon: const Icon(Icons.chevron_left),
                      onPressed: () => _changeDate(-1),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(), // 緊湊模式
                      visualDensity: VisualDensity.compact,
                    ),

                    // 日期文字 (彈性縮放)
                    Flexible(
                      child: InkWell(
                        onTap: _pickDate,
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4.0,
                            vertical: 8.0,
                          ),
                          child: FittedBox(
                            // 確保文字過長時自動縮小，不跑版
                            fit: BoxFit.scaleDown,
                            child: Row(
                              children: [
                                // Icon 可以視情況隱藏，這裡留著增加識別度
                                // const Icon(Icons.calendar_month, size: 16, color: Colors.grey),
                                // const SizedBox(width: 4),
                                Text(
                                  '${_selectedDate.year}/${_selectedDate.month}/${_selectedDate.day} (${_weekdayName(_selectedDate.weekday)})',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18, // 主標題字體
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                    // 右箭頭
                    IconButton(
                      icon: const Icon(Icons.chevron_right),
                      onPressed: () => _changeDate(1),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
              ),

              // 3. 右側：刷新按鈕
              IconButton(
                icon: const Icon(Icons.refresh),
                tooltip: '刷新',
                onPressed: _loadData,
              ),
            ],
          ),
        ),

        // 待排定區塊
        _buildPendingSessionBar(),

        // --- 2. 核心排程表 (Excel 佈局) ---
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              // 1. 計算表格實際需要的總寬度
              final double contentWidth =
                  _timeColumnWidth + (_tables.length * _tableColumnWidth);
              final double availableWidth = constraints.maxWidth;

              // 2. 判斷是否需要置中 (當內容寬度 < 螢幕寬度時)
              // 使用 Align(topCenter) 確保垂直方向是靠上的，只有水平方向置中
              final bool shouldCenter = contentWidth < availableWidth;

              // 3. 定義核心內容 Widget (原本的 Column 結構)
              Widget scheduleContent = Column(
                children: [
                  // A. 上半部：左上角空塊 + 右上角桌名 (水平捲動)
                  SizedBox(
                    height: _headerHeight,
                    child: Row(
                      children: [
                        // A-1. 左上角 (固定)
                        Container(
                          width: _timeColumnWidth,
                          color: Colors.grey.shade50,
                          alignment: Alignment.center,
                          child: Text(
                            '時間',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ),
                        // A-2. 右上角 (跟隨內容水平捲動)
                        Expanded(
                          child: ListView.builder(
                            controller: _headerScrollCtrl,
                            scrollDirection: Axis.horizontal,
                            itemCount: _tables.length,
                            physics: const ClampingScrollPhysics(),
                            itemBuilder: (context, index) {
                              final table = _tables[index];
                              return Container(
                                width: _tableColumnWidth,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  border: Border(
                                    right: BorderSide(
                                      color: Colors.grey.shade200,
                                    ),
                                    bottom: BorderSide(
                                      color: Colors.grey.shade300,
                                      width: 2,
                                    ),
                                  ),
                                ),
                                child: Text(
                                  table.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),

                  // B. 下半部：左下角時間 (垂直捲動) + 右下角內容 (雙向捲動)
                  Expanded(
                    child: Row(
                      children: [
                        // B-1. 左下角時間欄 (跟隨內容垂直捲動)
                        SizedBox(
                          width: _timeColumnWidth,
                          child: ListView.builder(
                            controller: _timeScrollCtrl,
                            itemCount: totalHours,
                            physics: const ClampingScrollPhysics(),
                            itemBuilder: (context, index) {
                              return Container(
                                height: _hourHeight,
                                alignment: Alignment.topCenter,
                                padding: const EdgeInsets.only(top: 4),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade50,
                                  border: Border(
                                    bottom: BorderSide(
                                      color: Colors.grey.shade200,
                                    ),
                                    right: BorderSide(
                                      color: Colors.grey.shade300,
                                    ),
                                  ),
                                ),
                                child: Text(
                                  '${_startHour + index}:00',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),

                        // B-2. 右下角核心內容區 (雙向捲動)
                        Expanded(
                          child: ScrollConfiguration(
                            behavior: ScrollConfiguration.of(
                              context,
                            ).copyWith(scrollbars: false),
                            child: Scrollbar(
                              controller: _contentHorizCtrl, // 綁定水平控制器
                              thumbVisibility: !isMobile, // 強制顯示
                              thickness: isMobile ? 0.0 : 10.0,
                              notificationPredicate: (notif) =>
                                  notif.depth == 1,
                              child: Scrollbar(
                                controller: _contentVertCtrl, // 綁定垂直控制器
                                thumbVisibility: !isMobile,
                                thickness: isMobile ? 0.0 : 10.0,
                                // 垂直捲動條監聽直接子元件 (depth == 0)
                                notificationPredicate: (notif) =>
                                    notif.depth == 0,
                                child: SingleChildScrollView(
                                  controller: _contentVertCtrl,
                                  scrollDirection: Axis.vertical,
                                  physics: const ClampingScrollPhysics(),
                                  child: SingleChildScrollView(
                                    controller: _contentHorizCtrl,
                                    scrollDirection: Axis.horizontal,
                                    physics: const ClampingScrollPhysics(),
                                    child: SizedBox(
                                      width:
                                          totalWidth, // 這裡指的是內容的總寬 (tables * width)
                                      height: totalHeight,
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
                                                    bottom: BorderSide(
                                                      color:
                                                          Colors.grey.shade100,
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
                                                          color: Colors
                                                              .grey
                                                              .shade100,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                )
                                                .toList(),
                                          ),
                                          // 課程卡片
                                          ..._buildSessionCards(),

                                          // 🔥 [現在時間紅線]
                                          if (_shouldShowCurrentTimeLine())
                                            Positioned(
                                              top:
                                                  _calculateCurrentTimeTop() -
                                                  5, // 往上提一點，讓線置中於時間點
                                              left: 0,
                                              right: 0,
                                              child: IgnorePointer(
                                                // 確保紅線不會攔截滑鼠點擊
                                                child: Row(
                                                  children: [
                                                    // 1. 紅色圓點 (模擬 Google Calendar 風格)
                                                    Container(
                                                      width: 10,
                                                      height: 10,
                                                      margin:
                                                          const EdgeInsets.only(
                                                            right: 0,
                                                          ),
                                                      decoration: BoxDecoration(
                                                        color: Colors.red,
                                                        shape: BoxShape.circle,
                                                        boxShadow: [
                                                          BoxShadow(
                                                            color: Colors.white,
                                                            spreadRadius: 1,
                                                          ), // 白邊讓它更清楚
                                                        ],
                                                      ),
                                                    ),
                                                    // 2. 貫穿全場的紅線
                                                    Expanded(
                                                      child: Container(
                                                        height: 2,
                                                        color: Colors.red,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );

              // 4. 根據判斷結果回傳 Widget
              if (shouldCenter) {
                // 如果螢幕夠寬，就用 Align(topCenter) + SizedBox 強制限制寬度
                return Align(
                  alignment: Alignment.topCenter, // 保持靠上，水平置中
                  child: SizedBox(
                    width: contentWidth, // 強制寬度 = 表格實際寬度
                    child: scheduleContent,
                  ),
                );
              } else {
                // 如果螢幕不夠寬 (手機)，則填滿並允許捲動
                return scheduleContent;
              }
            },
          ),
        ),
      ],
    );
  }

  // 繪製課程卡片
  List<Widget> _buildSessionCards() {
    return _sessions.expand((session) {
      if (session.tables.isEmpty) return <Widget>[];

      return session.tables.map((table) {
        final tableIdx = _tables.indexWhere((t) => t.id == table.id);
        if (tableIdx == -1) return const SizedBox();

        final localStart = session.startTime.toLocal();
        final localEnd = session.endTime.toLocal();

        // 計算分鐘數與位置
        final startMin =
            (localStart.hour - _startHour) * 60 + localStart.minute;
        final durationMin = localEnd.difference(localStart).inMinutes;

        // 計算尺寸 (防呆 clamp)
        final double left = tableIdx * _tableColumnWidth;
        final double top = (startMin / 60) * _hourHeight;
        final double width = (_tableColumnWidth - 4).clamp(
          0.0,
          double.infinity,
        );
        final double height = ((durationMin / 60) * _hourHeight - 4).clamp(
          0.0,
          double.infinity,
        );

        // 顏色邏輯
        final isPersonal = session.category == 'personal';
        final themeColor = isPersonal ? Colors.orange : Colors.blue;
        final bgColor = themeColor.withOpacity(0.12);
        final borderColor = themeColor.withOpacity(0.3); // 統一邊框色

        return Positioned(
          left: left,
          top: top,
          width: width,
          height: height,
          child: GestureDetector(
            onTap: () => _openSessionEdit(session),
            child: Tooltip(
              // 設定提示文字：包含標題、教練、完整時間、人數
              message:
                  "${session.courseTitle}\n"
                  "教練: ${_getCoachNames(session)}\n"
                  "時間: ${DateFormat('HH:mm').format(localStart)} - ${DateFormat('HH:mm').format(localEnd)}\n"
                  "人數: ${session.bookingsCount}/${session.maxCapacity}",

              // (選填) 自訂 Tooltip 樣式，讓它好看一點
              padding: const EdgeInsets.all(8),
              margin: const EdgeInsets.symmetric(horizontal: 10),
              showDuration: const Duration(seconds: 3), // 手機上顯示久一點
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.8),
                borderRadius: BorderRadius.circular(6),
              ),
              textStyle: const TextStyle(color: Colors.white, fontSize: 12),
              child: Container(
                margin: const EdgeInsets.only(left: 2, top: 2),
                // 1. 外觀設定：統一邊框 + 圓角 (解決報錯關鍵)
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: borderColor, width: 1), // 統一寬度與顏色
                ),
                // 2. 內容裁切：確保左側色條不會超出圓角
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Row(
                    children: [
                      // A. 左側粗色條 (取代原本的 BorderLeft)
                      Container(
                        width: 4,
                        color: themeColor,
                        height: double.infinity,
                      ),

                      // B. 右側主要內容 (LayoutBuilder)
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final h = constraints.maxHeight;

                            // [極小模式] 高度太小，只顯示色點
                            if (h < 25) {
                              return Center(
                                child: Container(
                                  width: 4,
                                  height: 4,
                                  decoration: BoxDecoration(
                                    color: themeColor,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              );
                            }

                            // [標題模式] 高度稍小，只顯示標題
                            if (h < 45) {
                              return Center(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                  ),
                                  child: Text(
                                    session.courseTitle,
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              );
                            }

                            // [完整模式]
                            return Padding(
                              padding: const EdgeInsets.fromLTRB(
                                6,
                                3,
                                4,
                                3,
                              ), // 左邊距稍微加大一點
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // 標題
                                  Text(
                                    session.courseTitle,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),

                                  // 教練
                                  if (h > 60) ...[
                                    const SizedBox(height: 1),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.person,
                                          size: 11,
                                          color: Colors.grey.shade700,
                                        ),
                                        const SizedBox(width: 2),
                                        Expanded(
                                          child: Text(
                                            _getCoachNames(session),
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: Colors.grey.shade800,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],

                                  const Spacer(),

                                  // 底部資訊
                                  if (h > 55)
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          DateFormat(
                                            'HH:mm',
                                          ).format(localStart),
                                          style: TextStyle(
                                            fontSize: 9,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 3,
                                            vertical: 0.5,
                                          ),
                                          decoration: BoxDecoration(
                                            color: session.isFull
                                                ? Colors.red.withOpacity(0.9)
                                                : Colors.white.withOpacity(0.6),
                                            borderRadius: BorderRadius.circular(
                                              3,
                                            ),
                                            border: session.isFull
                                                ? null
                                                : Border.all(
                                                    color: Colors.grey.shade400,
                                                    width: 0.5,
                                                  ),
                                          ),
                                          child: Text(
                                            '${session.bookingsCount}/${session.maxCapacity}',
                                            style: TextStyle(
                                              fontSize: 9,
                                              fontWeight: FontWeight.bold,
                                              color: session.isFull
                                                  ? Colors.white
                                                  : Colors.black87,
                                            ),
                                          ),
                                        ),
                                      ],
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
      });
    }).toList();
  }

  // 🔍 篩選出「待排定」或「資料不完整」的課程
  List<SessionModel> get _pendingSessions {
    return _sessions.where((s) {
      // 條件 1: 沒有分配桌子 (這是最嚴重的，因為會導致在表格上消失)
      final noTable = s.tables.isEmpty;
      // 條件 2: 沒有分配教練 (選用，視你的需求決定這算不算異常)
      final noCoach = s.coachIds.isEmpty;

      return noTable || noCoach;
    }).toList();
  }

  // ⚠️ 建構「待排定課程」的橫幅區域
  Widget _buildPendingSessionBar() {
    final pendingList = _pendingSessions;

    // 如果沒有問題課程，就隱藏這個區塊
    if (pendingList.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      color: Colors.orange.shade50, // 警示色背景
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                size: 16,
                color: Colors.orange.shade800,
              ),
              const SizedBox(width: 6),
              Text(
                '待排定 / 資料不完整 (${pendingList.length})',
                style: TextStyle(
                  color: Colors.orange.shade900,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // 橫向捲動的卡片列表
          SizedBox(
            height: 50, // 固定高度
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: pendingList.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final session = pendingList[index];

                // 判斷缺什麼
                final bool noTable = session.tables.isEmpty;
                final bool noCoach = session.coachIds.isEmpty;
                List<String> missingItems = [];
                if (noTable) missingItems.add("缺桌次");
                if (noCoach) missingItems.add("缺教練");

                return ActionChip(
                  backgroundColor: Colors.white,
                  surfaceTintColor: Colors.white,
                  elevation: 1,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(color: Colors.orange.shade200),
                  ),
                  avatar: CircleAvatar(
                    backgroundColor: Colors.orange.shade100,
                    child: Text(
                      DateFormat('HH:mm').format(session.startTime),
                      style: TextStyle(
                        fontSize: 9,
                        color: Colors.orange.shade900,
                      ),
                    ),
                  ),
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(session.courseTitle),
                      const SizedBox(width: 4),
                      // 顯示缺少的項目標籤
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.red.shade100),
                        ),
                        child: Text(
                          missingItems.join("/"),
                          style: TextStyle(
                            fontSize: 9,
                            color: Colors.red.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  onPressed: () => _openSessionEdit(session), // 點擊直接開啟編輯
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
