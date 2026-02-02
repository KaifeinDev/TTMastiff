import 'package:flutter/material.dart';
import '../../../../core/constants/course_types.dart';

/// 課程類別 Badge Widget
class CourseCategoryBadge extends StatelessWidget {
  final String category;

  const CourseCategoryBadge({
    super.key,
    required this.category,
  });

  @override
  Widget build(BuildContext context) {
    final isPersonal = category == CourseTypes.personal;
    final color = isPersonal ? Colors.purple : Colors.orange;
    final text = isPersonal ? '一對一' : '團體班';

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
