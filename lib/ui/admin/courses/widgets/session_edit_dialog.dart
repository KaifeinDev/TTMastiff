import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// 🔥 引入 main.dart 裡的全域變數
import 'package:ttmastiff/main.dart';

// Models
import '../../../../data/models/session_model.dart';
import '../../../../data/models/booking_model.dart';
import '../../../../data/models/student_model.dart';

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
  final _locationController = TextEditingController();
  final _capacityController = TextEditingController();
  List<Map<String, dynamic>> _allCoaches = [];
  List<String> _selectedCoachIds = [];
  late DateTime _startDateTime;
  late DateTime _endDateTime;
  bool _isSavingSettings = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    // 初始化 Tab 2 資料
    final s = widget.session;
    _locationController.text = s.location ?? '';
    _capacityController.text = s.maxCapacity.toString();
    _selectedCoachIds = List<String>.from(s.coachIds);
    _startDateTime = s.startTime;
    _endDateTime = s.endTime;

    // 載入資料 (使用全域變數)
    _fetchCoaches();
    _fetchRoster();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _locationController.dispose();
    _capacityController.dispose();
    super.dispose();
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

  void _showAddStudentDialog() {
    showDialog(
      context: context,
      builder: (context) => _StudentSearchDialog(
        onStudentSelected: (student) async {
          final messenger = ScaffoldMessenger.of(context);
          try {
            // 🔥 使用全域 bookingRepository 幫學生報名
            await bookingRepository.createBooking(
              sessionId: widget.session.id,
              studentId: student.id,
              userId: student.parentId,
              priceSnapshot: widget.session.displayPrice,
            );

            messenger.showSnackBar(
              SnackBar(content: Text('已加入學員: ${student.name}')),
            );

            if (mounted) {
              _fetchRoster(); // 刷新名單
            }
          } catch (e) {
            messenger.showSnackBar(
              SnackBar(content: Text('加入失敗: $e'), backgroundColor: Colors.red),
            );
          }
        },
      ),
    );
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
    setState(() => _isSavingSettings = true);
    try {
      // 🔥 使用全域 sessionRepository
      await sessionRepository.updateSession(
        sessionId: widget.session.id,
        coachIds: _selectedCoachIds,
        location: _locationController.text,
        maxCapacity: int.tryParse(_capacityController.text),
        startTime: _startDateTime.toUtc(),
        endTime: _endDateTime.toUtc(),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('錯誤: $e')));
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

    // 這裡放入原本的 Settings UI，並在 submit 時呼叫 sessionRepository.updateSession
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // 時間設定
          _buildTimeRow('開始時間', _startDateTime, () => _pickDateTime(true)),
          const SizedBox(height: 16),
          _buildTimeRow('結束時間', _endDateTime, () => _pickDateTime(false)),
          const SizedBox(height: 24),
          // 地點與人數
          TextField(
            controller: _locationController,
            decoration: const InputDecoration(
              labelText: '地點',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _capacityController,
            decoration: InputDecoration(
              labelText: '人數上限',
              border: OutlineInputBorder(),
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min, // 這一行非常重要！讓 Row 只佔據最小寬度
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
          // 教練
          const Align(alignment: Alignment.centerLeft, child: Text('教練分配')),
          Wrap(
            spacing: 8,
            children: _allCoaches.map((c) {
              final id = c['id'] as String;
              final selected = _selectedCoachIds.contains(id);
              return FilterChip(
                label: Text(c['full_name'] ?? '未命名'),
                selected: selected,
                onSelected: (val) => setState(() {
                  val
                      ? _selectedCoachIds.add(id)
                      : _selectedCoachIds.remove(id);
                  _recalcCapacity();
                }),
              );
            }).toList(),
          ),
          const SizedBox(height: 32),
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

// 簡單的學生搜尋 Dialog
class _StudentSearchDialog extends StatefulWidget {
  final Function(StudentModel) onStudentSelected;
  const _StudentSearchDialog({required this.onStudentSelected});

  @override
  State<_StudentSearchDialog> createState() => _StudentSearchDialogState();
}

class _StudentSearchDialogState extends State<_StudentSearchDialog> {
  final _searchController = TextEditingController();
  List<StudentModel> _results = [];
  bool _searching = false;

  Future<void> _search() async {
    setState(() => _searching = true);
    try {
      // 這裡直接用 Supabase Client 搜尋，或者你在 StudentRepository 補上 searchStudent 方法
      // 假設簡單搜尋名字
      final res = await Supabase.instance.client
          .from('students')
          .select()
          .ilike('name', '%${_searchController.text}%')
          .limit(5);
      setState(() {
        _results = (res as List).map((e) => StudentModel.fromJson(e)).toList();
      });
    } finally {
      setState(() => _searching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('搜尋學生'),
      content: SizedBox(
        width: 300,
        height: 300,
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: '輸入姓名...',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: _search,
                ),
              ),
              onSubmitted: (_) => _search(),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: _searching
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.builder(
                      itemCount: _results.length,
                      itemBuilder: (context, index) {
                        final s = _results[index];
                        return ListTile(
                          title: Text(s.name),
                          onTap: () {
                            Navigator.pop(context);
                            widget.onStudentSelected(s);
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
