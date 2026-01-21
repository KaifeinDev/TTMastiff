import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ttmastiff/data/models/payroll_model.dart';
import 'package:ttmastiff/data/services/salary_repository.dart';
import 'widgets/payroll_edit_dialog.dart'; // 下面會寫

class SalaryManagementScreen extends StatefulWidget {
  const SalaryManagementScreen({super.key});

  @override
  State<SalaryManagementScreen> createState() => _SalaryManagementScreenState();
}

class _SalaryManagementScreenState extends State<SalaryManagementScreen> {
  late SalaryRepository _repository;
  DateTime _selectedDate = DateTime.now(); // 只看年/月
  bool _isLoading = false;

  // 這裡簡單用一個 Map 來存每個員工的計算結果
  // Key: StaffName, Value: PayrollModel
  List<Map<String, dynamic>> _staffList = [];

  @override
  void initState() {
    super.initState();
    _repository = SalaryRepository(Supabase.instance.client);
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    // 1. 先抓所有員工 (Profiles)
    final profiles = await Supabase.instance.client.from('profiles').select();

    List<Map<String, dynamic>> tempList = [];

    for (var p in profiles) {
      final String staffId = p['id'];
      final String name = p['full_name'] ?? '未知';

      // 2. 檢查該月是否已結算 (DB有紀錄)
      final payrolls = await _repository.getPayrolls(
        _selectedDate.year,
        _selectedDate.month,
      );
      PayrollModel? record;

      try {
        record = payrolls.firstWhere((e) => e.staffId == staffId);
      } catch (e) {
        // 沒找到
      }

      // 3. 如果沒結算，跑即時計算
      if (record == null) {
        record = await _repository.calculateEstimatedSalary(
          staffId: staffId,
          year: _selectedDate.year,
          month: _selectedDate.month,
        );
      }

      tempList.add({'profile': p, 'payroll': record});
    }

    setState(() {
      _staffList = tempList;
      _isLoading = false;
    });
  }

  void _changeMonth(int offset) {
    setState(() {
      _selectedDate = DateTime(
        _selectedDate.year,
        _selectedDate.month + offset,
      );
    });
    _loadData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('薪資管理')),
      body: Column(
        children: [
          // 1. 月份選擇器
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.blue.shade50,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () => _changeMonth(-1),
                ),
                Text(
                  '${_selectedDate.year}年 ${_selectedDate.month}月',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () => _changeMonth(1),
                ),
              ],
            ),
          ),

          // 2. 員工列表
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    itemCount: _staffList.length,
                    itemBuilder: (context, index) {
                      final item = _staffList[index];
                      final name = item['profile']['full_name'];
                      final PayrollModel payroll = item['payroll'];
                      final bool isLocked = payroll.id.isNotEmpty; // 有ID代表已存過檔

                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: ListTile(
                          title: Text(
                            name,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            '教課: ${payroll.totalCoachHours}hr | 櫃檯: ${payroll.totalDeskHours}hr\n'
                            '狀態: ${isLocked ? (payroll.status == 'paid' ? '已發放' : '已結算(未發)') : '未結算'}',
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '\$${payroll.totalAmount}',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue,
                                ),
                              ),
                              const SizedBox(width: 12),
                              ElevatedButton(
                                onPressed: () {
                                  // 跳出結算/編輯視窗
                                  showDialog(
                                    context: context,
                                    builder: (_) => PayrollEditDialog(
                                      staffName: name,
                                      payroll: payroll,
                                      onConfirm: (updatedPayroll) async {
                                        await _repository.savePayroll(
                                          updatedPayroll,
                                        );
                                        _loadData(); // 重整
                                      },
                                    ),
                                  );
                                },
                                child: Text(isLocked ? '查看/修改' : '結算'),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
