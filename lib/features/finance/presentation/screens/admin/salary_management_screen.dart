import 'package:flutter/material.dart';
import 'package:ttmastiff/core/utils/util.dart';
import 'package:ttmastiff/core/di/service_locator.dart';
import 'package:ttmastiff/features/finance/data/repositories/salary_repository.dart';
import '../../../data/models/payroll_model.dart';
import '../../widgets/salary/payroll_edit_dialog.dart';
import '../../widgets/salary/salary_card.dart';
import '../../widgets/salary/payroll_dashboard.dart';

class SalaryManagementScreen extends StatefulWidget {
  const SalaryManagementScreen({super.key});

  @override
  State<SalaryManagementScreen> createState() => _SalaryManagementScreenState();
}

class _SalaryManagementScreenState extends State<SalaryManagementScreen> {
  final salaryRepository = getIt<SalaryRepository>();
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;
  List<Map<String, dynamic>> _staffList = [];

  String _searchQuery = '';
  String _statusFilter = 'All';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  bool get _isCurrentMonth {
    final now = DateTime.now();
    return _selectedDate.year == now.year && _selectedDate.month == now.month;
  }

  // 動態過濾清單
  List<Map<String, dynamic>> get _filteredList {
    return _staffList.where((item) {
      final PayrollModel p = item['payroll'];
      final String name = item['profile']['full_name'] ?? '';

      // A. 搜尋過濾
      if (_searchQuery.isNotEmpty && !name.contains(_searchQuery)) {
        return false;
      }

      // B. 狀態過濾
      if (_statusFilter != 'All') {
        if (_statusFilter == 'Unsettled') {
          final isUnsettled = p.status == 'unsettled' || p.id.isEmpty;
          if (!isUnsettled) return false;
        } else if (p.status != _statusFilter.toLowerCase()) {
          return false;
        }
      }
      return true;
    }).toList();
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
      logError(e);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _changeMonth(int offset) {
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
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('薪資管理'),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // 1. 月份選擇器 (保留固定在最上方，方便隨時切換月份)
          Container(
            color: Colors.white,
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
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: _isCurrentMonth ? null : () => _changeMonth(1),
                  color: _isCurrentMonth ? Colors.grey : Colors.black,
                ),
              ],
            ),
          ),

          // 2. 核心捲動區域 (使用 Expanded 填滿剩餘空間)
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _staffList.isEmpty
                ? const Center(child: Text("本月無資料"))
                : CustomScrollView(
                    // 🔥 關鍵：把 Dashboard, Search, List 全部放在這裡面
                    slivers: [
                      // A. 儀表板 (Dashboard) - 隨捲動滑走
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 10), // 加一點間距
                          child: PayrollDashboard(staffList: _staffList),
                        ),
                      ),

                      // B. 搜尋與篩選區 - 隨捲動滑走
                      SliverToBoxAdapter(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 4,
                          ),
                          color: Colors.grey[50], // 與背景融合
                          child: Column(
                            children: [
                              // 搜尋框
                              TextField(
                                decoration: InputDecoration(
                                  hintText: '搜尋教練姓名...',
                                  prefixIcon: const Icon(
                                    Icons.search,
                                    color: Colors.grey,
                                  ),
                                  filled: true,
                                  fillColor: Colors.white,
                                  contentPadding: const EdgeInsets.symmetric(
                                    vertical: 0,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(30),
                                    borderSide: BorderSide.none,
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(30),
                                    borderSide: BorderSide(
                                      color: Colors.grey.shade200,
                                    ),
                                  ),
                                ),
                                onChanged: (val) =>
                                    setState(() => _searchQuery = val),
                              ),
                              const SizedBox(height: 12),

                              // 狀態 Filter Chips
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children: [
                                    _buildFilterChip('全部', 'All'),
                                    const SizedBox(width: 8),
                                    _buildFilterChip(
                                      '未結算',
                                      'Unsettled',
                                      color: Colors.blue,
                                    ),
                                    const SizedBox(width: 8),
                                    _buildFilterChip(
                                      '已結算',
                                      'Calculated',
                                      color: Colors.orange,
                                    ),
                                    const SizedBox(width: 8),
                                    _buildFilterChip(
                                      '已發放',
                                      'Paid',
                                      color: Colors.green,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 10),
                            ],
                          ),
                        ),
                      ),

                      // C. 列表區 (SliverList)
                      _filteredList.isEmpty
                          ? SliverToBoxAdapter(
                              child: Container(
                                alignment: Alignment.center,
                                color: Colors.grey[50],
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.search_off,
                                      size: 64,
                                      color: Colors.grey[300],
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      '沒有符合條件的教練',
                                      style: TextStyle(color: Colors.grey[500]),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : SliverList(
                              delegate: SliverChildBuilderDelegate((
                                context,
                                index,
                              ) {
                                final item = _filteredList[index];
                                final name =
                                    item['profile']['full_name'] ?? '員工';
                                final PayrollModel payroll = item['payroll'];
                                final int baseRate = item['base_rate'] ?? 350;

                                String displayStatus = payroll.id.isEmpty
                                    ? 'unsettled'
                                    : payroll.status;

                                return SalaryCard(
                                  name: name,
                                  bankAccount: item['bank_account'] as String?,
                                  baseCoachRate: baseRate,
                                  coachHours: payroll.totalCoachHours,
                                  deskHours: payroll.totalDeskHours,
                                  adjustmentHours:
                                      payroll.adjustmentHours ?? 0.0,
                                  bonus: payroll.bonus,
                                  deduction: payroll.deduction,
                                  totalAmount: payroll.totalAmount,
                                  status: displayStatus,
                                  onAction: () =>
                                      _showEditDialog(name, payroll, baseRate),
                                );
                              }, childCount: _filteredList.length),
                            ),

                      // 底部留白，避免最後一張卡片被手機手勢條擋住
                      const SliverToBoxAdapter(child: SizedBox(height: 40)),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value, {Color? color}) {
    final isSelected = _statusFilter == value;
    final themeColor = color ?? Theme.of(context).colorScheme.primary;

    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _statusFilter = value;
          });
        }
      },
      selectedColor: themeColor.withValues(alpha: 0.15),
      backgroundColor: Colors.grey.shade50,
      side: BorderSide(color: isSelected ? themeColor : Colors.grey.shade300),
      labelStyle: TextStyle(
        color: isSelected ? themeColor : Colors.grey[600],
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      showCheckmark: false,
    );
  }

  void _showEditDialog(String name, PayrollModel payroll, int baseRate) {
    showDialog(
      context: context,
      builder: (_) => PayrollEditDialog(
        staffName: name,
        payroll: payroll,
        baseCoachRate: baseRate,
        onConfirm: (updatedPayroll) async {
          await salaryRepository.savePayroll(updatedPayroll);
          if (mounted) _loadData();
        },
      ),
    );
  }
}
