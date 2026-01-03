import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/models/booking_model.dart';
import '../../data/services/booking_repository.dart';

class MyBookingScreen extends StatefulWidget {
  const MyBookingScreen({super.key});

  @override
  State<MyBookingScreen> createState() => _MyBookingScreenState();
}

// use in _fetchBooking
class DaySection {
  final DateTime date;
  final List<List<BookingModel>> sessionGroups; // 這一天裡面的「場次群組」

  DaySection({required this.date, required this.sessionGroups});
}

class _MyBookingScreenState extends State<MyBookingScreen>
    with SingleTickerProviderStateMixin {
  late final BookingRepository _bookingRepo;
  late TabController _tabController;

  bool _isLoading = true;

  // 🔥 改用 Map 來分組：Key 是 Session ID，Value 是該場次的所有預約 (不同小孩)
  List<List<BookingModel>> _upcomingGroups = [];
  List<BookingModel> _historyBookings = []; // 歷史紀錄通常維持流水帳即可，或依需求分組

  @override
  void initState() {
    super.initState();
    _bookingRepo = BookingRepository(Supabase.instance.client);
    BookingRepository.bookingRefreshSignal.addListener(_fetchBookings);
    _tabController = TabController(length: 2, vsync: this);
    _fetchBookings();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // 在 State 裡面宣告這個變數取代原本的 List
  List<DaySection> _groupedSections = [];

  Future<void> _fetchBookings() async {
    setState(() => _isLoading = true);
    try {
      final bookings = await _bookingRepo.fetchMyBookings();
      final now = DateTime.now();

      // 1. 分離 未來 vs 歷史
      final rawUpcoming = <BookingModel>[];
      final rawHistory = <BookingModel>[];

      for (var booking in bookings) {
        final isEnd =
            booking.endTime.isBefore(now) ||
            booking.endTime.isAtSameMomentAs(now);
        final isCancelled = booking.status == 'cancelled';

        if (isCancelled || isEnd) {
          rawHistory.add(booking);
        } else {
          rawUpcoming.add(booking);
        }
      }

      // 照時間排序
      rawUpcoming.sort((a, b) => a.startTime.compareTo(b.startTime));

      // 2. 進行日期分組 Map
      final Map<String, List<BookingModel>> dateMap = {};

      for (var booking in rawUpcoming) {
        // 產生 Key: "2026-01-06"
        final dateKey = DateFormat('yyyy-MM-dd').format(booking.startTime);
        if (!dateMap.containsKey(dateKey)) {
          dateMap[dateKey] = [];
        }
        dateMap[dateKey]!.add(booking);
      }

      // 3. 轉換成 DaySection 結構
      final List<DaySection> sections = [];

      dateMap.forEach((dateKey, bookingsInDay) {
        // 在每一天裡面，再依 Session ID 進行分組 (這是你原本的邏輯)
        final Map<String, List<BookingModel>> sessionMap = {};
        for (var b in bookingsInDay) {
          if (!sessionMap.containsKey(b.sessionId)) {
            sessionMap[b.sessionId] = [];
          }
          sessionMap[b.sessionId]!.add(b);
        }

        // 這一天的場次列表
        final sessionGroups = sessionMap.values.toList();

        sections.add(
          DaySection(
            date: DateTime.parse(dateKey),
            sessionGroups: sessionGroups,
          ),
        );
      });

      // 歷史紀錄依舊維持單筆排序
      rawHistory.sort((a, b) => b.startTime.compareTo(a.startTime));

      if (mounted) {
        setState(() {
          _groupedSections = sections;
          _historyBookings = rawHistory;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 處理按鈕點擊 (判斷是取消還是請假)
  Future<void> _handleAction(BookingModel booking) async {
    final now = DateTime.now();
    final difference = booking.startTime.difference(now).inHours;

    // 🔥 邏輯判斷：是否小於 12 小時
    final isLate = difference < 12;

    if (booking.attendanceStatus == 'leave') {
      return; // 已經請假過就不能動了
    }

    // 根據時間顯示不同對話框
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isLate ? '申請請假？' : '取消預約？'),
        content: Text(
          isLate
              ? '課程即將在 12 小時內開始，無法取消退費，僅能標記為請假。\n(請依補課規定辦理)'
              : '確定要取消此預約嗎？名額將會釋出。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('保留'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: isLate ? Colors.orange : Colors.red,
            ),
            child: Text(isLate ? '確認請假' : '確認取消'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        if (isLate) {
          // < 12hr: 請假 (更新狀態)
          await _bookingRepo.requestLeave(booking.id);
          if (mounted)
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('已標記為請假')));
        } else {
          // > 12hr: 取消 (刪除)
          await _bookingRepo.cancelBooking(booking.id);
          if (mounted)
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('預約已取消')));
        }
        _fetchBookings(); // 重整列表
      } catch (e) {
        if (mounted)
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('操作失敗: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('我的預約'),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Theme.of(context).primaryColor,
          unselectedLabelColor: Colors.grey,
          tabs: const [
            Tab(text: '即將到來'),
            Tab(text: '歷史紀錄'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                // -----------------------------------------------------
                // 🔥 第一個 Tab：即將到來 (修改這裡!)
                // -----------------------------------------------------
                RefreshIndicator(
                  onRefresh: _fetchBookings,
                  // ⚠️ 注意：這裡的判斷變數建議也改用新的 _groupedSections
                  child: _groupedSections.isEmpty
                      ? const _UpcomingEmptyState() // 空狀態 (維持不變)
                      : ListView.builder(
                          // 🔥 這裡就是第 2 點要修改的重點
                          padding: const EdgeInsets.only(bottom: 30),
                          physics: const AlwaysScrollableScrollPhysics(),
                          // 改用新的日期分組清單
                          itemCount: _groupedSections.length,
                          itemBuilder: (context, index) {
                            final section = _groupedSections[index];

                            // 每一個 Item 包含：一個日期標題 + 該日期的所有課程卡片
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // A. 日期標題
                                _DateHeader(date: section.date),

                                // B. 該日期的所有課程 (用 map 轉出卡片)
                                ...section.sessionGroups.map((group) {
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                    ), // 補一點左右邊距
                                    child: _GroupedBookingCard(
                                      bookings: group,
                                      onAction: _handleAction,
                                      isCompact: true, // 🔥 開啟緊湊模式
                                    ),
                                  );
                                }),
                              ],
                            );
                          },
                        ),
                ),

                // -----------------------------------------------------
                // 第二個 Tab：歷史紀錄 (不用動)
                // -----------------------------------------------------
                RefreshIndicator(
                  onRefresh: _fetchBookings,
                  child: _HistoryList(bookings: _historyBookings),
                ),
              ],
            ),
    );
  }
}

