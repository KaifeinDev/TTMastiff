import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../data/models/payroll_model.dart'; // 請確認這個路徑是否正確

class PayrollDashboard extends StatelessWidget {
  final List<Map<String, dynamic>> staffList;

  const PayrollDashboard({super.key, required this.staffList});

  @override
  Widget build(BuildContext context) {
    // 簡單統計數據
    int totalPayout = 0;
    double totalCoachHours = 0;
    double totalDeskHours = 0;
    int unsettledCount = 0;

    for (var item in staffList) {
      final PayrollModel p = item['payroll'];
      totalPayout += p.totalAmount;
      totalCoachHours += p.totalCoachHours;
      totalDeskHours += p.totalDeskHours;

      // 判定未結算：狀態為 unsettled 或 id 為空
      if (p.status == 'unsettled' || p.id.isEmpty) {
        unsettledCount++;
      }
    }

    final currencyFmt = NumberFormat.decimalPattern(); // 1,000
    final hourFmt = NumberFormat('#,##0.0'); // 1,200.5 (保留一位小數)

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      color: Colors.white, //延續月份選擇器的背景色
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildStatItem(
              context,
              title: '預估總支出',
              value: '\$${currencyFmt.format(totalPayout)}',
              icon: Icons.payments_outlined,
              iconColor: Theme.of(context).colorScheme.primary,
              valueColor: Theme.of(context).colorScheme.primary,
              isLarge: true,
            ),
            _buildVerticalDivider(),
            _buildStatItem(
              context,
              title: '總工時 (教+櫃)',
              value: '${hourFmt.format(totalCoachHours + totalDeskHours)} hr',
              subValue:
                  '教 ${hourFmt.format(totalCoachHours)} / 櫃 ${hourFmt.format(totalDeskHours)}',
              icon: Icons.access_time,
              iconColor: Colors.orange,
            ),
            _buildVerticalDivider(),
            _buildStatItem(
              context,
              title: '待結算人數',
              value: '$unsettledCount 人',
              icon: Icons.assignment_late_outlined,
              iconColor: unsettledCount > 0 ? Colors.redAccent : Colors.grey,
              highlight: unsettledCount > 0,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVerticalDivider() {
    return Container(height: 40, width: 1, color: Colors.white);
  }

  Widget _buildStatItem(
    BuildContext context, {
    required String title,
    required String value,
    String? subValue, // 新增：顯示次要資訊
    required IconData icon,
    Color? iconColor,
    Color? valueColor,
    bool highlight = false,
    bool isLarge = false,
  }) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: Colors.grey[400]),
            const SizedBox(width: 4),
            Text(
              title,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
        const SizedBox(height: 6),

        Text(
          value,
          style: TextStyle(
            fontSize: isLarge ? 22 : 18,
            fontWeight: FontWeight.bold,
            color: highlight ? Colors.orange : (valueColor ?? Colors.black87),
            height: 1.0,
          ),
        ),
        // 次要資訊 (例如細分教課/櫃檯時數)
        if (subValue != null) ...[
          const SizedBox(height: 4),
          Text(
            subValue,
            style: TextStyle(fontSize: 10, color: Colors.grey[400]),
          ),
        ],
      ],
    );
  }
}
