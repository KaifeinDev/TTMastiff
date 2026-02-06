import 'package:flutter/material.dart';
import 'package:ttmastiff/core/utils/util.dart';
import '../../data/models/student_model.dart';
import '../../../../../core/utils/util.dart';
import 'student_avatar.dart';
import '../../../../core/widgets/gender_icon.dart';

/// 學員列表項目 Widget（用於 profile, student_list_screen, homepage）
class StudentListItem extends StatelessWidget {
  final StudentModel student;
  final bool isPrimary;
  final VoidCallback? onTap;
  final String? medicalNote;
  final String? parentPhone; // 用於 admin 顯示家長電話
  final bool showPoints; // 是否顯示點數
  final String? membership; // 會員等級
  final EdgeInsets? margin; // 自訂 margin
  final EdgeInsets? padding; // 自訂 padding（用於 ListTile 內部）
  final double? elevation; // 自訂 elevation

  const StudentListItem({
    super.key,
    required this.student,
    this.isPrimary = false,
    this.onTap,
    this.medicalNote,
    this.parentPhone,
    this.showPoints = true,
    this.membership,
    this.margin,
    this.padding,
    this.elevation,
  });

  @override
  Widget build(BuildContext context) {
    final hasNote = medicalNote != null && medicalNote!.isNotEmpty;
    final heroTag = 'avatar_${student.id}';

    return Card(
      margin: margin ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.white,
      elevation: elevation ?? 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: padding,
        leading: StudentAvatar(
          name: student.name,
          isPrimary: isPrimary,
          heroTag: heroTag,
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              student.name,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            if (student.gender != null) ...[
              const SizedBox(width: 4),
              GenderIcon(gender: student.gender),
            ],
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.cake_outlined,
                  size: parentPhone != null ? 16 : 14,
                  color: Colors.grey.shade600,
                ),
                const SizedBox(width: 4),
                Text(
                  student.birthDate.toDateWithAge(),
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: parentPhone != null ? 14 : 14,
                  ),
                ),
              ],
            ),
            if (parentPhone != null && parentPhone!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(
                    Icons.phone_outlined,
                    size: 16,
                    color: Colors.grey.shade600,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    parentPhone!,
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                  ),
                ],
              ),
            ],
            if (showPoints) ...[
              const SizedBox(height: 2),
              Row(
                children: [
                  const Icon(Icons.stars, size: 14, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    '${student.points}',
                    style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
                  ),
                ],
              ),
            ],
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (hasNote)
              Tooltip(
                message: medicalNote!,
                child: Icon(
                  Icons.medical_information,
                  size: 24,
                  color: Colors.redAccent,
                ),
              ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
        onTap: onTap,
      ),
    );
  }
}
