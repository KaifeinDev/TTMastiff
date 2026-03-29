import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ttmastiff/core/utils/util.dart';
import 'package:intl/intl.dart';
import '../../../data/models/staff_detail_model.dart';
import '../../../data/models/work_shift_model.dart';
import '../../../data/services/salary_repository.dart';

class StaffDetailScreen extends StatefulWidget {
  final Map<String, dynamic>
  profile; // 傳入 profile 物件 (包含 id, full_name, avatar_url)

  const StaffDetailScreen({super.key, required this.profile});

  @override
  State<StaffDetailScreen> createState() => _StaffDetailScreenState();
}

class _StaffDetailScreenState extends State<StaffDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late SalaryRepository _repository;

  bool _isLoading = false;
  StaffDetailModel? _detail;
  List<WorkShiftModel> _shifts = [];
  DateTime _selectedMonth = DateTime.now(); // 排班頁面查看的月份

  // Form Controllers
  final _coachRateCtrl = TextEditingController();
  final _deskRateCtrl = TextEditingController();
  final _bankCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _repository = SalaryRepository(Supabase.instance.client);
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      // 1. 載入詳細設定
      final detail = await _repository.getStaffDetail(widget.profile['id']);
      _detail = detail ?? StaffDetailModel(id: widget.profile['id']); // 若無則給預設值

      // 填入表單
      _coachRateCtrl.text = _detail!.coachHourlyRate.toString();
      _deskRateCtrl.text = _detail!.deskHourlyRate.toString();
      _bankCtrl.text = _detail!.bankAccount ?? '';

      // 2. 載入當月排班
      await _loadShifts();
    } catch (e, st) {
      logError(e, st);
      if (mounted) {
        showErrorSnackBar(context, e, prefix: '載入失敗：');
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadShifts() async {
    final shifts = await _repository.getStaffShifts(
      widget.profile['id'],
      _selectedMonth,
    );
    setState(() => _shifts = shifts);
  }

  Future<void> _saveBasicInfo() async {
    if (_detail == null) return;
    setState(() => _isLoading = true);
    try {
      final newDetail = StaffDetailModel(
        id: _detail!.id,
        coachHourlyRate: int.tryParse(_coachRateCtrl.text) ?? 0,
        deskHourlyRate: int.tryParse(_deskRateCtrl.text) ?? 180,
        bankAccount: _bankCtrl.text,
        status: _detail!.status,
      );
      await _repository.updateStaffDetail(newDetail);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('儲存成功')));
    } catch (e) {
      showErrorSnackBar(context, e, prefix: '儲存失敗：');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.profile['full_name'] ?? '員工資料'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '薪資設定'),
            Tab(text: '櫃檯排班'),
            Tab(text: '教課紀錄'), // 這裡先做簡單顯示
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildBasicInfoTab(),
                _buildShiftsTab(),
                const Center(child: Text('教課紀錄列表 (可沿用 Session 查詢邏輯)')),
              ],
            ),
    );
  }

  // Tab 1: 薪資設定
  Widget _buildBasicInfoTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const CircleAvatar(radius: 40, child: Icon(Icons.person, size: 40)),
          const SizedBox(height: 16),
          Text(
            widget.profile['full_name'],
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 24),

          TextField(
            controller: _coachRateCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: '教練時薪 (Coach Rate)',
              prefixText: '\$',
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _deskRateCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: '櫃檯時薪 (Desk Rate)',
              prefixText: '\$',
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _bankCtrl,
            decoration: const InputDecoration(
              labelText: '銀行帳號 (Bank Account)',
              icon: Icon(Icons.account_balance),
            ),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _saveBasicInfo,
              child: const Text('儲存設定'),
            ),
          ),
        ],
      ),
    );
  }

  // Tab 2: 排班管理
  Widget _buildShiftsTab() {
    return Column(
      children: [
        // 月份切換
        Container(
          color: Colors.grey[100],
          padding: const EdgeInsets.all(8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: () {
                  setState(
                    () => _selectedMonth = DateTime(
                      _selectedMonth.year,
                      _selectedMonth.month - 1,
                    ),
                  );
                  _loadShifts();
                },
              ),
              Text(
                DateFormat('yyyy年 MM月').format(_selectedMonth),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: () {
                  setState(
                    () => _selectedMonth = DateTime(
                      _selectedMonth.year,
                      _selectedMonth.month + 1,
                    ),
                  );
                  _loadShifts();
                },
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: _shifts.length,
            itemBuilder: (context, index) {
              final shift = _shifts[index];
              final duration =
                  shift.endTime.difference(shift.startTime).inMinutes / 60.0;

              return ListTile(
                leading: const Icon(Icons.access_time),
                title: Text(
                  '${DateFormat('MM/dd (E)').format(shift.startTime)}  ${DateFormat('HH:mm').format(shift.startTime)} - ${DateFormat('HH:mm').format(shift.endTime)}',
                ),
                subtitle: Text(
                  '時數: ${duration.toStringAsFixed(1)} hr ${shift.note != null ? "(${shift.note})" : ""}',
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.delete, color: Colors.grey),
                  onPressed: () async {
                    final confirm = await showDialog(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text('刪除排班'),
                        content: const Text('確定要刪除此紀錄嗎？'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('取消'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('刪除'),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      await _repository.deleteWorkShift(shift.id);
                      _loadShifts(); // 重整
                    }
                  },
                ),
                onTap: () => _showShiftDialog(shift: shift),
              );
            },
          ),
        ),
      ],
    );
  }

  // 新增/編輯排班 Dialog
  Future<void> _showShiftDialog({WorkShiftModel? shift}) async {
    // 預設時間：如果是新增，預設為選定月份的1號早上9點
    DateTime start =
        shift?.startTime ??
        DateTime(
          _selectedMonth.year,
          _selectedMonth.month,
          DateTime.now().day,
          9,
          0,
        );
    DateTime end = shift?.endTime ?? start.add(const Duration(hours: 4));
    final noteCtrl = TextEditingController(text: shift?.note);

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text(shift == null ? '新增排班' : '編輯排班'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  title: const Text('開始時間'),
                  subtitle: Text(DateFormat('yyyy/MM/dd HH:mm').format(start)),
                  onTap: () async {
                    // 簡化版：先不寫複雜的日期選擇器，假設您會接 DatePicker
                    final date = await showDatePicker(
                      context: context,
                      initialDate: start,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030),
                    );
                    if (date != null) {
                      final time = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.fromDateTime(start),
                      );
                      if (time != null) {
                        setDialogState(
                          () => start = DateTime(
                            date.year,
                            date.month,
                            date.day,
                            time.hour,
                            time.minute,
                          ),
                        );
                      }
                    }
                  },
                ),
                ListTile(
                  title: const Text('結束時間'),
                  subtitle: Text(DateFormat('yyyy/MM/dd HH:mm').format(end)),
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: end,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030),
                    );
                    if (date != null) {
                      final time = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.fromDateTime(end),
                      );
                      if (time != null) {
                        setDialogState(
                          () => end = DateTime(
                            date.year,
                            date.month,
                            date.day,
                            time.hour,
                            time.minute,
                          ),
                        );
                      }
                    }
                  },
                ),
                TextField(
                  controller: noteCtrl,
                  decoration: const InputDecoration(labelText: '備註'),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('取消'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final newShift = WorkShiftModel(
                    id: shift?.id ?? '', // 空字串代表新增
                    staffId: widget.profile['id'],
                    startTime: start,
                    endTime: end,
                    note: noteCtrl.text,
                  );
                  await _repository.upsertWorkShift(newShift);
                  if (mounted) Navigator.pop(context);
                  _loadShifts(); // 重整列表
                },
                child: const Text('儲存'),
              ),
            ],
          );
        },
      ),
    );
  }
}
