import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:ttmastiff/core/di/service_locator.dart';
import 'package:ttmastiff/features/booking/data/repositories/booking_repository.dart';
import '../../../data/models/session_model.dart';
import '../../../../student/data/models/student_model.dart';
import '../../../../student/presentation/widgets/student_search_dialog.dart'; 

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
  final bookingRepository = getIt<BookingRepository>();

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
      final result = await bookingRepository.createBatchBooking(
        sessionIds: _selectedSessionIds.toList(),
        studentIds: _targetStudents.map((s) => s.id).toList(), // 🔥 取出 ID
        priceSnapshot: widget.pricePerSession,
      );

      final successCount = result['success'] ?? 0;
      final skippedCount = result['skipped'] ?? 0;
      final totalCost = result['totalCost'] ?? 0;

      if (mounted) {
        String message;
        Color snackBarColor;
        if (successCount > 0) {
          // A. 有成功新增 (綠色)
          snackBarColor = Colors.green;
          message = '報名作業完成！\n成功: $successCount 堂，扣除 $totalCost 點';

          if (skippedCount > 0) {
            message += '\n(另有 $skippedCount 堂因重複而略過)';
          }
        } else {
          // B. 全部都是重複，沒有任何變動 (灰色)
          snackBarColor = Colors.grey.shade700;
          message = '沒有新增任何報名\n(所有選擇的項目皆已報名過)';
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
        // 5. 失敗處理 (紅色) - 不關閉視窗，讓使用者可以重試
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('報名失敗: $e'), backgroundColor: Colors.red),
        );
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
    
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Dialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16 : 24,
        vertical: isMobile ? 24 : 40,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final maxWidth = constraints.maxWidth.clamp(320, isMobile ? double.infinity : 900).toDouble();
          final maxHeight = constraints.maxHeight.clamp(400, isMobile ? double.infinity : 700).toDouble();
          
          return SizedBox(
            width: maxWidth,
            height: maxHeight,
            child: Padding(
              padding: EdgeInsets.all(isMobile ? 16 : 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
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
                      Expanded(
                        child: Column(
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
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const Divider(height: 32),

                  // Content
                  Expanded(
                    child: isMobile
                        ? SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // 選擇場次
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
                                Container(
                                  constraints: BoxConstraints(
                                    maxHeight: 200,
                                  ),
                                  child: widget.upcomingSessions.isEmpty
                                      ? const Center(child: Text('無未來場次'))
                                      : ListView.separated(
                                          shrinkWrap: true,
                                          itemCount: widget.upcomingSessions.length,
                                          separatorBuilder: (_, __) =>
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
                                              activeColor: Theme.of(context).colorScheme.primary,
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
                                                      ? Colors.red.shade700
                                                      : Colors.grey,
                                                ),
                                              ),
                                              onChanged: (val) {
                                                setState(() {
                                                  if (val == true)
                                                    _selectedSessionIds.add(session.id);
                                                  else
                                                    _selectedSessionIds.remove(
                                                      session.id,
                                                    );
                                                });
                                              },
                                            );
                                          },
                                        ),
                                ),
                                const SizedBox(height: 24),
                                const Divider(),
                                const SizedBox(height: 16),
                                
                                // 指定學生
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
                                    ElevatedButton.icon(
                                      onPressed: _openSearchDialog,
                                      icon: const Icon(Icons.person_add, size: 16),
                                      label: const Text('新增學員'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                                        foregroundColor: Theme.of(context).colorScheme.primary,
                                        elevation: 0,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  constraints: BoxConstraints(
                                    maxHeight: 200,
                                  ),
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
                                          shrinkWrap: true,
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
                                                      Theme.of(context).colorScheme.primaryContainer,
                                                  foregroundColor:
                                                      Theme.of(context).colorScheme.primary,
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
                          )
                        : Row(
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
                                              separatorBuilder: (_, __) =>
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
                                                  activeColor: Theme.of(context).colorScheme.primary,
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
                                                          ? Colors.red.shade700
                                                          : Colors.grey,
                                                    ),
                                                  ),
                                                  onChanged: (val) {
                                                    setState(() {
                                                      if (val == true)
                                                        _selectedSessionIds.add(session.id);
                                                      else
                                                        _selectedSessionIds.remove(
                                                          session.id,
                                                        );
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
                                            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                                            foregroundColor: Theme.of(context).colorScheme.primary,
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
                                                          Theme.of(context).colorScheme.primaryContainer,
                                                      foregroundColor:
                                                          Theme.of(context).colorScheme.primary,
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
                  Padding(
                    padding: EdgeInsets.only(top: isMobile ? 8 : 0),
                    child: Row(
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
                                fontSize: 16,
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
                          label: const Text('報名'),
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
                  ),
                ],
              ),
            ),
          );
        },
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
