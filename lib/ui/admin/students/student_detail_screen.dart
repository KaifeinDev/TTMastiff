import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:ttmastiff/main.dart';

import '../../../data/models/student_model.dart';
import '../../../data/models/booking_model.dart';
import 'widgets/student_info_row.dart';
import 'widgets/student_status_chip.dart';
import 'widgets/student_avatar.dart';
import '../courses/widgets/session_edit_dialog.dart';
import '../../../core/utils/util.dart';

class StudentDetailScreen extends StatefulWidget {
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

  @override
  State<StudentDetailScreen> createState() => _StudentDetailScreenState();
}

class _StudentDetailScreenState extends State<StudentDetailScreen> {
  // 將 DateFormat 設為靜態常量，避免每次 build 都創建新實例
  static final _dateFormat = DateFormat('yyyy/MM/dd (E)', 'zh_TW');
  static final _timeFormat = DateFormat('HH:mm');

  // 用來顯示即時點數
  int _parentCredits = 0;
  bool _isLoadingCredits = true;

  @override
  void initState() {
    super.initState();
    _loadParentCredits();
  }

  Future<void> _loadParentCredits() async {
    try {
      final credits = await creditRepository.getCurrentCredit(
        widget.student.parentId,
      );
      if (mounted) {
        setState(() {
          _parentCredits = credits;
          _isLoadingCredits = false;
        });
      }
    } catch (e) {
      print('讀取點數失敗: $e');
      if (mounted) setState(() => _isLoadingCredits = false);
    }
  }

  // 顯示儲值 Dialog
  void _showTopUpDialog(BuildContext context) {
    final amountController = TextEditingController();
    final descriptionController = TextEditingController();
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text('儲值點數 (${widget.parentName ?? "家長"})'), // 顯示家長名字
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: '儲值金額/點數',
                    suffixText: '點',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descriptionController,
                  decoration: InputDecoration(
                    labelText: '備註 (選填)',
                    // 自動帶入學生姓名，方便以後查帳知道是為了誰儲值的
                    hintText: '例如：學生 ${widget.student.name} 現金繳費',
                    border: const OutlineInputBorder(),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: isLoading ? null : () => Navigator.pop(context),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: isLoading
                    ? null
                    : () async {
                        final amountText = amountController.text;
                        if (amountText.isEmpty ||
                            int.tryParse(amountText) == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('請輸入有效的數字')),
                          );
                          return;
                        }

                        final amount = int.parse(amountText);
                        setDialogState(() => isLoading = true);

                        try {
                          // 🔥 重點：操作對象是 widget.parentId (Profile) 🔥

                          // 1. 呼叫 Repository 進行儲值
                          final newBalance = await creditRepository.addCredit(
                            userId: widget.student.parentId, // 存入 Profile
                            amount: amount,
                            // 備註若為空，自動補上學生名字
                            description: descriptionController.text.isEmpty
                                ? '${widget.student.name}${widget.student.isPrimary == false ? ' / ${widget.parentName}' : ''} 儲值 ${amount}'
                                : descriptionController.text,
                          );

                          if (mounted) {
                            setState(() {
                              _parentCredits = newBalance;
                            });
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  '成功儲值 $amount 點，目前餘額 $newBalance',
                                ),
                              ),
                            );
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('儲值失敗: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        } finally {
                          if (mounted) setDialogState(() => isLoading = false);
                        }
                      },
                child: isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text('確認儲值'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isSelf = widget.student.isPrimary == true;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.student.name),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      backgroundColor: Colors.grey.shade100,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ─── 方案三：尊榮金幣風 ───
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // 左半部 (頭像與個資) - 維持不變
                      Expanded(
                        child: Row(
                          children: [
                            StudentAvatar(
                              avatarUrl: widget.student.avatarUrl,
                              name: widget.student.name,
                              radius: 32,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.student.name,
                                    style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
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
                                        widget.student.birthDate
                                            .toDateWithAge(),
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
                      ),

                      // 中間分隔線
                      Container(
                        height: 50,
                        width: 1,
                        color: Colors.grey.shade300,
                        margin: const EdgeInsets.symmetric(horizontal: 12),
                      ),

                      // 🔥 右半部：方案三 (Gold) 🔥
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Icon(
                                Icons.monetization_on,
                                color: Colors.amber.shade700,
                                size: 18,
                              ),
                              const SizedBox(width: 4),
                              _isLoadingCredits
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : Text(
                                      NumberFormat(
                                        '#,###',
                                      ).format(_parentCredits),
                                      style: TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.grey.shade800,
                                      ),
                                    ),
                            ],
                          ),
                          Text(
                            'Credits',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.amber.shade800,
                              fontWeight: FontWeight.bold,
                            ),
                          ),

                          const SizedBox(height: 4),
                          SizedBox(
                            height: 24,
                            child: TextButton.icon(
                              onPressed: () => _showTopUpDialog(context),
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              icon: const Icon(Icons.add_card, size: 14),
                              label: const Text(
                                '儲值',
                                style: TextStyle(fontSize: 12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  // 下半部資訊 (維持不變)
                  const SizedBox(height: 16),
                  Divider(height: 1, color: Colors.grey.shade200),
                  const SizedBox(height: 16),
                  StudentInfoRow(
                    icon: Icons.phone,
                    label: isSelf ? '電話' : '家長電話',
                    value: widget.parentPhone ?? '未提供',
                  ),
                  if (!isSelf) ...[
                    const SizedBox(height: 12),
                    StudentInfoRow(
                      icon: Icons.person,
                      label: '家長姓名',
                      value: widget.parentName ?? '未提供',
                    ),
                  ],
                  if (widget.student.medical_note != null &&
                      widget.student.medical_note!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    StudentInfoRow(
                      icon: Icons.medical_information,
                      label: '醫療備註',
                      value: widget.student.medical_note!,
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          // 報名課程列表
          Text(
            '報名課程 (${widget.bookings.length})',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),

          if (widget.bookings.isEmpty)
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
            ...widget.bookings.map((booking) {
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
