import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:ttmastiff/main.dart'; // 確保能存取 Repository

class BatchSessionDialog extends StatefulWidget {
  final String courseId;
  final TimeOfDay defaultStartTime;
  final TimeOfDay defaultEndTime;
  final String category; // 'group' or 'personal'
  final int defaultPrice;

  const BatchSessionDialog({
    super.key,
    required this.courseId,
    required this.defaultStartTime,
    required this.defaultEndTime,
    required this.category,
    required this.defaultPrice,
  });

  @override
  State<BatchSessionDialog> createState() => _BatchSessionDialogState();
}

class _BatchSessionDialogState extends State<BatchSessionDialog> {
  DateTimeRange? _dateRange;
  // 紀錄星期幾要上課 (1=週一, 7=週日)
  final Set<int> _selectedWeekdays = {};

  // 教練資料 (配合 Repository 目前回傳 List<Map>)
  List<Map<String, dynamic>> _allCoaches = [];
  final List<String> _selectedCoachIds = [];

  final TextEditingController _capacityController = TextEditingController();
  final TextEditingController _locationController = TextEditingController(
    text: '第1桌',
  );

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchCoaches();
    _updateCapacity(); // 初始化人數
  }

  @override
  void dispose() {
    _capacityController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _fetchCoaches() async {
    try {
      final coaches = await coachRepository.getCoaches();
      if (mounted) {
        setState(() => _allCoaches = coaches);
      }
    } catch (e) {
      debugPrint('Error fetching coaches: $e');
    }
  }

  // 自動計算建議人數
  void _updateCapacity() {
    if (widget.category == 'personal') {
      _capacityController.text = '1';
    } else {
      // 邏輯：團體課 = 教練數 * 4 (若無教練預設為 4)
      int count = _selectedCoachIds.isEmpty ? 1 : _selectedCoachIds.length;
      _capacityController.text = (count * 4).toString();
    }
  }

  // 預覽功能：計算會產生多少堂課
  int _calculateSessionCount() {
    if (_dateRange == null || _selectedWeekdays.isEmpty) return 0;
    int count = 0;

    // 建立不含時間的日期物件，避免跨日問題
    DateTime day = DateTime(
      _dateRange!.start.year,
      _dateRange!.start.month,
      _dateRange!.start.day,
    );
    final endDay = DateTime(
      _dateRange!.end.year,
      _dateRange!.end.month,
      _dateRange!.end.day,
    );

    while (!day.isAfter(endDay)) {
      if (_selectedWeekdays.contains(day.weekday)) {
        count++;
      }
      day = day.add(const Duration(days: 1));
    }
    return count;
  }

  Future<void> _generate() async {
    if (_dateRange == null || _selectedWeekdays.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('請選擇日期範圍與星期')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      List<Map<String, dynamic>> sessionsPayload = [];

      // 確保從日期的 00:00:00 開始計算
      DateTime currentDay = DateTime(
        _dateRange!.start.year,
        _dateRange!.start.month,
        _dateRange!.start.day,
      );

      final endDay = DateTime(
        _dateRange!.end.year,
        _dateRange!.end.month,
        _dateRange!.end.day,
      );

      // 迴圈遍歷每一天
      while (!currentDay.isAfter(endDay)) {
        // 如果這一天是被選中的星期 (ex: 週二)
        if (_selectedWeekdays.contains(currentDay.weekday)) {
          // 組合具體的 StartTime
          final start = DateTime(
            currentDay.year,
            currentDay.month,
            currentDay.day,
            widget.defaultStartTime.hour,
            widget.defaultStartTime.minute,
          );

          // 組合具體的 EndTime
          final end = DateTime(
            currentDay.year,
            currentDay.month,
            currentDay.day,
            widget.defaultEndTime.hour,
            widget.defaultEndTime.minute,
          );

          // 處理跨日問題 (如果結束時間比開始時間早，代表跨日)
          final finalEnd = end.isBefore(start)
              ? end.add(const Duration(days: 1))
              : end;

          sessionsPayload.add({
            'start_time': start.toUtc().toIso8601String(),
            'end_time': finalEnd.toUtc().toIso8601String(),
            'coach_ids': _selectedCoachIds, // Supabase 支援直接傳 List
            'location': _locationController.text,
            'max_capacity': int.tryParse(_capacityController.text) ?? 4,
            'price': widget.defaultPrice,
          });
        }
        currentDay = currentDay.add(const Duration(days: 1));
      }

      // 批次寫入 DB
      // 這裡傳 Map 是正確的，因為 Create 不需要 Model
      await sessionRepository.batchCreateSessions(
        courseId: widget.courseId,
        sessionsData: sessionsPayload,
      );

      if (mounted) Navigator.pop(context, true); // 回傳 true 代表成功
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('排課失敗: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('批次排課'),
      content: SizedBox(
        width: 500,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // 1. 日期範圍選擇
              ListTile(
                title: Text(
                  _dateRange == null
                      ? '點擊選擇日期範圍 (Start - End)'
                      : '${DateFormat('yyyy/MM/dd').format(_dateRange!.start)} - ${DateFormat('yyyy/MM/dd').format(_dateRange!.end)}',
                  style: TextStyle(
                    color: _dateRange == null ? Colors.grey : Colors.black,
                  ),
                ),
                leading: const Icon(Icons.date_range, color: Colors.blue),
                tileColor: Colors.blue.shade50,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                onTap: () async {
                  final range = await showDateRangePicker(
                    context: context,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                    helpText: '選擇課程區間',
                  );
                  if (range != null) setState(() => _dateRange = range);
                },
              ),
              const SizedBox(height: 16),

              // 2. 星期選擇 (Checkbox)
              const Text(
                '重複規則 (每週)：',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  for (int i = 1; i <= 7; i++)
                    FilterChip(
                      label: Text(_weekdayName(i)),
                      selected: _selectedWeekdays.contains(i),
                      selectedColor: Colors.blue.shade100,
                      checkmarkColor: Colors.blue,
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            _selectedWeekdays.add(i);
                          } else {
                            _selectedWeekdays.remove(i);
                          }
                        });
                      },
                    ),
                ],
              ),
              const Divider(height: 30),

              // 3. 該批次場次的設定
              const Text(
                '場次詳細設定',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),

              // 教練選擇
              const Text(
                '指定教練：',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 4),
              _allCoaches.isEmpty
                  ? const Text(
                      '載入教練中或無教練資料',
                      style: TextStyle(color: Colors.grey),
                    )
                  : Wrap(
                      spacing: 8,
                      children: _allCoaches.map((coach) {
                        final coachId = coach['id'] as String;
                        final coachName = coach['full_name'] ?? '未命名';
                        final isSelected = _selectedCoachIds.contains(coachId);

                        return ChoiceChip(
                          label: Text(coachName),
                          selected: isSelected,
                          onSelected: (selected) {
                            setState(() {
                              if (selected) {
                                _selectedCoachIds.add(coachId);
                              } else {
                                _selectedCoachIds.remove(coachId);
                              }
                              _updateCapacity(); // 連動人數
                            });
                          },
                        );
                      }).toList(),
                    ),
              const SizedBox(height: 16),

              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _locationController,
                      decoration: const InputDecoration(
                        labelText: '桌次 / 地點',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextField(
                      controller: _capacityController,
                      decoration: const InputDecoration(
                        labelText: '人數上限',
                        border: OutlineInputBorder(),
                        isDense: true,
                        suffixText: '人',
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),
              // 預覽文字
              if (_dateRange != null && _selectedWeekdays.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.amber.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.lightbulb, color: Colors.amber.shade800),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '預計產生 ${_calculateSessionCount()} 堂課程\n'
                          '時間：${widget.defaultStartTime.format(context)} - ${widget.defaultEndTime.format(context)}',
                          style: TextStyle(
                            color: Colors.amber.shade900,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _generate,
          style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : const Text('確認生成', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }

  String _weekdayName(int day) {
    const names = ['週一', '週二', '週三', '週四', '週五', '週六', '週日'];
    return names[day - 1];
  }
}
