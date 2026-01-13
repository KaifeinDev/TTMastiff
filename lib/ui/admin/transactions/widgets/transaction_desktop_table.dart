import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:ttmastiff/data/models/transaction_model.dart';

class TransactionDesktopTable extends StatelessWidget {
  final List<TransactionModel> transactions;
  final Set<String> selectedIds;
  final Function(String id, bool selected) onSelectionChanged;
  final Function(TransactionModel) onRefundTap;
  final bool isAdmin;

  const TransactionDesktopTable({
    super.key,
    required this.transactions,
    required this.selectedIds,
    required this.onSelectionChanged,
    required this.onRefundTap,
    required this.isAdmin,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: SizedBox(
        width: double.infinity,
        child: DataTable(
          showCheckboxColumn: true,
          headingRowColor: MaterialStateProperty.all(Colors.grey.shade200),
          columns: const [
            DataColumn(label: Text('時間')),
            DataColumn(label: Text('經手人')),
            DataColumn(label: Text('客戶')),
            DataColumn(label: Text('項目/課程')),
            DataColumn(label: Text('金額'), numeric: true),
            DataColumn(label: Text('狀態')),
            DataColumn(label: Text('操作')),
          ],
          rows: transactions.map((tx) {
            final isIncome = tx.amount > 0;
            final isRefunded = tx.status == 'refunded'; // 檢查是否已退款
            final isRefundRecord =
                tx.type.contains('refund') || (tx.metadata['type'] == 'refund');

            return DataRow(
              selected: selectedIds.contains(tx.id),
              // 只有未對帳且為收入的項目可以勾選
              onSelectChanged:
                  (!tx.isReconciled && isIncome && !isRefunded && isAdmin)
                  ? (selected) => onSelectionChanged(tx.id, selected ?? false)
                  : null,
              cells: [
                DataCell(Text(DateFormat('MM/dd HH:mm').format(tx.createdAt))),
                DataCell(
                  Row(
                    children: [
                      Icon(Icons.badge, size: 16, color: Colors.grey.shade600),
                      const SizedBox(width: 4),
                      Text(tx.operatorFullName ?? '-'),
                    ],
                  ),
                ),
                DataCell(Text(tx.userFullName ?? '未知')),
                DataCell(
                  SizedBox(
                    width: 150,
                    child: Text(
                      tx.metadata['course_name'] ?? tx.description ?? '-',
                      style: const TextStyle(fontWeight: FontWeight.w500),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                DataCell(
                  Text(
                    '${isIncome ? "+" : ""}${tx.amount}',
                    style: TextStyle(
                      color: isIncome ? Colors.green : Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                DataCell(_buildStatusChip(tx)),
                DataCell(
                  (isAdmin && !isRefunded && !isRefundRecord && isIncome)
                      ? IconButton(
                          icon: const Icon(Icons.undo, color: Colors.grey),
                          tooltip: '退款',
                          onPressed: () => onRefundTap(tx),
                        )
                      : const SizedBox(),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildStatusChip(TransactionModel tx) {
    if (tx.status == 'refunded') {
      return const Chip(
        label: Text('已作廢', style: TextStyle(fontSize: 10, color: Colors.white)),
        backgroundColor: Colors.grey,
        visualDensity: VisualDensity.compact,
      );
    }
    if (tx.isReconciled) {
      return const Chip(
        label: Text('已入庫', style: TextStyle(fontSize: 10)),
        backgroundColor: Colors.greenAccent,
        visualDensity: VisualDensity.compact,
      );
    }
    if (tx.amount < 0) {
      return const Text('-');
    }
    return const Chip(
      label: Text('未收', style: TextStyle(color: Colors.white, fontSize: 10)),
      backgroundColor: Colors.redAccent,
      visualDensity: VisualDensity.compact,
    );
  }
}
