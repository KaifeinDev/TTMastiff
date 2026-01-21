import 'package:flutter/material.dart';
import 'package:ttmastiff/main.dart';
import '../../../../data/models/payroll_model.dart';
import 'widgets/payroll_edit_dialog.dart';
import 'widgets/salary_card.dart';
import 'widgets/payroll_dashboard.dart';

class SalaryManagementScreen extends StatefulWidget {
  const SalaryManagementScreen({super.key});

  @override
  State<SalaryManagementScreen> createState() => _SalaryManagementScreenState();
}

class _SalaryManagementScreenState extends State<SalaryManagementScreen> {
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;
  List<Map<String, dynamic>> _staffList = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  // 🔒 判斷是否為當月 (避免選到未來)
  bool get _isCurrentMonth {
    final now = DateTime.now();
    return _selectedDate.year == now.year && _selectedDate.month == now.month;
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final report = await salaryRepository.getMonthlySalaryReport(
        _selectedDate.year,
        _selectedDate.month,
      );
      setState(() {
        _staffList = report;
      });
    } catch (e) {
      debugPrint('Error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _changeMonth(int offset) {
    // 如果是往後且已經是當月，則不動作
    if (offset > 0 && _isCurrentMonth) return;

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
      appBar: AppBar(
        title: const Text('薪資管理'),
        backgroundColor: Colors.blue.shade50,
      ),
      body: Column(
        children: [
          // 1. 月份選擇器
          Container(
            color: Colors.blue.shade50,
            padding: const EdgeInsets.only(bottom: 10),
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
                // 🔒 限制：如果是當月，按鈕變灰且不可點
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: _isCurrentMonth ? null : () => _changeMonth(1),
                  color: _isCurrentMonth ? Colors.grey : Colors.black,
                ),
              ],
            ),
          ),

          if (!_isLoading && _staffList.isNotEmpty)
            PayrollDashboard(staffList: _staffList),

          // 2. 列表
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _staffList.isEmpty
                ? const Center(child: Text("本月無資料"))
                : ListView.builder(
                    itemCount: _staffList.length,
                    padding: const EdgeInsets.only(top: 8, bottom: 24),
                    itemBuilder: (context, index) {
                      final item = _staffList[index];
                      final name = item['profile']['full_name'] ?? '員工';
                      final PayrollModel payroll = item['payroll'];

                      // 🐛 修復 Badge 狀態邏輯
                      // 優先看 payroll.status，如果 DB 有存 'paid' 或 'confirmed' 就用它
                      // 只有當 id 為空 (沒存過檔) 才強制顯示為 'unsettled'
                      final int baseRate = item['base_rate'] ?? 350;

                      String displayStatus = payroll.id.isEmpty
                          ? 'unsettled'
                          : payroll.status;

                      return SalaryCard(
                        name: name,
                        baseCoachRate:
                            baseRate, // 🔥 2. 新增：傳入底薪給卡片 (讓它知道下一階是多少)
                        coachHours: payroll.totalCoachHours,
                        deskHours: payroll.totalDeskHours,
                        adjustmentHours:
                            payroll.adjustmentHours ?? 0.0, // 確保不為 null
                        totalAmount: payroll.totalAmount,
                        status: displayStatus,
                        // 🔥 3. 修改：傳入底薪給 Dialog 函式
                        onAction: () =>
                            _showEditDialog(name, payroll, baseRate),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _showEditDialog(String name, PayrollModel payroll, int baseRate) {
    showDialog(
      context: context,
      builder: (_) => PayrollEditDialog(
        staffName: name,
        payroll: payroll,
        baseCoachRate: baseRate, // 🔥 4. 傳遞底薪給彈窗
        onConfirm: (updatedPayroll) async {
          await salaryRepository.savePayroll(updatedPayroll);
          if (mounted) _loadData();
        },
      ),
    );
  }
}
