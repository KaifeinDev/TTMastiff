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
    const headerStyle = TextStyle(
      fontWeight: FontWeight.bold,
      color: Colors.black87,
    );

    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: SizedBox(
        width: double.infinity,
        child: DataTable(
          showCheckboxColumn: true,
          headingRowColor: MaterialStateProperty.all(Colors.grey.shade100),
          dataRowMinHeight: 60,
          dataRowMaxHeight: 84, // 🔥 加高行高，以容納退款時間與理由
          columnSpacing: 24,
          columns: const [
            DataColumn(label: Text('時間', style: headerStyle)),
            DataColumn(label: Text('經手員工', style: headerStyle)),
            DataColumn(label: Text('客戶', style: headerStyle)),
            DataColumn(label: Text('項目/說明', style: headerStyle)),
            DataColumn(label: Text('金額', style: headerStyle), numeric: true),
            DataColumn(label: Text('狀態', style: headerStyle)),
            DataColumn(label: Text('操作', style: headerStyle)),
          ],
          rows: transactions.map((tx) {
            final isRefunded = tx.status == 'refunded';
            final currencyFormat = NumberFormat("#,##0", "en_US");

            // 判斷是否可勾選：必須是 (未對帳 + 未作廢 + 管理員)
            final canSelect = !tx.isReconciled && !isRefunded && isAdmin;

            return DataRow(
              selected: selectedIds.contains(tx.id),
              onSelectChanged: canSelect
                  ? (selected) => onSelectionChanged(tx.id, selected ?? false)
                  : null,
              cells: [
                // 1. 時間 (🔥 新增：退款時間顯示)
                DataCell(
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          DateFormat('yyyy/MM/dd').format(tx.createdAt),
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        Text(
                          DateFormat('HH:mm').format(tx.createdAt),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade500,
                          ),
                        ),
                        // 如果已退款且有時間，顯示紅字時間
                        if (isRefunded && tx.updatedAt != null) ...[
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '退於 ${DateFormat('MM/dd HH:mm').format(tx.updatedAt!)}',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.red.shade400,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                // 2. 經手人
                DataCell(
                  Row(
                    children: [
                      Icon(
                        Icons.badge_outlined,
                        size: 16,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(width: 6),
                      Text(tx.operatorFullName ?? '-'),
                    ],
                  ),
                ),

                // 3. 客戶
                DataCell(
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 12,
                        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                        child: Text(
                          (tx.userFullName ?? 'U').substring(0, 1),
                          style: TextStyle(
                            fontSize: 10,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(tx.userFullName ?? '未知'),
                    ],
                  ),
                ),

                // 4. 項目/說明 (🔥 新增：退款理由顯示)
                DataCell(
                  SizedBox(
                    width: 200,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Tooltip(
                          message:
                              tx.metadata['course_name'] ??
                              tx.description ??
                              '',
                          child: Text(
                            tx.metadata['course_name'] ?? tx.description ?? '-',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              decoration: isRefunded
                                  ? TextDecoration.lineThrough
                                  : null,
                              color: isRefunded ? Colors.grey : Colors.black87,
                            ),
                          ),
                        ),
                        // 如果有退款理由，顯示在下方
                        if (isRefunded && tx.metadata['refund_reason'] != '')
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Tooltip(
                              message: '退款理由: ${tx.metadata['refund_reason']}',
                              child: Text(
                                '理由: ${tx.metadata['refund_reason']}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.red.shade300,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),

                // 5. 金額
                DataCell(
                  Text(
                    '+${currencyFormat.format(tx.amount)}',
                    style: TextStyle(
                      color: isRefunded ? Colors.grey : Colors.green.shade700,
                      fontWeight: FontWeight.bold,
                      decoration: isRefunded
                          ? TextDecoration.lineThrough
                          : null,
                      fontFamily: 'Roboto',
                    ),
                  ),
                ),

                // 6. 狀態
                DataCell(_buildStatusChip(tx)),

                // 7. 操作
                DataCell(
                  (isAdmin && !isRefunded)
                      ? IconButton(
                          icon: const Icon(Icons.undo_rounded),
                          color: Colors.red.shade400,
                          tooltip: '退款 / 作廢',
                          splashRadius: 20,
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
    final isRefunded = tx.status == 'refunded';

    Color bgColor;
    Color textColor;
    IconData icon;
    String label;

    if (isRefunded) {
      // [已作廢] -> 灰色
      bgColor = Colors.grey.shade100;
      textColor = Colors.grey;
      icon = Icons.block;
      label = '已作廢';
    } else if (tx.isReconciled) {
      // [已收款] -> 綠色
      bgColor = Colors.green.shade50;
      textColor = Colors.green.shade700;
      icon = Icons.check_circle_outline;
      label = '已收款';
    } else {
      // [待收款] -> 紅色
      bgColor = Colors.orange.shade50;
      textColor = Colors.orange.shade800;
      icon = Icons.add_circle_outline;
      label = '待收款';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: textColor.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: textColor),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: textColor,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
