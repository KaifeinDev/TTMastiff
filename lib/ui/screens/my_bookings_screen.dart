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
    _tabController = TabController(length: 2, vsync: this);
    _fetchBookings();
  }

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

      // 2. 🔥 進行分組 (Grouping)
      // 使用 Map 將相同 session_id 的預約集合起來
      final Map<String, List<BookingModel>> groupedMap = {};
      for (var booking in rawUpcoming) {
        if (!groupedMap.containsKey(booking.sessionId)) {
          groupedMap[booking.sessionId] = [];
        }
        groupedMap[booking.sessionId]!.add(booking);
      }

      // 轉回 List 並排序 (依照場次時間)
      final sortedGroups = groupedMap.values.toList();
      sortedGroups.sort(
        (a, b) => a.first.startTime.compareTo(b.first.startTime),
      );

      // 歷史紀錄依舊維持單筆排序
      rawHistory.sort((a, b) => b.startTime.compareTo(a.startTime));

      if (mounted) {
        setState(() {
          _upcomingGroups = sortedGroups;
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
                // 即將到來 (使用分組列表)
                ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _upcomingGroups.length,
                  itemBuilder: (context, index) {
                    return _GroupedBookingCard(
                      bookings: _upcomingGroups[index],
                      onAction: _handleAction,
                    );
                  },
                ),
                // 歷史紀錄 (維持原樣，或是您也可以套用分組)
                _HistoryList(bookings: _historyBookings),
              ],
            ),
    );
  }
}

// 🔥 新的 Widget：合併顯示同一場次的預約
class _GroupedBookingCard extends StatelessWidget {
  final List<BookingModel> bookings; // 這一組裡面的所有預約 (同一場次，不同學員)
  final Function(BookingModel) onAction;

  const _GroupedBookingCard({required this.bookings, required this.onAction});

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
            padding: const EdgeInsets.all(16),
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

// 完整的歷史紀錄列表 Widget
class _HistoryList extends StatelessWidget {
  final List<BookingModel> bookings;

  const _HistoryList({required this.bookings});

  @override
  Widget build(BuildContext context) {
    // 1. 空狀態處理
    if (bookings.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              "沒有歷史紀錄",
              style: TextStyle(color: Colors.grey.shade500, fontSize: 16),
            ),
          ],
        ),
      );
    }

    final dateFormat = DateFormat('MM/dd (E)', 'zh_TW');
    final timeFormat = DateFormat('HH:mm');

    // 2. 列表建構
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: bookings.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final booking = bookings[index];

        // 準備顯示資料
        final dateStr = dateFormat.format(booking.startTime);
        final timeStr =
            "${timeFormat.format(booking.startTime)} - ${timeFormat.format(booking.endTime)}";
        final studentName = booking.student?.name ?? '未知學員';

        // 3. 狀態判斷邏輯 (決定顏色與文字)
        String statusText;
        Color statusColor;
        Color statusBgColor;

        if (booking.status == 'cancelled') {
          // 情況 A: 已取消 (最優先判斷)
          statusText = '已取消';
          statusColor = Colors.red.shade700;
          statusBgColor = Colors.red.shade50;
        } else if (booking.attendanceStatus == 'leave') {
          // 情況 B: 已請假
          statusText = '已請假';
          statusColor = Colors.orange.shade800;
          statusBgColor = Colors.orange.shade50;
        } else {
          // 情況 C: 正常結束 (預設)
          statusText = '已結束';
          statusColor = Colors.grey.shade600;
          statusBgColor = Colors.grey.shade200;
        }

        return Card(
          elevation: 0, // 歷史紀錄不需要太多陰影，讓畫面乾淨點
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey.shade200), // 淡淡的邊框
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 第一行：課程名稱 + 狀態標籤
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        booking.courseTitle,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          // 如果是已取消，標題顏色也淡一點
                          color: booking.status == 'cancelled'
                              ? Colors.grey
                              : Colors.black87,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: statusBgColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        statusText,
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // 第二行：時間
                Row(
                  children: [
                    Icon(
                      Icons.access_time,
                      size: 14,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      "$dateStr  $timeStr",
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 4),

                // 第三行：學員
                Row(
                  children: [
                    Icon(Icons.person, size: 14, color: Colors.grey.shade400),
                    const SizedBox(width: 6),
                    Text(
                      "學員: $studentName",
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
