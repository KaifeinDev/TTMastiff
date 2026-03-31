import 'package:flutter/material.dart';

/// 課程類型共用元件
/// personal -> 一對一 / 紫色
/// group -> 團體班 / 橘色
/// rental -> 租桌 / 綠色
class ClassCategory extends StatelessWidget {
  final String category;
  final bool isArchived;
  final TextStyle? textStyle;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final bool showBorder;

  const ClassCategory({
    super.key,
    required this.category,
    this.isArchived = false,
    this.textStyle,
    this.padding = const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    this.borderRadius = 6,
    this.showBorder = false,
  });

  static String labelOf(String category) {
    switch (category) {
      case 'personal':
        return '一對一';
      case 'rental':
        return '租桌';
      case 'group':
      default:
        return '團體班';
    }
  }

  static Color colorOf(String category) {
    switch (category) {
      case 'personal':
        return Colors.purple;
      case 'rental':
        return Colors.green;
      case 'group':
      default:
        return Colors.orange;
    }
  }

  static Color bgColorOf(String category) {
    switch (category) {
      case 'personal':
        return Colors.purple.shade50;
      case 'rental':
        return Colors.green.shade50;
      case 'group':
      default:
        return Colors.orange.shade50;
    }
  }

  static Color borderColorOf(String category) {
    switch (category) {
      case 'personal':
        return Colors.purple.shade200;
      case 'rental':
        return Colors.green.shade200;
      case 'group':
      default:
        return Colors.orange.shade200;
    }
  }

  static Color textColorOf(String category) {
    switch (category) {
      case 'personal':
        return Colors.purple.shade800;
      case 'rental':
        return Colors.green.shade700;
      case 'group':
      default:
        return Colors.orange.shade800;
    }
  }

  @override
  Widget build(BuildContext context) {
    final label = labelOf(category);

    final bg = isArchived ? Colors.grey.shade300 : bgColorOf(category);
    final borderColor =
        isArchived ? Colors.grey.shade300 : borderColorOf(category);
    final txt = isArchived ? Colors.grey.shade600 : textColorOf(category);

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(borderRadius),
        border: showBorder ? Border.all(color: borderColor) : null,
      ),
      child: Text(
        label,
        style: textStyle ??
            TextStyle(
              fontSize: 12,
              color: txt,
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }
}

