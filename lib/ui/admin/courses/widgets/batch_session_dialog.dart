import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:ttmastiff/main.dart';
import 'package:ttmastiff/data/models/table_model.dart';
import 'package:flutter/services.dart';
import '../../../../core/utils/util.dart';
import '../../../../data/models/student_model.dart';
import 'student_search_dialog.dart';

class BatchSessionDialog extends StatefulWidget {
  final String courseId;
  final TimeOfDay defaultStartTime;
  final TimeOfDay defaultEndTime;
  final String category; // 'group', 'personal', 'rental'
  final int defaultPrice; // 如果是 rental，這裡代表「時薪」

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
  final Set<int> _selectedWeekdays = {};

  // 本地維護的起訖時間
  late TimeOfDay _startTime;
  late TimeOfDay _endTime;

  // 教練相關
  List<Map<String, dynamic>> _allCoaches = [];
  final List<String> _selectedCoachIds = [];

  // 租桌相關
  Map<String, dynamic>? _selectedRenter;
  final TextEditingController _guestNameController = TextEditingController();
  final TextEditingController _guestPhoneController = TextEditingController();
  String _paymentMethod = 'credit'; // 'credit' or 'cash'

  // 桌次與容量
  List<TableModel> _tables = [];
  final List<String> _selectedTableIds = [];
  bool _isLoadingTables = true;
  final TextEditingController _capacityController = TextEditingController();

  // 手動調整最終價格
  final TextEditingController _finalPriceController = TextEditingController();

  bool _isLoading = false;

  // Helper
  bool get _isRental => widget.category == 'rental';

  // 我們改為判斷選中的人，其姓名是否包含 "散客" (或者您可以用 role 欄位判斷)
  bool get _isGuestSelected {
    if (_selectedRenter == null) return false;
    final name = _selectedRenter!['full_name'].toString();
    // 簡單判斷：名字有 "散客" 或是 "Guest" 就當作是散客帳號
    return name.contains('散客') || name.contains('Guest');
  }

  @override
  void initState() {
    super.initState();
    // 1. 初始化時間
    _startTime = widget.defaultStartTime;
    _endTime = widget.defaultEndTime;

    // 2. 初始化價格 (計算一次)
    _calculateAndSetPrice();

    // 3. 載入資料
    if (!_isRental) {
      _fetchCoaches();
    }
    _loadTables();
    _updateCapacity();
  }

  @override
  void dispose() {
    _capacityController.dispose();
    _guestNameController.dispose();
    _guestPhoneController.dispose();
    _finalPriceController.dispose();
    super.dispose();
  }

  // --- 核心邏輯區 ---

  // 計算價格邏輯
  void _calculateAndSetPrice() {
    if (!_isRental) {
      _finalPriceController.text = widget.defaultPrice.toString();
      return;
    }

    final startMinutes = _startTime.hour * 60 + _startTime.minute;
    final endMinutes = _endTime.hour * 60 + _endTime.minute;

    int durationMinutes = endMinutes - startMinutes;
    if (durationMinutes < 0) durationMinutes += 24 * 60;

    double hours = durationMinutes / 60.0;
    if (hours <= 0) hours = 1.0;

    int totalPrice = (hours * widget.defaultPrice).round();

    setState(() {
      _finalPriceController.text = totalPrice.toString();
    });
  }

