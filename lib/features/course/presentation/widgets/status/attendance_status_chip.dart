import 'package:flutter/material.dart';
import '../../../../../../core/constants/attendance_status.dart';

/// 出席狀態 Badge Widget
class AttendanceStatusChip extends StatelessWidget {
  final String status;
  final bool showBackground; // 是否顯示背景和邊框

  const AttendanceStatusChip({
    super.key,
    required this.status,
    this.showBackground = true, // 預設顯示背景
  });

  @override
  Widget build(BuildContext context) {
    Color color;
    String text;

    switch (status) {
      case AttendanceStatus.attended:
        color = Colors.green;
        text = '已出席';
        break;
      case AttendanceStatus.absent:
        color = Colors.red;
        text = '曠課';
        break;
      case AttendanceStatus.leave:
        color = Colors.orange;
        text = '請假';
        break;
      case AttendanceStatus.cancelled:
        color = Colors.red; // 改為紅色
        text = '已取消';
        break;
      case AttendanceStatus.ended:
        color = Colors.grey;
        text = '已結束';
        break;
      case AttendanceStatus.inProgress:
        color = Colors.green;
        text = '上課中';
        break;
      case AttendanceStatus.pending:
        color = Colors.blue;
        text = '待上課';
        break;
      default:
        color = Colors.grey;
        text = '待上課';
    }

    if (!showBackground) {
      // 只顯示文字顏色，不顯示背景和邊框
      return Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
