import 'package:flutter/material.dart';

/// 學員頭像 Widget（用於列表顯示）
class StudentAvatar extends StatelessWidget {
  final String name;
  final bool isPrimary;
  final double radius;
  final String? heroTag;

  const StudentAvatar({
    super.key,
    required this.name,
    this.isPrimary = false,
    this.radius = 25,
    this.heroTag,
  });

  @override
  Widget build(BuildContext context) {
    final name = this.name.trim();
    final initials = name.isEmpty
        ? '?'
        : (name.length >= 2 ? name.substring(name.length - 2) : name);

    final avatar = CircleAvatar(
      radius: radius,
      backgroundColor: isPrimary
          ? Theme.of(context).colorScheme.primary
          : Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
      child: Text(
        initials,
        style: TextStyle(
          fontSize: radius * 0.72,
          fontWeight: FontWeight.w600,
          color: isPrimary
              ? Colors.white
              : Theme.of(context).colorScheme.primary,
        ),
      ),
    );

    if (heroTag != null) {
      return Hero(tag: heroTag!, child: avatar);
    }

    return avatar;
  }
}
