import 'package:flutter/material.dart';
import 'package:ttmastiff/data/models/payroll_model.dart';
import 'package:ttmastiff/main.dart';
import 'widgets/payroll_edit_dialog.dart';

class SalaryManagementScreen extends StatefulWidget {
  const SalaryManagementScreen({super.key});

  @override
  State<SalaryManagementScreen> createState() => _SalaryManagementScreenState();
}

class _SalaryManagementScreenState extends State<SalaryManagementScreen> {
  DateTime _selectedDate = DateTime.now(); // 只看年/月
  bool _isLoading = false;

  // 這裡簡單用一個 Map 來存每個員工的計算結果
  // Key: StaffName, Value: PayrollModel
  List<Map<String, dynamic>> _staffList = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      // 🔥 修改重點：不再前端跑迴圈，而是呼叫一次 Repository
      // 後端會一次平行抓取 Profile, Session, Shift 並完成配對計算
      final report = await salaryRepository.getMonthlySalaryReport(
        _selectedDate.year,
        _selectedDate.month,
      );

      setState(() {
        _staffList = report; // 直接接收處理好的資料
      });
    } catch (e) {
      debugPrint('Error loading data: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('載入失敗: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
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
                                        await salaryRepository.savePayroll(
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
