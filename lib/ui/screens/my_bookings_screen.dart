import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// 🔥 請確認您的路徑正確
import '../../data/models/booking_model.dart';
import '../../data/services/booking_repository.dart';
import '../../main.dart'; // 為了取得全域 bookingRepository

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
    _tabController = TabController(length: 2, vsync: this);
    _fetchBookings();
  }

  @override
  void dispose() {
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
  void _handleBookingAction(BookingModel booking) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.sick, color: Colors.orange),
                title: const Text('請假 (Leave)'),
                subtitle: const Text('將狀態改為請假，釋出名額'),
                onTap: () async {
                  Navigator.pop(context);
                  await _updateStatus(booking, 'leave');
                },
              ),
              ListTile(
                leading: const Icon(Icons.cancel, color: Colors.red),
                title: const Text('取消預約 (Cancel)'),
                subtitle: const Text('完全取消此預約'),
                onTap: () async {
                  Navigator.pop(context);
                  await _updateStatus(
                    booking,
                    'cancelled',
                  ); // 這裡傳遞 cancelled 給後端判斷
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _updateStatus(BookingModel booking, String actionType) async {
    try {
      // 這裡呼叫 Repository 更新
      // 注意：需根據您的 Repo 實作調整。
      // 如果是請假 -> status: confirmed, attendance: leave
      // 如果是取消 -> status: cancelled, attendance: pending

      String newStatus = booking.status;
      String newAttendance = booking.attendanceStatus;

      if (actionType == 'leave') {
        newAttendance = 'leave';
      } else if (actionType == 'cancelled') {
        newStatus = 'cancelled';
        newAttendance = 'pending';
      }

      await bookingRepository.updateBookingStatus(
        bookingId: booking.id,
        status: newStatus,
        attendanceStatus: newAttendance,
      );

      // 刷新列表
      _fetchBookings();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('更新成功')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('失敗: $e')));
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
              children: [_buildUpcomingList(), _buildHistoryList()],
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
                // 🔥 修正：這裡不再傳入 isCompact
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
            final hoursLeft = booking.startTime
                .difference(DateTime.now())
                .inHours;
            final isLate = hoursLeft < 12;

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
                  _buildRightSideStatus(booking, isLate),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildRightSideStatus(BookingModel booking, bool isLate) {
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
      return OutlinedButton(
        onPressed: () => onAction(booking),
        style: OutlinedButton.styleFrom(
          foregroundColor: isLate ? Colors.orange : Colors.red,
          side: BorderSide(
            color: isLate ? Colors.orange.shade200 : Colors.red.shade200,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
          minimumSize: const Size(0, 32),
        ),
        child: Text(isLate ? '請假' : '取消', style: const TextStyle(fontSize: 13)),
      );
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
