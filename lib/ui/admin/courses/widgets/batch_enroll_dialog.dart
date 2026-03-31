import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:ttmastiff/core/utils/util.dart';
import 'package:ttmastiff/main.dart'; // 取得 bookingRepository
import '../../../../data/models/session_model.dart';
import '../../../../data/models/student_model.dart';
import 'student_search_dialog.dart'; // 🔥 引入剛剛建立的搜尋視窗

class BatchEnrollDialog extends StatefulWidget {
  final String courseId;
  final String courseTitle;
  final int pricePerSession;
  final List<SessionModel> upcomingSessions;

  const BatchEnrollDialog({
    super.key,
    required this.courseId,
    required this.courseTitle,
    required this.pricePerSession,
    required this.upcomingSessions,
  });

  @override
  State<BatchEnrollDialog> createState() => _BatchEnrollDialogState();
}

class _BatchEnrollDialogState extends State<BatchEnrollDialog> {
  // 🔥 改成：已選擇的學生列表 (手動加入)
  final List<StudentModel> _targetStudents = [];

  // 選取的場次 ID
  final Set<String> _selectedSessionIds = {};

  bool _isSubmitting = false;

  String _formatStudentNames(List<StudentModel> students) {
    if (students.isEmpty) return '';
    if (students.length <= 5) {
      return students.map((s) => s.name).join('、');
    }
    final first = students.take(5).map((s) => s.name).join('、');
    return '$first 等 ${students.length} 人';
  }

  // 開啟搜尋視窗
  Future<void> _openSearchDialog() async {
    final existingIds = _targetStudents.map((s) => s.id).toSet();

    // 開啟搜尋 Dialog，並等待回傳結果
    final StudentModel? selectedStudent = await showDialog(
      context: context,
      builder: (context) =>
          StudentSearchDialog(existingStudentIds: existingIds),
    );

    if (selectedStudent != null) {
      setState(() {
        _targetStudents.add(selectedStudent);
      });
    }
  }

  // 移除學生
  void _removeStudent(StudentModel student) {
    setState(() {
      _targetStudents.removeWhere((s) => s.id == student.id);
    });
  }

  // 提交報名
  Future<void> _submit() async {
    if (_selectedSessionIds.isEmpty || _targetStudents.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('請至少選擇一位學員和一堂課程')));
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      // Phase 1：批次報名點數不足的「前端攔截」
      // BookingRepository 端如果餘額不足會直接 throw，導致整批失敗；
      // 這裡先計算每位學員「需要的扣點」(單堂扣點 * 選擇場次數)，只送餘額足夠者進後端。
      final int sessionCount = _selectedSessionIds.length;
      final int perStudentCost = widget.pricePerSession * sessionCount;

      // 逐一扣預算：同一個 parentId 可能有多位學生，因此要用 remainingCredits 逐筆分配。
      final Set<String> parentIds =
          _targetStudents.map((s) => s.parentId).toSet();
      final creditsEntries = await Future.wait(
        parentIds.map(
          (parentId) async => MapEntry(
            parentId,
            await creditRepository.getCurrentCredit(parentId),
          ),
        ),
      );
      final Map<String, int> remainingCredits = Map.fromEntries(creditsEntries);

      final List<StudentModel> eligibleStudents = [];
      final List<StudentModel> insufficientStudents = [];

      for (final student in _targetStudents) {
        final remaining = remainingCredits[student.parentId] ?? 0;
        if (remaining >= perStudentCost) {
          eligibleStudents.add(student);
          remainingCredits[student.parentId] = remaining - perStudentCost;
        } else {
          insufficientStudents.add(student);
        }
      }

