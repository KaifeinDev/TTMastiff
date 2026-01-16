import 'package:flutter/material.dart';
import 'widgets/daily_schedule_view.dart'; 

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  // 這裡可以做簡單的數據載入，為了示範先維持靜態或簡單 Future
  // 實際專案建議這裡去 call repository 抓「今日總覽」數據

  @override
  Widget build(BuildContext context) {
    // 假數據 (若您原本有邏輯，請保留)
    const int todayBookings = 12;
    const int todayRevenue = 4800;
    const int totalStudents = 85;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '今日概況',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),

        // 上方資訊卡片區 (保留您原本的設計)
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            _InfoCard(
              title: '今日預約',
              value: '$todayBookings 人',
              icon: Icons.people_alt,
              color: Colors.blue,
            ),
            _InfoCard(
              title: '今日預估營收',
              value: '\$ $todayRevenue',
              icon: Icons.attach_money,
              color: Colors.green,
            ),
            _InfoCard(
              title: '總學員數',
              value: '$totalStudents 人',
              icon: Icons.school,
              color: Colors.orange,
            ),
          ],
        ),

        const SizedBox(height: 24),

        // 下方：桌次排程表
        const Text(
          '桌次排程總覽',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),

        // 🔥 使用 Expanded 讓排程表佔滿剩餘空間
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias, // 讓圓角生效
            child: const DailyScheduleView(), // 🔥 嵌入剛剛做的 Widget
          ),
        ),
      ],
    );
  }
}

// 您的 _InfoCard 保持不變
class _InfoCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _InfoCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    // 配合 Wrap，設定固定寬度或依照需求調整
    return Container(
      width: 200,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
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
          Row(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(color: Colors.grey[600], fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
