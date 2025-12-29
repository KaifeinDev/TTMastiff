import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/services/booking_repository.dart';

class MyBookingsScreen extends StatefulWidget {
  const MyBookingsScreen({super.key});

  @override
  State<MyBookingsScreen> createState() => _MyBookingsScreenState();
}

class _MyBookingsScreenState extends State<MyBookingsScreen> {
  final _bookingRepository = BookingRepository(Supabase.instance.client);
  
  bool _isLoading = true;
  List<BookingModel> _upcomingList = [];
  List<BookingModel> _historyList = [];

  @override
  void initState() {
    super.initState();
    _loadBookings();
  }

  Future<void> _loadBookings() async {
    setState(() => _isLoading = true);
    try {
      final allBookings = await _bookingRepository.fetchMyBookings();
      
      // 在 Client 端進行分堆：過期 vs 沒過期
      final now = DateTime.now();
      
      final upcoming = <BookingModel>[];
      final history = <BookingModel>[];

      for (var booking in allBookings) {
        if (booking.endTime.isBefore(now)) {
          history.add(booking);
        } else {
          upcoming.add(booking);
        }
      }

      // 排序優化：
      // 即將到來：時間近的在上面 (升冪)
      upcoming.sort((a, b) => a.startTime.compareTo(b.startTime));
      // 歷史紀錄：最近結束的在上面 (降冪)
      history.sort((a, b) => b.startTime.compareTo(a.startTime));

      if (mounted) {
        setState(() {
          _upcomingList = upcoming;
          _historyList = history;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text('載入失敗: $e')),
        );
      }
    }
  }

  // 處理取消預約
  Future<void> _handleCancel(BookingModel booking) async {
    // 1. 檢查時間：例如開課前 2 小時不能取消
    final timeDifference = booking.startTime.difference(DateTime.now());
    if (timeDifference.inHours < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('開課前 2 小時無法取消，請聯繫櫃檯。')),
      );
      return;
    }

    // 2. 跳出確認視窗
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('取消預約'),
        content: Text('確定要取消 ${booking.studentName} 的\n${booking.courseTitle} 嗎？\n\n點數將會退還。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('保留')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('確認取消', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _bookingRepository.cancelBooking(booking.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ 已取消預約')));
          _loadBookings(); // 重新整理列表
        }
      } catch (e) {
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('取消失敗，請稍後再試')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2, // 兩個分頁
      child: Scaffold(
        appBar: AppBar(
          title: const Text('我的課程'),
          bottom: const TabBar(
            tabs: [
              Tab(text: '即將開始'),
              Tab(text: '歷史紀錄'),
            ],
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                children: [
                  _buildBookingList(_upcomingList, isHistory: false),
                  _buildBookingList(_historyList, isHistory: true),
                ],
              ),
      ),
    );
  }

  Widget _buildBookingList(List<BookingModel> bookings, {required bool isHistory}) {
    if (bookings.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isHistory ? Icons.history : Icons.calendar_today_outlined,
              size: 64, color: Colors.grey.shade300
            ),
            const SizedBox(height: 16),
            Text(
              isHistory ? '沒有歷史紀錄' : '目前沒有預約',
              style: const TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: bookings.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final booking = bookings[index];
        return _BookingCard(
          booking: booking,
          isHistory: isHistory,
          onCancel: () => _handleCancel(booking),
        );
      },
    );
  }
}

// 提取出來的卡片 Widget，讓程式碼比較乾淨
class _BookingCard extends StatelessWidget {
  final BookingModel booking;
  final bool isHistory;
  final VoidCallback onCancel;

  const _BookingCard({
    required this.booking,
    required this.isHistory,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MM/dd (E)', 'zh_TW'); // 需要 intl 套件支援中文
    final timeFormat = DateFormat('HH:mm');

    // 歷史紀錄顯示灰色，未來的顯示亮色
    final cardColor = isHistory ? Colors.grey.shade100 : Colors.white;
    final textColor = isHistory ? Colors.grey : Colors.black87;

    return Card(
      elevation: isHistory ? 0 : 2,
      color: cardColor,
      shape: RoundedRectangleBorder(
        side: isHistory ? BorderSide.none : BorderSide(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(12)
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. 頂部：日期時間標籤
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isHistory ? Colors.grey.shade300 : Theme.of(context).primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.access_time, size: 14, color: isHistory ? Colors.grey : Theme.of(context).primaryColor),
                      const SizedBox(width: 4),
                      Text(
                        '${dateFormat.format(booking.startTime)} ${timeFormat.format(booking.startTime)} - ${timeFormat.format(booking.endTime)}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isHistory ? Colors.grey : Theme.of(context).primaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!isHistory)
                  const Text('已預約', style: TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.bold)),
                 if (isHistory)
                  const Text('已結束', style: TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
            const SizedBox(height: 12),

            // 2. 課程標題
            Text(
              booking.courseTitle,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor),
            ),
            const SizedBox(height: 4),
            
           // 3. 顯示分類標籤與教練
            Row(
              children: [
                // 分類標籤 (不同顏色區分)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: booking.category == 'personal' ? Colors.orange.shade100 : Colors.blue.shade100,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    booking.categoryText,
                    style: TextStyle(
                      fontSize: 12, 
                      color: booking.category == 'personal' ? Colors.orange.shade800 : Colors.blue.shade800
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                
                // 教練圖示與名字
                const Icon(Icons.sports_tennis, size: 16, color: Colors.grey), // 換成球拍圖示更有感
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    booking.coaches.isEmpty ? '待定' : booking.coaches.join('、'),
                    style: const TextStyle(color: Colors.grey, fontSize: 14),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ), 
            const Divider(height: 24),
            
            // 4. 底部：學員名稱 + 操作按鈕
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.person_outline, size: 18, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text('學員：${booking.studentName}', style: TextStyle(fontWeight: FontWeight.w500, color: textColor)),
                  ],
                ),
                
                // 只有「非歷史」且「非取消」的狀態才顯示取消按鈕
                if (!isHistory)
                  OutlinedButton(
                    onPressed: onCancel,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text('取消', style: TextStyle(fontSize: 12)),
                  ),
              ],
            )
          ],
        ),
      ),
    );
  }
}
