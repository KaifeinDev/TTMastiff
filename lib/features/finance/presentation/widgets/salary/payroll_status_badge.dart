import 'package:flutter/material.dart';
import 'package:ttmastiff/core/utils/util.dart';
import '../../../../../../core/constants/payroll_status.dart';

/// 薪資狀態 Badge Widget
class PayrollStatusBadge extends StatelessWidget {
  final String status;

  const PayrollStatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    String text;

    switch (status) {
      case PayrollStatus.paid:
        color = Colors.green;
        text = '已發放';
        break;
      case PayrollStatus.calculated:
        color = Colors.orange;
        text = '已結算';
        break;
      case PayrollStatus.unsettled:
      default:
        color = Colors.blue;
        text = '未結算';
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
