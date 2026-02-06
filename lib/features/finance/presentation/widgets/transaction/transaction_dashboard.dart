import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // 需要這個來處理千分位逗號

class TransactionDashboard extends StatelessWidget {
  final int pendingCash; // 未收帳款
  final int settledCash; // 已入庫

  const TransactionDashboard({
    super.key,
    required this.pendingCash,
    required this.settledCash,
    // operatorStats 已經移除，因為我們改在主頁面顯示
  });

  @override
  Widget build(BuildContext context) {
    // 使用 NumberFormat 來讓金額有逗號 (ex: 1,000)
    final currencyFormat = NumberFormat("#,##0", "en_US");

    return Padding(
      // 移除 Container 的顏色，改用 Padding 即可
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _buildStatCard(
            title: '待收款',
            amount: currencyFormat.format(pendingCash),
            bgColor: Colors.orange.shade50,
            textColor: Colors.orange.shade800,
            icon: Icons.pending_actions,
          ),
          const SizedBox(width: 12),
          _buildStatCard(
            title: '已收款',
            amount: currencyFormat.format(settledCash),
            bgColor: Colors.green.shade50,
            textColor: Colors.green.shade700,
            icon: Icons.savings, // 換個更有「入袋」感覺的 icon，或維持 check_circle
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String amount, // 改成 String 因為已經格式化過了
    required Color bgColor,
    required Color textColor,
    required IconData icon,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16), // 圓角大一點比較現代
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: textColor.withValues(alpha: 0.8)),
                const SizedBox(width: 6),
                Text(
                  title,
                  style: TextStyle(
                    color: textColor.withValues(alpha: 0.9),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '\$$amount',
              style: TextStyle(
                color: textColor,
                fontSize: 22, // 稍微調整字體大小
                fontWeight: FontWeight.w800, // 字體加粗
                fontFamily: 'RobotoMono', // 如果有數字專用字體更好，沒有也沒關係
              ),
            ),
          ],
        ),
      ),
    );
  }
}
