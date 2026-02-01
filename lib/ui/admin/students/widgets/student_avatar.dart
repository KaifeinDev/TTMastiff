import 'package:flutter/material.dart';

/// 獨立的 Avatar Widget，使用本人/非本人兩種顏色
class StudentAvatar extends StatelessWidget {
  final String name;
  final double radius;
  final bool isPrimary;

  const StudentAvatar({
    super.key,
    required this.name,
    required this.radius,
    required this.isPrimary,
  });

  @override
  Widget build(BuildContext context) {
    final nameTrimmed = name.trim();
    final initials = nameTrimmed.isEmpty
        ? '?'
        : (nameTrimmed.length >= 2
            ? nameTrimmed.substring(nameTrimmed.length - 2)
            : nameTrimmed);

    return CircleAvatar(
      radius: radius,
      backgroundColor: isPrimary
          ? Theme.of(context).colorScheme.primary
          : Theme.of(context).colorScheme.primary.withOpacity(0.12),
      child: Text(
        initials,
        style: TextStyle(
          fontSize: radius * 0.7,
          fontWeight: FontWeight.w600,
          color: isPrimary
              ? Colors.white
              : Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}

