import 'package:flutter/material.dart';
import 'package:ttmastiff/core/utils/util.dart';

class TransactionFilterBar extends StatelessWidget {
  final bool? currentFilter; // null=全部, false=未對帳, true=已對帳
  final bool hasSelection; // 是否有勾選項目
  final ValueChanged<bool?> onFilterChanged;
  final VoidCallback onClearSelection;

  const TransactionFilterBar({
    super.key,
    required this.currentFilter,
    required this.hasSelection,
    required this.onFilterChanged,
    required this.onClearSelection,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _buildFilterChip('全部', null),
        const SizedBox(width: 8),
        _buildFilterChip('未對帳', false),
        const SizedBox(width: 8),
        _buildFilterChip('已對帳', true),

        // 如果有勾選項目，顯示取消按鈕
        if (hasSelection) ...[
          const VerticalDivider(width: 20),
          TextButton.icon(
            onPressed: onClearSelection,
            icon: const Icon(Icons.close, size: 16),
            label: const Text('取消勾選'),
            style: TextButton.styleFrom(
              foregroundColor: Colors.grey,
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildFilterChip(String label, bool? value) {
    final isSelected = currentFilter == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      showCheckmark: false, // 不顯示打勾符號，比較清爽
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.black87,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        fontSize: 12,
      ),
      backgroundColor: Colors.grey.shade100,
      selectedColor: Colors.blueGrey.shade700,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      onSelected: (_) => onFilterChanged(value),
    );
  }
}