// Widget：合併顯示同一場次的預約
class _GroupedBookingCard extends StatelessWidget {
  final List<BookingModel> bookings; // 這一組裡面的所有預約 (同一場次，不同學員)
  final Function(BookingModel) onAction;
  final bool isCompact;
  const _GroupedBookingCard({
    required this.bookings,
    required this.onAction,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    if (bookings.isEmpty) return const SizedBox.shrink();

    final session = bookings.first.session; // 取第一筆抓課程資訊
    final dateFormat = DateFormat('MM/dd (E)', 'zh_TW');
    final timeFormat = DateFormat('HH:mm');
    final dateStr = dateFormat.format(session.startTime);
    final timeStr =
        "${timeFormat.format(session.startTime)} - ${timeFormat.format(session.endTime)}";

    return Card(
      elevation: 3,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          // 1. 卡片頭部：顯示課程資訊 (只顯示一次)
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: 16,
              vertical: isCompact ? 12 : 16, // 稍微調整垂直間距
            ),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.calendar_today,
                    color: Colors.blue.shade700,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        session.courseTitle,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "$dateStr  $timeStr",
                        style: TextStyle(
                          color: Colors.blue.shade900,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 2. 學員列表 (Loop 顯示每個小孩)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              children: bookings.map((booking) {
                // 計算是否小於 12 小時
                final hoursLeft = booking.startTime
                    .difference(DateTime.now())
                    .inHours;
                final isLate = hoursLeft < 12;
                final isLeave = booking.attendanceStatus == 'leave';

                return Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: Colors.grey.shade100),
                    ),
                  ),
                  child: Row(
                    children: [
                      // 學員名字
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: Colors.grey.shade200,
                        child: Text(
                          booking.student?.name[0] ?? '?',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        booking.student?.name ?? '未知',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      const Spacer(),

                      // 操作按鈕 (根據狀態變換)
                      if (isLeave)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            '已請假',
                            style: TextStyle(
                              color: Colors.orange,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        )
                      else
                        OutlinedButton(
                          onPressed: () => onAction(booking),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: isLate
                                ? Colors.orange
                                : Colors.red,
                            side: BorderSide(
                              color: isLate
                                  ? Colors.orange.shade200
                                  : Colors.red.shade200,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 0,
                            ),
                            minimumSize: const Size(0, 32),
                          ),
                          child: Text(
                            isLate ? '請假' : '取消', // 🔥 按鈕文字自動變換
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          // 底部提示 (選用)
          if (bookings.first.session.category == 'personal')
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                "※ 這是私人課程",
                style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------
// 優化後的歷史紀錄列表
// -----------------------------------------------------
class _HistoryList extends StatelessWidget {
  final List<BookingModel> bookings;

  const _HistoryList({required this.bookings});

  @override
  Widget build(BuildContext context) {
    // 1. 空狀態處理 (保持原本的設計，但圖示可以微調)
    if (bookings.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.history_edu,
                size: 48,
                color: Colors.grey.shade400,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              "目前沒有歷史紀錄",
              style: TextStyle(color: Colors.grey.shade500, fontSize: 16),
            ),
          ],
        ),
      );
    }

    // 2. 列表建構
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 12),
      itemCount: bookings.length,
      itemBuilder: (context, index) {
        final booking = bookings[index];
        // 判斷是否需要顯示年份標題 (如果跨年了，可以在這裡加邏輯，目前先簡化)
        return _HistoryCard(booking: booking);
      },
    );
  }
}

// -----------------------------------------------------
// 新增：單筆歷史紀錄卡片 (左側日期 + 右側資訊)
// -----------------------------------------------------
class _HistoryCard extends StatelessWidget {
  final BookingModel booking;

