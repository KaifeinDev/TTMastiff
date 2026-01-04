import 'package:flutter/material.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // 未來這裡要改成 FutureBuilder 去抓真實數據
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
        const SizedBox(height: 20),

        // 資訊卡片區
        Wrap(
          spacing: 20,
          runSpacing: 20,
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

        const SizedBox(height: 40),
        const Text(
          '近期操作紀錄',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        const Expanded(
          child: Card(child: Center(child: Text('這裡可以放最近的報名或點數交易紀錄列表'))),
        ),
      ],
    );
  }
}

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
    return Container(
      width: 250,
      padding: const EdgeInsets.all(20),
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
              Icon(icon, color: color, size: 30),
              const SizedBox(width: 10),
              Text(
                title,
                style: TextStyle(color: Colors.grey[600], fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
