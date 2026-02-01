import 'package:flutter/material.dart';

class StudentInfoRow extends StatelessWidget {
  final IconData icon;
  final String? label;
  final String value;
  final VoidCallback? onEdit;

  const StudentInfoRow({
    super.key,
    required this.icon,
    this.label,
    required this.value,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey.shade600),
        const SizedBox(width: 8),
        Text(
          label != null ? '$label: ' : '',
          style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
        ),
        if (onEdit != null) ...[
          Text(
            value,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.edit, size: 16),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: onEdit,
          ),
        ] else ...[
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ],
    );
  }
}
