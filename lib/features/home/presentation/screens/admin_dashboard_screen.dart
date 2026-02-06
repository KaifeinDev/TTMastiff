import 'package:flutter/material.dart';
import 'package:ttmastiff/core/utils/util.dart';
import '../widgets/daily_schedule_view.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  // 模擬數據
  final int todayBookings = 12;
  final int todayRevenue = 4800;
  final int totalStudents = 85;

  @override
  Widget build(BuildContext context) {
    // 🔥 1. 使用 LayoutBuilder 偵測螢幕寬度
    return LayoutBuilder(
      builder: (context, constraints) {
        // 設定斷點，例如 900px (平板橫向或電腦)
        bool isDesktop = constraints.maxWidth > 900;

        // 準備好數據卡片清單 (重用)
        final statsCards = [
          _InfoCard(
            title: '今日預約',
            value: '$todayBookings 人',
            icon: Icons.people_alt,
            color: Colors.blue,
            isDesktop: isDesktop,
          ),
          SizedBox(width: isDesktop ? 0 : 12, height: isDesktop ? 16 : 0), // 間距
          _InfoCard(
            title: '今日預估營收',
            value: '\$ $todayRevenue',
            icon: Icons.attach_money,
            color: Colors.green,
            isDesktop: isDesktop,
          ),
          SizedBox(width: isDesktop ? 0 : 12, height: isDesktop ? 16 : 0), // 間距
          _InfoCard(
            title: '總學員數',
            value: '$totalStudents 人',
            icon: Icons.school,
            color: Colors.orange,
            isDesktop: isDesktop,
          ),
        ];

        // --- 排程區塊 (封裝成 Widget 方便重複使用) ---
        Widget scheduleSection = Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: const DailyScheduleView(),
        );

        // ============================================
        //  💻 電腦版佈局 (左右並排)
        // ============================================
        if (isDesktop) {
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 左側：排程 (70%)
                Expanded(
                  flex: 7,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '桌次排程總覽',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Expanded(child: scheduleSection),
                    ],
                  ),
                ),
                const SizedBox(width: 20),
                // 右側：數據 (30%)
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '今日概況',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: SingleChildScrollView(
                          child: Column(children: statsCards),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }

        // ============================================
        //  📱 手機版佈局 (上下堆疊)
        // ============================================
        return Column(
          children: [
            // 上方：數據區 (改為橫向滑動，節省垂直空間)
            Container(
              padding: const EdgeInsets.fromLTRB(16, 16, 0, 8),
              height: 110, // 固定高度給橫向列表
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  // 手機版不需要顯示大標題 "今日概況"，直接給數據即可
                  ...statsCards,
                  const SizedBox(width: 16), // 右邊留白
                ],
              ),
            ),

            // 下方：排程區 (佔滿剩餘空間)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [Expanded(child: scheduleSection)],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// 調整後的 _InfoCard (支援手機版變小一點)
class _InfoCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final bool isDesktop; // 新增判斷參數

  const _InfoCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.isDesktop = true,
  });

  @override
  Widget build(BuildContext context) {
    // 手機版固定寬度，電腦版自動填滿
    return Container(
      width: isDesktop ? double.infinity : 160,
      padding: EdgeInsets.all(isDesktop ? 20 : 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: isDesktop
          ? Row(
              // 電腦版樣式 (圖示在右)
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(color: Colors.grey[600], fontSize: 14),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      value,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 28),
                ),
              ],
            )
          : Column(
              // 手機版樣式 (緊湊，圖示在左上)
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Icon(icon, color: color, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      title,
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
    );
  }
}
