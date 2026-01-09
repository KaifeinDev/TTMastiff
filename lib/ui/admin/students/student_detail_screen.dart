import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../data/models/student_model.dart';
import '../../../data/models/booking_model.dart';
import 'widgets/student_info_row.dart';
import 'widgets/student_status_chip.dart';
import 'widgets/student_avatar.dart';
import '../courses/widgets/session_edit_dialog.dart';
import '../../../core/utils/util.dart';

class StudentDetailScreen extends StatelessWidget {
  final StudentModel student;
  final String? parentPhone;
  final String? parentName;
  final List<BookingModel> bookings;

  const StudentDetailScreen({
    super.key,
    required this.student,
    this.parentPhone,
    this.parentName,
    required this.bookings,
  });

  // 將 DateFormat 設為靜態常量，避免每次 build 都創建新實例
  static final _dateFormat = DateFormat('yyyy/MM/dd (E)', 'zh_TW');
  static final _timeFormat = DateFormat('HH:mm');

  @override
  Widget build(BuildContext context) {
    // 判斷學員是否為本人（註冊者）
    // 如果 student.name == parentName，則為本人
    final isSelf = parentName != null && 
                  parentName!.trim().isNotEmpty &&
                  student.name.trim() == parentName!.trim();

    return Scaffold(
      appBar: AppBar(
        title: Text(student.name),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      backgroundColor: Colors.grey.shade100,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 學員基本資訊卡片
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      StudentAvatar(
                        avatarUrl: student.avatarUrl,
                        name: student.name,
                        radius: 40,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              student.name,
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(
                                  Icons.cake_outlined,
                                  size: 16,
                                  color: Colors.grey.shade600,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  student.birthDate.toDateWithAge(),
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 32),
                  // 如果是本人，只顯示電話；如果不是本人，顯示家長電話和家長姓名
                  StudentInfoRow(
                    icon: Icons.phone,
                    label: isSelf ? '電話' : '家長電話',
                    value: parentPhone ?? '未提供',
                  ),
                  if (!isSelf) ...[
                    const SizedBox(height: 12),
                    StudentInfoRow(
                      icon: Icons.person,
                      label: '家長姓名',
                      value: parentName ?? '未提供',
                    ),
                  ],
                  if (student.medical_note != null && student.medical_note!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    StudentInfoRow(
                      icon: Icons.medical_information,
                      label: '醫療備註',
                      value: student.medical_note!,
                    ),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // 報名課程列表
          Text(
            '報名課程 (${bookings.length})',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 12),

          if (bookings.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Center(
                  child: Text(
                    '尚未報名任何課程',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ),
              ),
            )
          else
            ...bookings.map((booking) {
              final session = booking.session;
              final course = session.course;
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                elevation: 1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: course != null
                      ? () {
                          // 直接打開該場次的對話框
                          final category = course.category;
                          showDialog(
                            context: context,
                            builder: (dialogContext) => SessionEditDialog(
                              session: session,
                              category: category,
                            ),
                          );
                        }
                      : null,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                course?.title ?? '未知課程',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            if (course != null)
                              const Icon(
                                Icons.arrow_forward_ios,
                                size: 16,
                                color: Colors.blue,
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(
                              Icons.calendar_today,
                              size: 16,
                              color: Colors.grey.shade600,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${_dateFormat.format(session.startTime)} ${_timeFormat.format(session.startTime)} - ${_timeFormat.format(session.endTime)}',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.attach_money,
                              size: 16,
                              color: Colors.grey.shade600,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '\$${booking.price_snapshot}',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 14,
                              ),
                            ),
                            const Spacer(),
                            StudentStatusChip(status: booking.attendanceStatus),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}

