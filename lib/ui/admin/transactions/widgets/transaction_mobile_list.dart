import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:ttmastiff/data/models/transaction_model.dart';
import '../../../component/widget/transaction_status_badge.dart';

class TransactionMobileList extends StatelessWidget {
  final List<TransactionModel> transactions;
  final Function(TransactionModel) onReconcileTap;
  final Function(TransactionModel) onRefundTap;
  final bool isAdmin;

  const TransactionMobileList({
    super.key,
    required this.transactions,
    required this.onReconcileTap,
    required this.onRefundTap,
    required this.isAdmin,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 80, top: 8),
      itemCount: transactions.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final tx = transactions[index];
        return _buildTransactionItem(context, tx);
      },
    );
  }

  Widget _buildTransactionItem(BuildContext context, TransactionModel tx) {
    final currencyFormat = NumberFormat("#,##0", "en_US");
    final isRefunded = tx.status == 'refunded';

    // 判斷顯示的標題：優先顯示課程名稱，沒有才顯示描述，再沒有才顯示類型
    final String title =
        "${tx.userFullName ?? '未知'} 儲值 ${currencyFormat.format(tx.amount)} 元";

    IconData icon;
    Color iconColor;
    Color iconBgColor;

    if (isRefunded) {
      // 已退款 (灰色禁止符號)
      icon = Icons.block;
      iconColor = Colors.grey;
      iconBgColor = Colors.grey.shade200;
    } else {
      if (tx.isReconciled) {
        // [已收款] -> 勾勾 (Check)
        icon = Icons.check;
        iconColor = Colors.green.shade700;
        iconBgColor = Colors.green.shade100;
      } else {
        // [待收款] -> 加號 (Add)
        icon = Icons.add;
        iconColor = Colors.orange.shade700; // 建議待收款用藍色或橘色，區分 "已完成" 的綠色
        iconBgColor = Colors.orange.shade50;
      }
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: isRefunded ? Colors.grey.shade100 : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _showTransactionDetails(context, tx, isRefunded),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                // 1. 左側圖示
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: iconBgColor,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: iconColor, size: 12),
                ),
                const SizedBox(width: 18),

                // 2. 中間資訊 (標題 + 時間)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          decoration: isRefunded
                              ? TextDecoration.lineThrough
                              : null,
                          color: isRefunded ? Colors.grey : Colors.black87,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        DateFormat('MM/dd HH:mm').format(tx.createdAt),
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),

                // 3. 右側金額與狀態
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '+${currencyFormat.format(tx.amount)}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isRefunded ? Colors.grey : Colors.green,
                      ),
                    ),
                    const SizedBox(height: 4),
                    // 對帳狀態小標籤
                    TransactionStatusBadge(
                      isReconciled: tx.isReconciled,
                      status: tx.status,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 顯示底部詳情面板
  void _showTransactionDetails(
    BuildContext context,
    TransactionModel tx,
    bool isRefunded,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // 允許內容較長時滾動
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final currencyFormat = NumberFormat("#,##0", "en_US");

        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 頂部標題與金額
              Center(
                child: Column(
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Text(
                      '收款詳情',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '+${currencyFormat.format(tx.amount)}',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: isRefunded ? Colors.grey : Colors.green,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // 詳細資料列表
              _buildDetailRow(
                Icons.person,
                '經手員工',
                tx.operatorFullName ?? '系統自動',
              ),
              _buildDetailRow(
                Icons.account_circle,
                '會員姓名',
                tx.userFullName ?? '未知',
              ),
              if (tx.metadata['course_name'] != null)
                _buildDetailRow(
                  Icons.class_,
                  '課程項目',
                  tx.metadata['course_name'],
                ),
              if (tx.metadata['session_info'] != null)
                _buildDetailRow(
                  Icons.access_time,
                  '上課時間',
                  tx.metadata['session_info'],
                ),
              _buildDetailRow(
                Icons.info_outline,
                '備註說明',
                tx.description ?? '無',
              ),
              _buildDetailRow(
                Icons.calendar_today,
                '交易時間',
                DateFormat('yyyy/MM/dd HH:mm').format(tx.createdAt),
              ),
              if (isRefunded)
                _buildDetailRow(
                  Icons.history,
                  '退款時間',
                  DateFormat('yyyy/MM/dd HH:mm').format(tx.updatedAt!),
                  // textColor: Colors.red.shade700, // 用紅色強調
                ),

              // ✅ 新增：如果是已退款狀態，顯示原因
              if (isRefunded && tx.metadata['refund_reason'] != "")
                _buildDetailRow(
                  Icons.comment_bank, // 或 Icons.notes
                  '退款原因',
                  tx.metadata['refund_reason'],
                  // textColor: Colors.red.shade700,
                ),

              const SizedBox(height: 32),

              // 按鈕區域 (只有 Admin 且符合條件才顯示)
              if (isAdmin && !isRefunded) ...[
                Row(
                  children: [
                    // 退款按鈕 (收入且未退款)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.pop(context); // 關閉面板
                          onRefundTap(tx);
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: const Text('退款 / 作廢'),
                      ),
                    ),

                    if (!tx.isReconciled) const SizedBox(width: 16),

                    // 確認收款按鈕 (收入、未對帳、未退款)
                    if (!tx.isReconciled)
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context); // 關閉面板
                            onReconcileTap(tx);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            elevation: 0,
                          ),
                          child: const Text('確認收款'),
                        ),
                      ),
                  ],
                ),
              ],

              if (isRefunded)
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(12),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    '此筆交易已完成退款',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(
    IconData icon,
    String label,
    String value, {
    Color? textColor,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.grey.shade400),
          const SizedBox(width: 12),
          SizedBox(
            width: 70,
            child: Text(label, style: const TextStyle(color: Colors.grey)),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 15,
                color: textColor ?? Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
