import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:ttmastiff/main.dart'; // 確保能存取 Repository
import 'package:ttmastiff/data/models/table_model.dart';
import 'package:flutter/services.dart';
import '../../../../core/utils/util.dart';

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
  List<TableModel> _tables = [];
  List<String> _selectedTableIds = [];
  bool _isLoadingTables = true;

  final TextEditingController _capacityController = TextEditingController();
  // final TextEditingController _locationController = TextEditingController(
  //   text: '第1桌',
  // );

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchCoaches();
    _loadTables();
    _updateCapacity(); // 初始化人數
  }

  @override
  void dispose() {
    _capacityController.dispose();
    // _locationController.dispose();
    super.dispose();
  }

  Future<void> _fetchCoaches() async {
    try {
      final coaches = await coachRepository.getCoaches();
      if (mounted) {
        setState(() => _allCoaches = coaches);
      }
    } catch (e) {
      if (mounted) {
        showErrorDialog(context, e, title: '載入教練失敗');
      }
    }
  }

  Future<void> _loadTables() async {
    try {
      final tables = await tableRepository.getTables();
      // 只顯示啟用中的桌子
      final activeTables = tables.where((t) => t.isActive).toList();

      if (mounted) {
        setState(() {
          _tables = activeTables;
          _isLoadingTables = false;
          // 預設選第一張桌子
          // if (_tables.isNotEmpty) {
          //   _selectedTableId = _tables.first.id;
          // }
        });
      }
    } catch (e) {
      if (mounted) {
        showErrorDialog(context, e, title: '載入桌次失敗');
        setState(() => _isLoadingTables = false);
      }
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

  void _manualAdjustCapacity(int change) {
    // 1. 取得當前輸入框的數字，如果是空的就當作 0
    int currentValue = int.tryParse(_capacityController.text) ?? 0;

    // 2. 計算新數值
    int newValue = currentValue + change;

    // 3. 防止變成負數
    if (newValue < 0) newValue = 0;

    // 4. 更新畫面
    setState(() {
      _capacityController.text = newValue.toString();
    });
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

    // if (_selectedTableIds == null) {
    //   ScaffoldMessenger.of(
    //     context,
    //   ).showSnackBar(const SnackBar(content: Text('請選擇桌次')));
    //   return;
    // }

    setState(() => _isLoading = true);

    try {
      List<Map<String, dynamic>> sessionsPayload = [];
      bool conflictFound = false;
      String conflictDateStr = '';

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

          final conflict = await sessionRepository.checkDetailConflict(
            startTime: start,
            endTime: end,
            tableIds: _selectedTableIds,
            coachIds: _selectedCoachIds, // 傳入選到的教練列表
            courseId: widget.courseId,
          );

          if (conflict.hasConflict) {
            // 根據衝突類型，你可以決定要 break 還是 continue
            // 這裡示範：記錄錯誤並中斷
            conflictFound = true;
            // 組合詳細錯誤訊息
            conflictDateStr =
                '${DateFormat('MM/dd HH:mm').format(start)}\n原因：${conflict.message}';
            break;
          }

          // 處理跨日問題 (如果結束時間比開始時間早，代表跨日)
          final finalEnd = end.isBefore(start)
              ? end.add(const Duration(days: 1))
              : end;

          sessionsPayload.add({
            'start_time': start.toUtc().toIso8601String(),
            'end_time': finalEnd.toUtc().toIso8601String(),
            'coach_ids': _selectedCoachIds, // Supabase 支援直接傳 List
            // 選擇性：也可以把桌名寫入 location 欄位當作備份
            // 'location': _tables.firstWhere((t) => t.id == _selectedTableId).name,
            'table_ids': _selectedTableIds,
            'max_capacity': int.tryParse(_capacityController.text) ?? 4,
            'price': widget.defaultPrice,
          });
        }
        currentDay = currentDay.add(const Duration(days: 1));
      }
      if (conflictFound) {
        // 使用 Dialog 顯示詳細錯誤，比 SnackBar 更清楚
        await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('排程衝突'),
            content: Text(
              conflictDateStr,
              style: const TextStyle(fontSize: 16),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('確定'),
              ),
            ],
          ),
        );
        return; // 中斷
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
        showErrorDialog(context, e, title: '排課失敗');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showAddCoachDialog(BuildContext context) {
    // 1. 過濾出「尚未選擇」的教練
    final availableCoaches = _allCoaches.where((coach) {
      final coachId = coach['id'] as String;
      return !_selectedCoachIds.contains(coachId);
    }).toList();

    if (availableCoaches.isEmpty) return;

    // 2. 顯示清單對話框
    showDialog(
      context: context,
      builder: (ctx) {
        return SimpleDialog(
          title: const Text('選擇要加入的教練'),
          children: availableCoaches.map((coach) {
            return SimpleDialogOption(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
              child: Text(
                coach['full_name'] ?? '未命名',
                style: const TextStyle(fontSize: 16),
              ),
              onPressed: () {
                // 3. 點選後加入清單並更新 UI
                setState(() {
                  _selectedCoachIds.add(coach['id']);
                  _updateCapacity(); // 連動人數
                });
                Navigator.pop(ctx); // 關閉對話框
              },
            );
          }).toList(),
        );
      },
    );
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

              const SizedBox(height: 16),
              const Text(
                '選擇桌次 (可多選)',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),

              _isLoadingTables
                  ? const LinearProgressIndicator()
                  : Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Wrap(
                        spacing: 8.0,
                        children: _tables.map((table) {
                          final isSelected = _selectedTableIds.contains(
                            table.id,
                          );
                          return FilterChip(
                            label: Text(table.name),
                            selected: isSelected,
                            onSelected: (bool selected) {
                              setState(() {
                                if (selected) {
                                  _selectedTableIds.add(table.id);
                                } else {
                                  _selectedTableIds.remove(table.id);
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),
                    ),

              const SizedBox(height: 16),

              // ─── 教練選擇區塊 ───
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '指定教練：',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),

                  // 如果還在載入或完全沒資料
                  if (_allCoaches.isEmpty)
                    const Text(
                      '載入教練中或無教練資料',
                      style: TextStyle(color: Colors.grey),
                    )
                  else
                    Wrap(
                      spacing: 8.0,
                      runSpacing: 4.0, // 換行後的間距
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        // 1. 顯示「已選擇」的教練 (InputChip)
                        ..._selectedCoachIds.map((id) {
                          // 找到對應的教練資料
                          final coach = _allCoaches.firstWhere(
                            (c) => c['id'] == id,
                            orElse: () => {'full_name': '未知教練'},
                          );

                          return InputChip(
                            avatar: CircleAvatar(
                              backgroundColor: Colors.blue.shade100,
                              child: Text(
                                coach['full_name'].substring(0, 1), // 取首字當頭像
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.blue.shade800,
                                ),
                              ),
                            ),
                            label: Text(coach['full_name']),
                            onDeleted: () {
                              // 點擊 X 移除
                              setState(() {
                                _selectedCoachIds.remove(id);
                                _updateCapacity(); // 連動人數
                              });
                            },
                            backgroundColor: Colors.blue.shade50,
                            deleteIconColor: Colors.blue.shade300,
                          );
                        }),

                        // 2. 顯示「+ 新增教練」按鈕 (只有當還有未選教練時才顯示)
                        if (_selectedCoachIds.length < _allCoaches.length)
                          if (widget.category == 'personal' &&
                              _selectedCoachIds.isNotEmpty)
                            const SizedBox.shrink()
                          else
                            ActionChip(
                              avatar: const Icon(
                                Icons.add,
                                size: 18,
                                color: Colors.grey,
                              ),
                              label: const Text('新增教練'),
                              backgroundColor: Colors.white,
                              side: BorderSide(
                                color: Colors.grey.shade300,
                              ), // 邊框樣式
                              onPressed: () => _showAddCoachDialog(context),
                            ),
                      ],
                    ),
                ],
              ),

              const SizedBox(height: 24),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 地點輸入框
                  // TextField(
                  //   controller: _locationController,
                  //   decoration: const InputDecoration(
                  //     labelText: '桌次 / 地點',
                  //     border: OutlineInputBorder(),
                  //     prefixIcon: Icon(
                  //       Icons.place_outlined,
                  //     ), // 加個 icon 增加識別度(可選)
                  //   ),
                  // ),
                  // const SizedBox(height: 16), // 上下間距

                  // 人數上限輸入框 (按鈕整合在右側)
                  TextField(
                    controller: _capacityController,
                    // 允許使用者直接點擊輸入數字
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      labelText: '人數上限',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.group_outlined),

                      suffixIcon: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // 減號按鈕
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline),
                            color: Colors.grey,
                            // 記得改回我們剛才定義的 _manualAdjustCapacity
                            onPressed: () => _manualAdjustCapacity(-1),
                          ),

                          // 加號按鈕
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline),
                            color: Colors.blue,
                            onPressed: () => _manualAdjustCapacity(1),
                          ),
                        ],
                      ),
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
