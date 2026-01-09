import 'package:flutter/material.dart';

/// 獨立的 Avatar Widget，避免 NetworkImage 導致持續 rebuild
class StudentAvatar extends StatelessWidget {
  final String? avatarUrl;
  final String name;
  final double radius;

  const StudentAvatar({
    super.key,
    required this.avatarUrl,
    required this.name,
    required this.radius,
  });

  @override
  Widget build(BuildContext context) {
    if (avatarUrl != null && avatarUrl!.isNotEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundImage: NetworkImage(avatarUrl!),
        onBackgroundImageError: (exception, stackTrace) {
          // 圖片加載失敗時使用默認顯示
        },
        child: null, // 有圖片時不顯示文字
      );
    } else {
      return CircleAvatar(
        radius: radius,
        backgroundColor: Colors.grey.shade300,
        child: Text(
          name.isNotEmpty ? name[0] : '?',
          style: TextStyle(fontSize: radius * 0.8),
        ),
      );
    }
  }
}

