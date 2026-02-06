import 'package:flutter/material.dart';
import '../../../../../../core/constants/course_types.dart';

/// 課程類別工具函數
class CourseCategoryUtils {
  /// 根據課程類別返回主題顏色
  static Color getCategoryColor(String category) {
    final isPersonal = category == CourseTypes.personal;
    return isPersonal ? Colors.purple : Colors.orange;
  }

  /// 根據課程類別返回是否為個人班
  static bool isPersonal(String category) {
    return category == CourseTypes.personal;
  }

  /// 根據課程類別返回顯示文字
  static String getCategoryText(String category) {
    final isPersonal = category == CourseTypes.personal;
    return isPersonal ? '一對一' : '團體班';
  }
}

/// 課程類別 Badge Widget
class CourseCategoryBadge extends StatelessWidget {
  final String category;

  const CourseCategoryBadge({
    super.key,
    required this.category,
  });

  @override
  Widget build(BuildContext context) {
    final color = CourseCategoryUtils.getCategoryColor(category);
    final text = CourseCategoryUtils.getCategoryText(category);

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
