import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:ttmastiff/data/models/transaction_model.dart';

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
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 80),
      itemCount: transactions.length,
      itemBuilder: (context, index) {
        final tx = transactions[index];
        final isIncome = tx.amount > 0;
        final isRefunded = tx.status == 'refunded';

        return Card(
          color: isRefunded ? Colors.grey.shade200 : null,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: ExpansionTile(
            leading: CircleAvatar(
              backgroundColor: isIncome
                  ? Colors.green.shade50
                  : Colors.orange.shade50,
              child: Icon(
                isIncome ? Icons.attach_money : Icons.money_off,
                color: isIncome ? Colors.green : Colors.orange,
                size: 20,
              ),
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    '${tx.operatorFullName ?? '系統'} ➜ ${tx.userFullName ?? '未知'}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      decoration: isRefunded
                          ? TextDecoration.lineThrough
                          : null, // 刪除線
                      color: isRefunded ? Colors.grey : null,
                    ),
                  ),
                ),
                Text(
                  '${isIncome ? "+" : ""}${tx.amount}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isIncome ? Colors.green : Colors.red,
                  ),
                ),
              ],
            ),
            subtitle: Text(
              DateFormat('MM/dd HH:mm').format(tx.createdAt),
              style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
            ),
            trailing: isIncome
                ? Icon(
                    Icons.check_circle,
                    color: tx.isReconciled
                        ? Colors.green
                        : Colors.grey.shade300,
                  )
                : null,
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInfoRow(
                      '項目',
                      tx.metadata['course_name'] ?? tx.description ?? '',
                    ),
                    if (tx.metadata['session_info'] != null)
                      _buildInfoRow('上課時間', tx.metadata['session_info']),

                    const Divider(),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        // 隱藏 Confirm 按鈕：只有 Admin 且 沒被退款 且 未對帳 才能看
                        if (isAdmin &&
                            isIncome &&
                            !tx.isReconciled &&
                            !isRefunded)
                          OutlinedButton.icon(
                            icon: const Icon(Icons.check),
                            label: const Text('確認收款'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.green,
                            ),
                            onPressed: () => onReconcileTap(tx),
                          ),
                        const SizedBox(width: 8),

                        // 隱藏 Refund 按鈕：只有 Admin 且 沒被退款 才能看
                        if (isAdmin && isIncome && !isRefunded)
                          TextButton(
                            onPressed: () => onRefundTap(tx),
                            child: const Text(
                              '退款',
                              style: TextStyle(color: Colors.red),
                            ),
                          ),

                        if (isRefunded)
                          const Text(
                            '此交易已作廢 (已退款)',
                            style: TextStyle(
                              color: Colors.grey,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 70,
            child: Text(label, style: const TextStyle(color: Colors.grey)),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}