      if (eligibleStudents.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: Colors.red.shade700,
              content: Text(
                '餘額不足，無法完成批次報名。\n略過：${_formatStudentNames(insufficientStudents)}',
              ),
              duration: const Duration(seconds: 4),
            ),
          );
        }
        return;
      }

      final result = await bookingRepository.createBatchBooking(
        sessionIds: _selectedSessionIds.toList(),
        // 只送餘額足夠的學員去後端扣點
        studentIds: eligibleStudents.map((s) => s.id).toList(),
        priceSnapshot: widget.pricePerSession,
      );

      final successCount = (result['success'] ?? 0) as int;
      final totalCost = (result['totalCost'] ?? 0) as int;
      final alreadyBookedIds =
          (result['alreadyBooked'] as List<dynamic>? ?? []).cast<String>();
      final conflictedIds =
          (result['conflicted'] as List<dynamic>? ?? []).cast<String>();

      List<StudentModel> studentsFromIds(Iterable<String> ids) {
        final idSet = ids.toSet();
        return _targetStudents.where((s) => idSet.contains(s.id)).toList();
      }

      final alreadyBookedStudents = studentsFromIds(alreadyBookedIds);
      final conflictedStudents = studentsFromIds(conflictedIds);

      if (mounted) {
        String message;
        Color snackBarColor;
        if (successCount > 0) {
          // A. 有成功新增 (綠色)
          snackBarColor = Colors.green;
          message = '報名作業完成！\n成功: $successCount 堂，扣除 $totalCost 點';

          if (alreadyBookedStudents.isNotEmpty) {
            message +=
                '\n已報名：${_formatStudentNames(alreadyBookedStudents)}';
          }
          if (conflictedStudents.isNotEmpty) {
            message +=
                '\n同時段已有課程：${_formatStudentNames(conflictedStudents)}';
          }

          if (insufficientStudents.isNotEmpty) {
            message += '\n(另有 ${insufficientStudents.length} 位餘額不足：${_formatStudentNames(insufficientStudents)} 已略過)';
          }
        } else {
          // B. 沒有任何成功新增：全部都是重複 / 衝堂
          snackBarColor = Colors.grey.shade700;
          message = '沒有新增任何報名';

          if (alreadyBookedStudents.isNotEmpty) {
            message +=
                '\n已報名：${_formatStudentNames(alreadyBookedStudents)}';
          }
          if (conflictedStudents.isNotEmpty) {
            message +=
                '\n同時段已有課程：${_formatStudentNames(conflictedStudents)}';
          }

          if (insufficientStudents.isNotEmpty) {
            message += '\n(另有 ${insufficientStudents.length} 位餘額不足：${_formatStudentNames(insufficientStudents)} 已略過)';
          }
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: snackBarColor,
            duration: const Duration(seconds: 3),
          ),
        );

        // 關閉視窗
        // 因為是 Dialog，成功執行(包含全部略過)後通常會關閉，並回傳 true 通知上一頁刷新
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(context, e, prefix: '報名失敗：');
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalCost =
        _selectedSessionIds.length *
        _targetStudents.length *
        widget.pricePerSession;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 900,
        height: 700,
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Header
            Row(
              children: [
                Icon(
                  Icons.checklist_rtl_rounded,
                  color: Theme.of(context).primaryColor,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '批次報名',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '課程：${widget.courseTitle}',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ],
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const Divider(height: 32),

            // Content
            Expanded(
              child: Row(
                children: [
                  // ─── 左側：選擇場次 ───
                  Expanded(
                    flex: 4,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeader(
                          '1. 選擇場次',
                          _selectedSessionIds.length,
                          widget.upcomingSessions.length,
                          onToggleAll: () {
                            setState(() {
                              if (_selectedSessionIds.length ==
                                  widget.upcomingSessions.length) {
                                _selectedSessionIds.clear();
                              } else {
                                _selectedSessionIds.addAll(
                                  widget.upcomingSessions.map((s) => s.id),
                                );
                              }
                            });
                          },
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: widget.upcomingSessions.isEmpty
                              ? const Center(child: Text('無未來場次'))
                              : ListView.separated(
                                  itemCount: widget.upcomingSessions.length,
                                  separatorBuilder: (context, _) =>
                                      const Divider(height: 1),
                                  itemBuilder: (context, index) {
                                    final session =
                                        widget.upcomingSessions[index];
                                    final isSelected = _selectedSessionIds
                                        .contains(session.id);
                                    final dateStr = DateFormat(
                                      'MM/dd (E) HH:mm',
                                      'zh_TW',
                                    ).format(session.startTime);

                                    return CheckboxListTile(
                                      value: isSelected,
                                      activeColor: Colors.blue,
                                      contentPadding: EdgeInsets.zero,
                                      title: Text(
                                        dateStr,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      subtitle: Text(
                                        '剩餘名額: ${session.remainingCapacity}',
                                        style: TextStyle(
                                          color: session.remainingCapacity <= 0
                                              ? Colors.red
                                              : Colors.grey,
                                        ),
                                      ),
                                      onChanged: (val) {
                                        setState(() {
                                          if (val == true) {
                                            _selectedSessionIds.add(session.id);
                                          } else {
                                            _selectedSessionIds.remove(
                                              session.id,
                                            );
                                          }
                                        });
                                      },
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
                  ),

                  const VerticalDivider(width: 40, thickness: 1),

                  // ─── 右側：已選學生清單 (透過搜尋加入) ───
                  Expanded(
                    flex: 5,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '2. 指定學生 (${_targetStudents.length})',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            // 🔥 新增學生按鈕
                            ElevatedButton.icon(
                              onPressed: _openSearchDialog,
                              icon: const Icon(Icons.person_add, size: 16),
                              label: const Text('新增學員'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange.shade50,
                                foregroundColor: Colors.orange.shade800,
                                elevation: 0,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // 學生列表 (顯示已加入的)
                        Expanded(
                          child: _targetStudents.isEmpty
                              ? Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.groups_outlined,
                                        size: 48,
                                        color: Colors.grey.shade200,
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        '尚未加入任何學生',
                                        style: TextStyle(
                                          color: Colors.grey.shade400,
                                        ),
                                      ),
                                      Text(
                                        '請點擊右上方按鈕新增',
                                        style: TextStyle(
                                          color: Colors.grey.shade400,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : ListView.builder(
                                  itemCount: _targetStudents.length,
                                  itemBuilder: (context, index) {
                                    final student = _targetStudents[index];
                                    return Card(
                                      margin: const EdgeInsets.only(bottom: 8),
                                      elevation: 0,
                                      color: Colors.grey.shade50,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        side: BorderSide(
                                          color: Colors.grey.shade200,
                                        ),
                                      ),
                                      child: ListTile(
                                        leading: CircleAvatar(
                                          backgroundColor:
                                              Colors.orange.shade100,
                                          foregroundColor:
                                              Colors.orange.shade800,
                                          child: Text(
                                            student.name.substring(0, 1),
                                          ),
                                        ),
                                        title: Text(student.name),
                                        trailing: IconButton(
                                          icon: const Icon(
                                            Icons.remove_circle_outline,
                                            color: Colors.red,
                                          ),
                                          onPressed: () =>
                                              _removeStudent(student),
                                          tooltip: '移除',
                                        ),
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(),

            // Footer
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '共 ${_targetStudents.length} 人 x ${_selectedSessionIds.length} 堂',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '總計扣點: $totalCost',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 24),
                OutlinedButton(
                  onPressed: _isSubmitting
                      ? null
                      : () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                  ),
                  child: const Text('取消'),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed:
                      (_isSubmitting ||
                          _selectedSessionIds.isEmpty ||
                          _targetStudents.isEmpty)
                      ? null
                      : _submit,
                  icon: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.check_circle_outline),
                  label: const Text('確認報名'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(
    String title,
    int count,
    int total, {
    required VoidCallback onToggleAll,
  }) {
    final isAll = total > 0 && count == total;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          '$title ($count)',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        TextButton(onPressed: onToggleAll, child: Text(isAll ? '取消全選' : '全選')),
      ],
    );
  }
}