  const _HistoryCard({required this.booking});

  @override
  Widget build(BuildContext context) {
    // 跨年顯示優化邏輯
    final now = DateTime.now();
    final isDifferentYear = booking.startTime.year != now.year;
    // 如果是不同年，顯示 "2025/12/31"，否則顯示 "12/31"
    final datePattern = isDifferentYear ? 'yyyy/MM/dd' : 'MM/dd';

    // 1. 日期與時間格式化
    final monthDayFormat = DateFormat(datePattern);
    final weekDayFormat = DateFormat('E', 'zh_TW');
    final timeFormat = DateFormat('HH:mm');

    final dateStr = monthDayFormat.format(booking.startTime);
    final weekStr = weekDayFormat.format(booking.startTime);
    final timeRange =
        "${timeFormat.format(booking.startTime)} - ${timeFormat.format(booking.endTime)}";

    // 2. 狀態顏色邏輯 (統一設定)
    String statusText;
    Color themeColor; // 文字與邊框色
    Color bgColor; // 背景色

    if (booking.status == 'cancelled') {
      // 🔴 Case 1: 已取消 (紅色)
      statusText = '已取消';
      themeColor = Colors.red.shade600;
      bgColor = Colors.red.shade50;
    } else if (booking.attendanceStatus == 'leave') {
      // 🟠 Case 2: 已請假 (橘色)
      statusText = '已請假';
      themeColor = Colors.orange.shade700;
      bgColor = Colors.orange.shade50;
    } else {
      // 🟢 Case 3: 已結束/已完成 (綠色)
      statusText = '已結束';
      themeColor = Colors.green.shade700;
      bgColor = Colors.green.shade50;
    }

    // 判斷是否要讓標題變淡或加刪除線 (僅針對已取消)
    final isCancelled = booking.status == 'cancelled';
    final contentColor = isCancelled ? Colors.grey.shade400 : Colors.black87;
    final titleDecoration = isCancelled ? TextDecoration.lineThrough : null;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200), // 統一的淡邊框
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // A. 左側日期
          SizedBox(
            width: 50,
            child: Column(
              children: [
                Text(
                  dateStr,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isCancelled
                        ? Colors.grey.shade400
                        : Colors.blueGrey.shade700,
                  ),
                ),
                Text(
                  weekStr,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                ),
              ],
            ),
          ),

          // 分隔線
          Container(
            width: 1,
            height: 36,
            color: Colors.grey.shade200,
            margin: const EdgeInsets.symmetric(horizontal: 12),
          ),

          // B. 中間資訊 (課程名稱、學員)
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  booking.courseTitle,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: contentColor,
                    decoration: titleDecoration,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.person, size: 12, color: Colors.grey.shade400),
                    const SizedBox(width: 4),
                    Text(
                      "${booking.student?.name ?? '未知'}  •  $timeRange",
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // C. 右側狀態標籤 (統一外觀，只變顏色)
          Container(
            margin: const EdgeInsets.only(left: 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(8),
              // 如果想要邊框更明顯，可以取消註解下面這行
              // border: Border.all(color: themeColor.withOpacity(0.3)),
            ),
            child: Text(
              statusText,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: themeColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// 即將到來的空狀態引導頁面
class _UpcomingEmptyState extends StatelessWidget {
  const _UpcomingEmptyState();

  @override
  Widget build(BuildContext context) {
    // 使用 ListView 確保在空狀態下也能 "下拉刷新" (RefreshIndicator 需要可捲動的子元件)
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.2), // 垂直置中調整
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.calendar_today_rounded,
                size: 64,
                color: Colors.blue.shade300,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              "目前沒有即將到來的課程",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "快去尋找感興趣的課程吧！",
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ],
    );
  }
}

class _DateHeader extends StatelessWidget {
  final DateTime date;
  const _DateHeader({required this.date});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final isToday =
        date.year == now.year && date.month == now.month && date.day == now.day;

    final isTomorrow =
        date.year == now.year &&
        date.month == now.month &&
        date.day == now.day + 1;

    final isSameYear = date.year == now.year;

    String title;
    if (isToday) {
      title = "今天";
    } else if (isTomorrow) {
      title = "明天";
    } else {
      // 如果是跨年 (例如明年)，顯示 "2026/01/05"
      // 如果是今年，維持 "01/05"
      final format = isSameYear ? 'MM/dd' : 'yyyy/MM/dd';
      title = DateFormat(format, 'zh_TW').format(date);
    }

    final weekDay = DateFormat('EEEE', 'zh_TW').format(date); // 週二

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: isToday ? Colors.blue.shade700 : Colors.black87,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            weekDay,
            style: TextStyle(
              fontSize: 14,
              color: isToday ? Colors.blue.shade700 : Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Divider(color: Colors.grey.shade300, thickness: 1)),
        ],
      ),
    );
  }
}