  Future<void> _pickTime(bool isStart) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _startTime : _endTime,
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startTime = picked;
        } else {
          _endTime = picked;
        }
        _calculateAndSetPrice();
      });
    }
  }

  Future<void> _fetchCoaches() async {
    try {
      final coaches = await coachRepository.getCoaches();
      if (mounted) setState(() => _allCoaches = coaches);
    } catch (e) {
      if (mounted) showErrorDialog(context, e, title: '載入教練失敗');
    }
  }

  Future<void> _loadTables() async {
    try {
      final tables = await tableRepository.getTables();
      final activeTables = tables.where((t) => t.isActive).toList();
      if (mounted) {
        setState(() {
          _tables = activeTables;
          _isLoadingTables = false;
        });
      }
    } catch (e) {
      if (mounted) {
        showErrorDialog(context, e, title: '載入桌次失敗');
        setState(() => _isLoadingTables = false);
      }
    }
  }

  Future<void> _showRenterSearchDialog() async {
    final StudentModel? selectedStudent = await showDialog<StudentModel>(
      context: context,
      builder: (context) => const StudentSearchDialog(
        existingStudentIds: {},
        // 移除 allowGuest: true
      ),
    );

    if (selectedStudent != null) {
      setState(() {
        // 使用真實選到的資料
        _selectedRenter = {
          'id': selectedStudent.id, // 這是資料庫真實 ID，不會報錯了
          'full_name': selectedStudent.name,
          'parent_id': selectedStudent.parentId,
        };

        // 自動判斷支付方式
        // 這裡直接呼叫 getter 判斷
        if (_selectedRenter!['full_name'].toString().contains('散客')) {
          _paymentMethod = 'cash';
        } else {
          _paymentMethod = 'credit';
        }
      });
    }
  }

  void _updateCapacity() {
    if (_isRental) {
      _capacityController.text = '1';
    } else if (widget.category == 'personal') {
      _capacityController.text = '1';
    } else {
      int count = _selectedCoachIds.isEmpty ? 1 : _selectedCoachIds.length;
      _capacityController.text = (count * 4).toString();
    }
  }

  void _manualAdjustCapacity(int change) {
    int currentValue = int.tryParse(_capacityController.text) ?? 0;
    int newValue = currentValue + change;
    if (newValue < 0) newValue = 0;
    setState(() => _capacityController.text = newValue.toString());
  }

  int _calculateSessionCount() {
    if (_dateRange == null || _selectedWeekdays.isEmpty) return 0;
    int count = 0;
    DateTime day = _dateRange!.start;
    final endDay = _dateRange!.end;
    while (!day.isAfter(endDay)) {
      if (_selectedWeekdays.contains(day.weekday)) count++;
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
    if (_selectedTableIds.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('請至少選擇一張桌子')));
      return;
    }
    if (_isRental) {
      if (_selectedRenter == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('租桌模式必須選擇一位租借人')));
        return;
      }
      if (_isGuestSelected && _guestNameController.text.isEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('現場散客請輸入姓名')));
        return;
      }
    }

    setState(() => _isLoading = true);

    try {
      List<Map<String, dynamic>> sessionsPayload = [];
      bool conflictFound = false;
      String conflictDetails = '';

      DateTime currentDay = _dateRange!.start;
      final endDay = _dateRange!.end;
      final int finalPrice =
          int.tryParse(_finalPriceController.text) ?? widget.defaultPrice;

      while (!currentDay.isAfter(endDay)) {
        if (_selectedWeekdays.contains(currentDay.weekday)) {
          final start = DateTime(
            currentDay.year,
            currentDay.month,
            currentDay.day,
            _startTime.hour,
            _startTime.minute,
          );
          final end = DateTime(
            currentDay.year,
            currentDay.month,
            currentDay.day,
            _endTime.hour,
            _endTime.minute,
          );
          final finalEnd = end.isBefore(start)
              ? end.add(const Duration(days: 1))
              : end;

          final conflict = await sessionRepository.checkDetailConflict(
            startTime: start,
            endTime: finalEnd,
            tableIds: _selectedTableIds,
            coachIds: _selectedCoachIds,
            courseId: widget.courseId,
          );

          if (conflict.hasConflict) {
            conflictFound = true;
            conflictDetails =
                '${DateFormat('MM/dd HH:mm').format(start)}\n${conflict.message}';
            break;
          }

          Map<String, dynamic> sessionData = {
            'start_time': start.toUtc().toIso8601String(),
            'end_time': finalEnd.toUtc().toIso8601String(),
            'table_ids': _selectedTableIds,
            'max_capacity': int.tryParse(_capacityController.text) ?? 1,
            'price': finalPrice,
            'coach_ids': _selectedCoachIds,
          };

          if (_isRental) {
            sessionData['is_rental'] = true;
            sessionData['renter_id'] = _selectedRenter!['id'];
            sessionData['target_user_id'] = _selectedRenter!['parent_id'];
            sessionData['payment_method'] = _paymentMethod;
            if (_isGuestSelected) {
              sessionData['guest_info'] = {
                'name': _guestNameController.text,
                'phone': _guestPhoneController.text,
              };
            }
          }

          sessionsPayload.add(sessionData);
        }
        currentDay = currentDay.add(const Duration(days: 1));
      }

      if (conflictFound) {
        if (mounted) {
          await showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('排程衝突'),
              content: Text(conflictDetails),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('確定'),
                ),
              ],
            ),
          );
        }
        return;
      }

      await sessionRepository.batchCreateSessions(
        courseId: widget.courseId,
        sessionsData: sessionsPayload,
      );

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) showErrorDialog(context, e, title: '排程失敗');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- UI Components ---

  Widget _buildTimeAndPriceConfig() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => _pickTime(true),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: '開始時間',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                    ),
                    child: Text(
                      _startTime.format(context),
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              const Icon(Icons.arrow_forward, color: Colors.grey),
              const SizedBox(width: 12),
              Expanded(
                child: InkWell(
                  onTap: () => _pickTime(false),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: '結束時間',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                    ),
                    child: Text(
                      _endTime.format(context),
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _finalPriceController,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              labelText: _isRental ? '本次總費用 (可手動修改)' : '單堂費用',
              prefixText: '\$ ',
              suffixText: _isRental
                  ? '(時薪: \$${widget.defaultPrice}/hr)'
                  : null,
              border: const OutlineInputBorder(),
              filled: true,
              fillColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  //  選擇租借人
  Widget _buildRenterSelection() {
    final isGuest = _isGuestSelected;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('租借人 (User)', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),

        // 1. 選擇租借人的輸入框 (唯讀，點擊觸發 Dialog)
        InkWell(
          onTap: _showRenterSearchDialog,
          borderRadius: BorderRadius.circular(4),
          child: InputDecorator(
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              filled: true,
              fillColor: Colors.grey.shade50,
              prefixIcon: Icon(
                isGuest ? Icons.storefront : Icons.person,
                color: isGuest ? Colors.green : Colors.blue,
              ),
              suffixIcon: _selectedRenter != null
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        setState(() {
                          _selectedRenter = null;
                          _paymentMethod = 'credit';
                          _guestNameController.clear();
                          _guestPhoneController.clear();
                        });
                      },
                    )
                  : const Icon(Icons.search),
              hintText: '點擊搜尋會員...',
            ),
            child: Text(
              _selectedRenter?['full_name'] ?? '請選擇租借人',
              style: TextStyle(
                color: _selectedRenter == null
                    ? Colors.grey.shade600
                    : Colors.black87,
                fontWeight: isGuest ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ),

        // 2. 如果是散客，顯示額外的資料輸入框
        if (isGuest) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '散客資訊 (必填)',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _guestNameController,
                        decoration: const InputDecoration(
                          labelText: '姓名',
                          isDense: true,
                          border: OutlineInputBorder(),
                          fillColor: Colors.white,
                          filled: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _guestPhoneController,
                        decoration: const InputDecoration(
                          labelText: '電話 (選填)',
                          isDense: true,
                          border: OutlineInputBorder(),
                          fillColor: Colors.white,
                          filled: true,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],

        // 3. 支付方式選擇 (只有在已選擇租借人後顯示)
        if (_selectedRenter != null) ...[
          const SizedBox(height: 16),
          const Text('支付方式', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Row(
            children: [
              ChoiceChip(
                label: const Text('錢包扣款 (Credit)'),
                selected: _paymentMethod == 'credit',
                // 如果是散客，禁用錢包選項
                onSelected: isGuest
                    ? null
                    : (selected) => setState(() => _paymentMethod = 'credit'),
                avatar: const Icon(Icons.account_balance_wallet, size: 18),
              ),
              const SizedBox(width: 12),
              ChoiceChip(
                label: const Text('現場現金 (Cash)'),
                selected: _paymentMethod == 'cash',
                onSelected: (selected) =>
                    setState(() => _paymentMethod = 'cash'),
                avatar: const Icon(Icons.attach_money, size: 18),
                selectedColor: Colors.green.shade100,
                side: _paymentMethod == 'cash'
                    ? const BorderSide(color: Colors.green)
                    : null,
              ),
            ],
          ),
          if (_paymentMethod == 'cash')
            Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Text(
                '註: 現金交易將標記為 "Pending"，需在帳務管理中核銷。',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              ),
            ),
        ],
      ],
    );
  }

  Widget _buildCoachSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('指定教練：', style: TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 8),
        if (_allCoaches.isEmpty)
          const Text('載入教練中或無教練資料', style: TextStyle(color: Colors.grey))
        else
          Wrap(
            spacing: 8.0,
            runSpacing: 4.0,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ..._selectedCoachIds.map((id) {
                final coach = _allCoaches.firstWhere(
                  (c) => c['id'] == id,
                  orElse: () => {'full_name': '未知'},
                );
                return InputChip(
                  avatar: CircleAvatar(
                    backgroundColor: Colors.blue.shade100,
                    child: Text(
                      coach['full_name'].substring(0, 1),
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.blue.shade800,
                      ),
                    ),
                  ),
                  label: Text(coach['full_name']),
                  onDeleted: () {
                    setState(() {
                      _selectedCoachIds.remove(id);
                      _updateCapacity();
                    });
                  },
                  backgroundColor: Colors.blue.shade50,
                  deleteIconColor: Colors.blue.shade300,
                );
              }),
              if (_selectedCoachIds.length < _allCoaches.length)
                ActionChip(
                  avatar: const Icon(Icons.add, size: 18, color: Colors.grey),
                  label: const Text('新增教練'),
                  backgroundColor: Colors.white,
                  side: BorderSide(color: Colors.grey.shade300),
                  onPressed: () => _showAddCoachDialog(context),
                ),
            ],
          ),
      ],
    );
  }

  void _showAddCoachDialog(BuildContext context) {
    final availableCoaches = _allCoaches
        .where((c) => !_selectedCoachIds.contains(c['id']))
        .toList();
    if (availableCoaches.isEmpty) return;

    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('選擇要加入的教練'),
        children: availableCoaches.map((coach) {
          return SimpleDialogOption(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
            child: Text(
              coach['full_name'] ?? '未命名',
              style: const TextStyle(fontSize: 16),
            ),
            onPressed: () {
              setState(() {
                _selectedCoachIds.add(coach['id']);
                _updateCapacity();
              });
              Navigator.pop(ctx);
            },
          );
        }).toList(),
      ),
    );
  }

  String _weekdayName(int day) {
    const names = ['週一', '週二', '週三', '週四', '週五', '週六', '週日'];
    return names[day - 1];
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isRental ? '租桌設定 (建立 Booking)' : '批次排課 (建立課程)'),
      content: SizedBox(
        width: 500,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // 1. 日期選擇
              ListTile(
                title: Text(
                  _dateRange == null
                      ? '點擊選擇日期範圍'
                      : '${DateFormat('yyyy/MM/dd').format(_dateRange!.start)} - ${DateFormat('yyyy/MM/dd').format(_dateRange!.end)}',
                ),
                leading: Icon(
                  Icons.date_range,
                  color: Theme.of(context).colorScheme.primary,
                ),
                tileColor: Theme.of(context).colorScheme.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                onTap: () async {
                  final range = await showDateRangePicker(
                    context: context,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (range != null) setState(() => _dateRange = range);
                },
              ),
              const SizedBox(height: 16),

              // 2. 星期選擇
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
                      selectedColor: Theme.of(
                        context,
                      ).colorScheme.primaryContainer,
                      checkmarkColor: Theme.of(context).colorScheme.primary,
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

              // 3. 時間與價格
              const Text(
                '時間與費用',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              _buildTimeAndPriceConfig(),
              const SizedBox(height: 16),

              // 4. 桌次選擇
              const Text('選擇桌次', style: TextStyle(fontWeight: FontWeight.bold)),
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
                          return FilterChip(
                            label: Text(table.name),
                            selected: _selectedTableIds.contains(table.id),
                            onSelected: (val) => setState(
                              () => val
                                  ? _selectedTableIds.add(table.id)
                                  : _selectedTableIds.remove(table.id),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
              const SizedBox(height: 16),

              // 5. 根據模式選人或選教練
              if (_isRental)
                _buildRenterSelection()
              else
                _buildCoachSelection(),

              const SizedBox(height: 24),

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
                        color: Theme.of(context).colorScheme.primary,
                        onPressed: () => _manualAdjustCapacity(1),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // 7. 預覽資訊
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
                          '預計產生 ${_calculateSessionCount()} 筆預約',
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
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
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
}
