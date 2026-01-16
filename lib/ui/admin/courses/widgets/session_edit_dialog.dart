import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

// 🔥 引入 main.dart 裡的全域變數
import 'package:ttmastiff/main.dart';

// Models
import '../../../../data/models/session_model.dart';
import '../../../../data/models/booking_model.dart';
import '../../../../data/models/student_model.dart';
import '../../../../data/models/table_model.dart';
import 'student_search_dialog.dart';

class SessionEditDialog extends StatefulWidget {
  final SessionModel session;
  final String category;

  const SessionEditDialog({
    super.key,
    required this.session,
    required this.category,
  });

  @override
  State<SessionEditDialog> createState() => _SessionEditDialogState();
}

class _SessionEditDialogState extends State<SessionEditDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Tab 1: 學員名單變數
  List<BookingModel> _roster = [];
  bool _isLoadingRoster = false;

  // Tab 2: 場次設定變數
  // final _locationController = TextEditingController();
  final _capacityController = TextEditingController();
  List<Map<String, dynamic>> _allCoaches = [];
  List<String> _selectedCoachIds = [];
  late DateTime _startDateTime;
  late DateTime _endDateTime;
  bool _isSavingSettings = false;

  List<TableModel> _tables = [];
  List<String> _selectedTableIds = [];
  bool _isLoadingTables = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    // 初始化 Tab 2 資料
    final s = widget.session;
    // _locationController.text = s.location ?? '';
    _capacityController.text = s.maxCapacity.toString();
    _selectedCoachIds = List<String>.from(s.coachIds);
    _startDateTime = s.startTime;
    _endDateTime = s.endTime;
    _selectedTableIds = List.from(widget.session.tableIds);

    // 載入資料 (使用全域變數)
    _fetchCoaches();
    _fetchRoster();
    _loadTables();
  }

  @override
  void dispose() {
    _tabController.dispose();
    // _locationController.dispose();
    _capacityController.dispose();
    super.dispose();
  }

  Future<void> _loadTables() async {
    try {
      // 1. 取得所有桌子 (包含停用的)
      final allTables = await tableRepository.getTables();

      // 2. 取得這堂課目前紀錄的 tableId
      final currentTableId = widget.session.tableIds;

      // 3. 過濾邏輯：
      // 保留「啟用中」的桌子 OR 「這堂課原本選中的」桌子
      // 這樣可以確保即使桌子被停用，編輯這堂課時依然能看到它顯示在選單上，而不是空白或報錯
      final displayTables = allTables.where((t) {
        return t.isActive || (currentTableId != null && t.id == currentTableId);
      }).toList();

      if (mounted) {
        setState(() {
          _tables = displayTables;
          _isLoadingTables = false;
          // 注意：不需要在這裡設定 _selectedTableId
          // 因為 initState 已經用 widget.session.tableId 設定好了
        });
      }
    } catch (e) {
      debugPrint('載入桌次失敗: $e');
      if (mounted) setState(() => _isLoadingTables = false);
    }
  }

  // --------------------------------------------------------------------------
  // Tab 1 邏輯: 名單管理
  // --------------------------------------------------------------------------
  Future<void> _fetchRoster() async {
    setState(() => _isLoadingRoster = true);
    try {
      // 🔥 使用全域 bookingRepository
      final bookings = await bookingRepository.fetchBookingsBySessionId(
        widget.session.id,
      );
      if (mounted) setState(() => _roster = bookings);
    } catch (e) {
      debugPrint('Fetch roster error: $e');
    } finally {
      if (mounted) setState(() => _isLoadingRoster = false);
    }
  }

  Future<void> _updateStudentStatus(
    String bookingId,
    String status,
    String attendance,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      // 🔥 使用全域 bookingRepository
      await bookingRepository.updateBookingStatus(
        bookingId: bookingId,
        status: status,
        attendanceStatus: attendance,
      );

      messenger.showSnackBar(const SnackBar(content: Text('更新成功')));

      if (mounted) {
        _fetchRoster();
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('更新失敗: $e')));
    }
  }

  Future<void> _cancelStudentBooking(String bookingId) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      // 🔥 使用全域 bookingRepository
      await bookingRepository.cancelBooking(bookingId);

      messenger.showSnackBar(const SnackBar(content: Text('取消成功，已成功退費')));

      if (mounted) {
        _fetchRoster();
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('取消失敗: $e')));
    }
  }

  Future<void> _showAddStudentDialog() async {
    final existingIds = _roster.map((booking) => booking.studentId).toSet();
    final StudentModel? selectedStudent = await showDialog<StudentModel>(
      context: context,
      builder: (context) =>
          StudentSearchDialog(existingStudentIds: existingIds),
    );
    if (selectedStudent != null) {
      // 呼叫下面定義的函式
      await _executeEnrollment(selectedStudent);
    }
  }

  Future<void> _executeEnrollment(StudentModel student) async {
    setState(() => _isLoadingRoster = true);

    try {
      // 🔥 重點：直接呼叫 repository 的批次報名，但只傳入一筆資料
      // 這樣我們就不用重寫「檢查名額、扣點數、寫入DB」的複雜邏輯
      final result = await bookingRepository.createBatchBooking(
        sessionIds: [widget.session.id], // 當前場次 ID
        studentIds: [student.id], // 選到的學生 ID
        priceSnapshot: widget.session.displayPrice, // 當前價格
      );

      final successCount = result['success'] as int;

      if (mounted) {
        if (successCount > 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('已成功幫 ${student.name} 完成報名與扣款'),
              backgroundColor: Colors.green,
            ),
          );
          // 報名成功後，刷新名單
          _fetchRoster();
        } else {
          // 可能是重複報名或被略過
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('加入失敗：該學員可能已報名或餘額不足')));
        }
      }
    } catch (e) {
      if (mounted) {
        // 顯示錯誤 (例如：額滿、餘額不足)
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('無法加入'),
            content: Text(e.toString().replaceAll('Exception: ', '')),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('確定'),
              ),
            ],
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingRoster = false);
      }
    }
  }

  // --------------------------------------------------------------------------
  // Tab 2 邏輯: 場次設定
  // --------------------------------------------------------------------------
  Future<void> _fetchCoaches() async {
    try {
      // 🔥 使用全域 coachRepository
      final coaches = await coachRepository.getCoaches();
      if (mounted) setState(() => _allCoaches = coaches);
    } catch (e) {
      debugPrint('Fetch coaches error: $e');
    }
  }

  void _recalcCapacity() {
    if (widget.category == 'personal') return;
    int count = _selectedCoachIds.isEmpty ? 1 : _selectedCoachIds.length;
    _capacityController.text = (count * 4).toString();
  }

  Future<void> _pickDateTime(bool isStart) async {
    // ... (維持原本時間選擇邏輯)
    final initialDate = isStart ? _startDateTime : _endDateTime;
    final date = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2024),
      lastDate: DateTime(2030),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initialDate),
    );
    if (time == null) return;
    final newDateTime = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    setState(() {
      if (isStart) {
        _startDateTime = newDateTime;
        if (_startDateTime.isAfter(_endDateTime))
          _endDateTime = _startDateTime.add(const Duration(hours: 1));
      } else {
        if (newDateTime.isBefore(_startDateTime)) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('結束時間不能早於開始時間')));
          return;
        }
        _endDateTime = newDateTime;
      }
    });
  }

  Future<void> _submitSettings() async {
    // if (_selectedTableId == null) {
    //   ScaffoldMessenger.of(
    //     context,
    //   ).showSnackBar(const SnackBar(content: Text('請選擇桌次')));
    //   return;
    // }
    setState(() => _isSavingSettings = true);
    try {
      // 撞期檢查
      final conflict = await sessionRepository.checkDetailConflict(
        startTime: _startDateTime,
        endTime: _endDateTime,
        tableIds: _selectedTableIds,
        coachIds: _selectedCoachIds,
        courseId: widget.session.courseId,
        excludeSessionId: widget.session.id, // 排除自己
      );

      if (conflict.hasConflict) {
        if (mounted) {
          // 顯示具體錯誤原因
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('無法儲存：${conflict.message}'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 4),
              behavior: SnackBarBehavior.floating, // 浮動樣式比較好看
            ),
          );
        }
        return; // 中斷
      }

      // 🔥 使用全域 sessionRepository
      await sessionRepository.updateSession(
        sessionId: widget.session.id,
        coachIds: _selectedCoachIds,
        // location: _locationController.text,
        tableIds: _selectedTableIds,
        maxCapacity: int.tryParse(_capacityController.text),
        startTime: _startDateTime.toUtc(),
        endTime: _endDateTime.toUtc(),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('錯誤: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSavingSettings = false);
    }
  }

  // --------------------------------------------------------------------------
  // UI 渲染 (與之前相同，僅微調細節)
  // --------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 500,
        height: 700,
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              decoration: BoxDecoration(
                color: Colors.blue.shade50.withOpacity(0.5),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.session.courseTitle,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              DateFormat(
                                'MM/dd HH:mm',
                              ).format(widget.session.startTime),
                              style: TextStyle(color: Colors.grey[700]),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TabBar(
                    controller: _tabController,
                    labelColor: Colors.blue.shade800,
                    unselectedLabelColor: Colors.grey,
                    indicatorColor: Colors.blue,
                    tabs: const [
                      Tab(text: '學員名單'),
                      Tab(text: '場次設定'),
                    ],
                  ),
                ],
              ),
            ),
            // Body
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [_buildRosterView(), _buildSettingsView()],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRosterView() {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddStudentDialog,
        icon: const Icon(Icons.person_add),
        label: const Text('加入學生'),
      ),
      body: _isLoadingRoster
          ? const Center(child: CircularProgressIndicator())
          : _roster.isEmpty
          ? const Center(
              child: Text('目前無人報名', style: TextStyle(color: Colors.grey)),
            )
          : ListView.separated(
              // padding: const EdgeInsets.all(16),
              padding: const EdgeInsets.only(bottom: 80),
              itemCount: _roster.length,
              separatorBuilder: (_, __) => const Divider(),
              itemBuilder: (context, index) {
                final booking = _roster[index];
                return ListTile(
                  leading: CircleAvatar(
                    child: Text(booking.student?.name[0] ?? '?'),
                  ),
                  title: Text(booking.student?.name ?? '未知'),
                  subtitle: _buildStatusBadge(
                    booking.attendanceStatus,
                    booking.status,
                  ),
                  trailing: booking.status == 'cancelled'
                      ? null
                      : PopupMenuButton<String>(
                          onSelected: (val) {
                            if (val == 'cancel')
                              _cancelStudentBooking(booking.id);
                            else
                              _updateStudentStatus(
                                booking.id,
                                'confirmed',
                                val,
                              );
                          },
                          itemBuilder: (context) => const [
                            PopupMenuItem(
                              value: 'attended',
                              child: Text('✅ 出席'),
                            ),
                            PopupMenuItem(value: 'leave', child: Text('🤧 請假')),
                            PopupMenuItem(value: 'absent', child: Text('❌ 曠課')),
                            PopupMenuDivider(),
                            PopupMenuItem(
                              value: 'cancel',
                              child: Text('🔙 取消'),
                            ),
                          ],
                        ),
                );
              },
            ),
    );
  }

  Widget _buildStatusBadge(String attendance, String status) {
    if (status == 'cancelled')
      return const Text('已取消', style: TextStyle(color: Colors.grey));
    String text = '待上課';
    Color color = Colors.blue;
    switch (attendance) {
      case 'attended':
        {
          text = '已出席';
          color = Colors.green;
        }
        break;
      case 'leave':
        {
          text = '已請假';
          color = Colors.orange;
        }
        break;
      case 'absent':
        {
          text = '曠課';
          color = Colors.red;
        }
        break;
    }
    return Text(
      text,
      style: TextStyle(color: color, fontWeight: FontWeight.bold),
    );
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
                  _recalcCapacity(); // 連動人數
                });
                Navigator.pop(ctx); // 關閉對話框
              },
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildSettingsView() {
    void _adjustCapacity(int amount) {
      // 1. 嘗試將目前文字轉為整數，若為空或格式錯誤則預設為 0
      int currentValue = int.tryParse(_capacityController.text) ?? 0;

      // 2. 計算新數值
      int newValue = currentValue + amount;

      // 3. 避免變成負數
      if (newValue < 0) newValue = 0;

      // 4. 更新 Controller 顯示
      _capacityController.text = newValue.toString();
    }

    final selectedTableNames = _tables
        .where((t) => _selectedTableIds.contains(t.id))
        .map((t) => t.name)
        .join('、');

    // 這裡放入原本的 Settings UI，並在 submit 時呼叫 sessionRepository.updateSession
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 時間設定
          _buildTimeRow('開始時間', _startDateTime, () => _pickDateTime(true)),
          const SizedBox(height: 16),
          _buildTimeRow('結束時間', _endDateTime, () => _pickDateTime(false)),
          const SizedBox(height: 16),

          Row(
            children: [
              const Icon(Icons.table_restaurant, size: 20, color: Colors.grey),
              const SizedBox(width: 8),
              const Text('桌次安排', style: TextStyle(fontWeight: FontWeight.bold)),
              const Spacer(),
              Text(
                selectedTableNames.isEmpty ? '未指定' : selectedTableNames,
                style: TextStyle(
                  color: Colors.blue.shade700,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          // 地點與人數
          // TextField(
          //   controller: _locationController,
          //   decoration: const InputDecoration(
          //     labelText: '地點',
          //     border: OutlineInputBorder(),
          //     prefixIcon: Icon(Icons.place_outlined),
          //   ),
          // ),
          _isLoadingTables
              ? const Center(child: CircularProgressIndicator())
              : Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    border: Border.all(color: Colors.grey.shade200),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: _tables.isEmpty
                      ? const Text('無可用桌次資料')
                      : Wrap(
                          spacing: 8.0,
                          runSpacing: 4.0,
                          children: _tables.map((table) {
                            final isSelected = _selectedTableIds.contains(
                              table.id,
                            );
                            return FilterChip(
                              label: Text(table.name),
                              selected: isSelected,
                              selectedColor: Colors.blue.shade100,
                              checkmarkColor: Colors.blue.shade700,
                              labelStyle: TextStyle(
                                color: isSelected
                                    ? Colors.blue.shade900
                                    : Colors.black87,
                                fontWeight: isSelected
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                              ),
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
                const Text('載入教練中或無教練資料', style: TextStyle(color: Colors.grey))
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
                            _recalcCapacity(); // 連動人數
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
                          side: BorderSide(color: Colors.grey.shade300), // 邊框樣式
                          onPressed: () => _showAddCoachDialog(context),
                        ),
                  ],
                ),
            ],
          ),

          const SizedBox(height: 24),
          TextField(
            controller: _capacityController,
            decoration: InputDecoration(
              labelText: '人數上限',
              border: OutlineInputBorder(),
              prefixIcon: const Icon(Icons.group_outlined),
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 減號按鈕
                  IconButton(
                    icon: const Icon(
                      Icons.remove_circle_outline,
                      color: Colors.grey,
                    ),
                    onPressed: () => _adjustCapacity(-1),
                  ),
                  // 加號按鈕
                  IconButton(
                    icon: const Icon(
                      Icons.add_circle_outline,
                      color: Colors.blue,
                    ),
                    onPressed: () => _adjustCapacity(1),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _isSavingSettings ? null : _submitSettings,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
              child: _isSavingSettings
                  ? const CircularProgressIndicator()
                  : const Text('儲存變更', style: TextStyle(color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeRow(String label, DateTime time, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            DateFormat('yyyy/MM/dd HH:mm').format(time),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
