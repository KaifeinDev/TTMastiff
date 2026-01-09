import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

// 🔥 請確認您的路徑正確
import '../../data/models/booking_model.dart';
import '../../data/services/booking_repository.dart';
import '../../main.dart'; // 為了取得全域 bookingRepository

const int kFreeCancelHours = 12; // 課程開始前 12 小時以前可免費取消
const int kLockoutHours = 1; // 課程開始前 1 小時鎖定

class MyBookingScreen extends StatefulWidget {
  const MyBookingScreen({super.key});

  @override
  State<MyBookingScreen> createState() => _MyBookingScreenState();
}

// 輔助類別：用來存放某一天的所有場次群組
class DaySection {
  final DateTime date;
  final List<List<BookingModel>> sessionGroups; // 這一天裡面的「場次群組」

  DaySection({required this.date, required this.sessionGroups});
}

class _MyBookingScreenState extends State<MyBookingScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  bool _isLoading = true;

  // 🔥 核心資料結構
  // Tab 1: 即將到來 (按天分組 -> 再按場次分組)
  List<DaySection> _upcomingDays = [];
  // Tab 2: 歷史紀錄 (流水帳)
  List<BookingModel> _historyBookings = [];

  @override
  void initState() {
    super.initState();
    BookingRepository.bookingRefreshSignal.addListener(_fetchBookings);
    _tabController = TabController(length: 2, vsync: this);
    _fetchBookings();
  }

  @override
  void dispose() {
    BookingRepository.bookingRefreshSignal.removeListener(_fetchBookings);
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchBookings() async {
    setState(() => _isLoading = true);
    try {
      // 1. 抓取所有預約
      final bookings = await bookingRepository.fetchMyBookings();

      // 2. 分類為「歷史」與「未來」
      final now = DateTime.now();
      final List<BookingModel> rawHistory = [];
      final List<BookingModel> rawUpcoming = [];

      for (var b in bookings) {
        // 判斷邏輯：如果狀態是取消，或時間已過，歸類為歷史
        // 注意：這裡假設 b.endTime 是 Local Time
        if (b.status == 'cancelled' || b.endTime.isBefore(now)) {
          rawHistory.add(b);
        } else {
          rawUpcoming.add(b);
        }
      }

      // 3. 處理「即將到來」的分組邏輯 (DaySection)
      //    結構：[ DaySection(date: 今天, groups: [ [小明, 小華], [小明] ]), ... ]
      final Map<String, List<BookingModel>> dateMap = {};

      // 3-1. 先依照日期 (yyyy-MM-dd) 分籃子
      for (var b in rawUpcoming) {
        final dateKey = DateFormat('yyyy-MM-dd').format(b.startTime);
        if (!dateMap.containsKey(dateKey)) {
          dateMap[dateKey] = [];
        }
        dateMap[dateKey]!.add(b);
      }

      // 3-2. 將每個日期的籃子，再依照 Session ID 分組
      final List<DaySection> days = [];
      final sortedDates = dateMap.keys.toList()..sort(); // 日期排序

      for (var dateKey in sortedDates) {
        final bookingsInDay = dateMap[dateKey]!;
        final dateObj = DateTime.parse(dateKey);

        // Session 分組 map
        final Map<String, List<BookingModel>> sessionMap = {};
        for (var b in bookingsInDay) {
          if (!sessionMap.containsKey(b.sessionId)) {
            sessionMap[b.sessionId] = [];
          }
          sessionMap[b.sessionId]!.add(b);
        }

        // 轉成 List
        final sessionGroups = sessionMap.values.toList();

        // 依照該群組的第一筆資料時間排序 (早上的課在前)
        sessionGroups.sort(
          (a, b) => a.first.startTime.compareTo(b.first.startTime),
        );

        days.add(DaySection(date: dateObj, sessionGroups: sessionGroups));
      }

      if (mounted) {
        setState(() {
          _upcomingDays = days;
          _historyBookings = rawHistory;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching bookings: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 操作處理 (取消/請假)
  Future<void> _handleBookingAction(BookingModel booking) async {
    final now = DateTime.now();
    // 使用浮點數計算小時，比整數精確 (例如 1.5 小時)
    final hoursLeft = booking.startTime.difference(now).inMinutes / 60.0;

    // 再次檢查狀態，避免 UI 沒刷新導致誤按
    if (hoursLeft < kLockoutHours) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('課程即將開始，已停止線上操作，請直接聯繫場館。')));
      _fetchBookings(); // 刷新 UI 讓按鈕消失
      return;
    }

    final isLeaveWindow = hoursLeft < kFreeCancelHours; // 是否進入「僅能請假」區間

    // 顯示對話框
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isLeaveWindow ? '申請請假？' : '取消預約？'),
        content: Text(
          isLeaveWindow
              ? '課程即將在 $kFreeCancelHours 小時內開始，無法取消退費。\n您確定要標記為請假嗎？'
              : '距離開課還有充足時間，取消將全額退還點數。\n確定要取消此預約嗎？',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('保留'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: isLeaveWindow ? Colors.orange : Colors.red,
            ),
            child: Text(isLeaveWindow ? '確認請假' : '確認取消'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        if (isLeaveWindow) {
          // 情況 2: 請假 (Attendance -> Leave)
          await bookingRepository.requestLeave(booking.id);
          if (mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('已標記為請假')));
          }
        } else {
          // 情況 3: 取消 (Status -> Cancelled)
          await bookingRepository.cancelBooking(booking.id);
          if (mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('預約已取消')));
          }
        }
        _fetchBookings(); // 重整列表
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('操作失敗: $e')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('我的課程'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.blue,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Colors.blue,
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
                RefreshIndicator(
                  onRefresh: _fetchBookings,
                  child: _buildUpcomingList(),
                ),
                RefreshIndicator(
                  onRefresh: _fetchBookings,
                  child: _buildHistoryList(),
                ),
              ],
            ),
    );
  }

  // Tab 1: 即將到來列表
  Widget _buildUpcomingList() {
    if (_upcomingDays.isEmpty) {
      return const Center(child: Text('目前沒有即將到來的課程'));
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 20),
      itemCount: _upcomingDays.length,
      itemBuilder: (context, index) {
        final daySection = _upcomingDays[index];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 日期標題
            _DayHeader(date: daySection.date),
            // 該日期的所有場次卡片
            ...daySection.sessionGroups.map((group) {
              return _GroupedBookingCard(
                bookings: group,
                onAction: _handleBookingAction,
              );
            }),
          ],
        );
      },
    );
  }

  // Tab 2: 歷史紀錄列表
  Widget _buildHistoryList() {
    if (_historyBookings.isEmpty) {
      return const Center(child: Text('沒有歷史紀錄'));
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 12),
      itemCount: _historyBookings.length,
      itemBuilder: (context, index) {
        final booking = _historyBookings[index];
        return _HistoryCard(booking: booking);
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Widget: 日期標題 (例如：今天、明天、01/05 週日)
// ---------------------------------------------------------------------------
class _DayHeader extends StatelessWidget {
  final DateTime date;
  const _DayHeader({required this.date});

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
      final format = isSameYear ? 'MM/dd' : 'yyyy/MM/dd';
      title = DateFormat(format, 'zh_TW').format(date);
    }

    final weekDay = DateFormat('EEEE', 'zh_TW').format(date); // e.g. 週二

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
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
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Widget: 即將到來的群組卡片 (整合請假/出席狀態標籤)
// ---------------------------------------------------------------------------
class _GroupedBookingCard extends StatelessWidget {
  final List<BookingModel> bookings;
  final Function(BookingModel) onAction;

  const _GroupedBookingCard({required this.bookings, required this.onAction});

  @override
  Widget build(BuildContext context) {
    if (bookings.isEmpty) return const SizedBox.shrink();

    final sessionInfo = bookings.first;
    final timeFormat = DateFormat('HH:mm');
    final timeRange =
        "${timeFormat.format(sessionInfo.startTime)} - ${timeFormat.format(sessionInfo.endTime)}";

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: 時間與地點
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  timeRange,
                  style: TextStyle(
                    color: Colors.blue.shade700,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                sessionInfo.session.location ?? "無地點資訊",
                style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 課程標題
          Text(
            sessionInfo.courseTitle,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            "教練: ${sessionInfo.session.coachesText}",
            style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
          ),

          const Divider(height: 24),

          // 學員列表
          ...bookings.map((booking) {
            return Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
              ),
              child: Row(
                children: [
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
                  _buildRightSideStatus(booking),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildRightSideStatus(BookingModel booking) {
    if (booking.attendanceStatus == 'leave') {
      return _buildStatusBadge('已請假', Colors.orange);
    }
    if (booking.attendanceStatus == 'attended') {
      return _buildStatusBadge('已出席', Colors.green);
    }
    if (booking.attendanceStatus == 'absent') {
      return _buildStatusBadge('曠課', Colors.red);
    }

    if (booking.attendanceStatus == 'pending') {
      final now = DateTime.now();
      final hoursLeft = booking.startTime.difference(now).inMinutes / 60.0;

      if (hoursLeft > kFreeCancelHours) {
        // 可取消時段
        return OutlinedButton(
          onPressed: () => onAction(booking),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.red,
            side: BorderSide(color: Colors.red.shade200),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            minimumSize: const Size(0, 32),
          ),
          child: const Text('取消', style: TextStyle(fontSize: 13)),
        );
      } else if (hoursLeft > kLockoutHours) {
        // 可請假時段
        return OutlinedButton(
          onPressed: () => onAction(booking),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.orange,
            side: BorderSide(color: Colors.orange.shade200),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
            minimumSize: const Size(0, 32),
          ),
          child: Text('請假', style: const TextStyle(fontSize: 13)),
        );
      } else {
        return _buildStatusBadge(
          hoursLeft < 0 ? '待上課' : '上課中',
          hoursLeft < 0 ? Colors.blue : Colors.green,
        );
        // return const SizedBox.shrink();
      }
    }
    return Text(booking.attendanceStatus);
  }

  Widget _buildStatusBadge(String text, MaterialColor color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.shade100),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color.shade700,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Widget: 歷史紀錄卡片
// ---------------------------------------------------------------------------
class _HistoryCard extends StatelessWidget {
  final BookingModel booking;
  const _HistoryCard({required this.booking});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final isDifferentYear = booking.startTime.year != now.year;
    final datePattern = isDifferentYear ? 'yyyy/MM/dd' : 'MM/dd';
    final monthDayFormat = DateFormat(datePattern);
    final weekDayFormat = DateFormat('E', 'zh_TW');
    final timeFormat = DateFormat('HH:mm');

    final dateStr = monthDayFormat.format(booking.startTime);
    final weekStr = weekDayFormat.format(booking.startTime);
    final timeRange =
        "${timeFormat.format(booking.startTime)} - ${timeFormat.format(booking.endTime)}";

    String statusText;
    Color themeColor;
    Color bgColor;

    if (booking.status == 'cancelled') {
      statusText = '已取消';
      themeColor = Colors.red.shade400;
      bgColor = Colors.red.shade50;
    } else {
      switch (booking.attendanceStatus) {
        case 'attended':
          statusText = '已出席';
          themeColor = Colors.green.shade700;
          bgColor = Colors.green.shade50;
          break;
        case 'leave':
          statusText = '已請假';
          themeColor = Colors.orange.shade700;
          bgColor = Colors.orange.shade50;
          break;
        case 'absent':
          statusText = '曠課';
          themeColor = Colors.red.shade800;
          bgColor = Colors.red.shade100;
          break;
        case 'pending':
        default:
          statusText = '已結束';
          themeColor = Colors.grey.shade600;
          bgColor = Colors.grey.shade100;
          break;
      }
    }

    final isCancelled = booking.status == 'cancelled';
    final contentColor = isCancelled ? Colors.grey.shade400 : Colors.black87;
    final titleDecoration = isCancelled ? TextDecoration.lineThrough : null;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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

          Container(
            width: 1,
            height: 36,
            color: Colors.grey.shade200,
            margin: const EdgeInsets.symmetric(horizontal: 12),
          ),

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

          Container(
            margin: const EdgeInsets.only(left: 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(8),
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
