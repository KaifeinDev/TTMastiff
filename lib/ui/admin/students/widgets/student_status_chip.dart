import 'package:flutter/material.dart';

class StudentStatusChip extends StatelessWidget {
  final String status;

  const StudentStatusChip({
    super.key,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    Color color;
    String text;

    switch (status) {
      case 'attended':
        color = Colors.green;
        text = '已出席';
        break;
      case 'absent':
        color = Colors.red;
        text = '缺席';
        break;
      case 'leave':
        color = Colors.orange;
        text = '請假';
        break;
      default:
        color = Colors.grey;
        text = '待上課';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
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

