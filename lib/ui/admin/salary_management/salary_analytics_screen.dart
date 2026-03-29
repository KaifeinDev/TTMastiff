import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ttmastiff/core/utils/util.dart';
import 'package:ttmastiff/main.dart';
import 'package:ttmastiff/data/models/payroll_model.dart';

class SalaryAnalyticsScreen extends StatefulWidget {
  const SalaryAnalyticsScreen({super.key});

  @override
  State<SalaryAnalyticsScreen> createState() => _SalaryAnalyticsScreenState();
}

class _SalaryAnalyticsScreenState extends State<SalaryAnalyticsScreen> {
  bool _isLoading = true;

  int _selectedYear = DateTime.now().year;
  String? _selectedStaffId; // null 代表 "全體"
  
  // 員工選單
  List<Map<String, dynamic>> _staffList = [];
  
  // 圖表數據 (Index 0=1月, 11=12月)
  List<double> _thisYearData = List.filled(12, 0);
  List<double> _lastYearData = List.filled(12, 0);

  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<void> _initData() async {
    // 1. 抓員工名單供篩選
    final profiles = await Supabase.instance.client.from('profiles').select();
    _staffList = List<Map<String, dynamic>>.from(profiles);
    
    // 2. 抓圖表數據
    await _loadChartData();
  }

  Future<void> _loadChartData() async {
    setState(() => _isLoading = true);
    try {
      // 分別抓今年和去年整年的數據
      final thisYearPayrolls = await salaryRepository.getYearlyPayrolls(_selectedYear);
      final lastYearPayrolls = await salaryRepository.getYearlyPayrolls(_selectedYear - 1);

      _thisYearData = _processData(thisYearPayrolls);
      _lastYearData = _processData(lastYearPayrolls);

    } catch (e) {
      logError(e);
      if (mounted) {
        showErrorSnackBar(context, e, prefix: '載入圖表失敗：');
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  /// 將 [PayrollModel] 列表轉為 12 個月份的總金額
  List<double> _processData(List<PayrollModel> payrolls) {
    List<double> monthlyTotals = List.filled(12, 0);

    for (var p in payrolls) {
      // 篩選：如果選了特定員工，且這張單不是他的，就跳過
      if (_selectedStaffId != null && p.staffId != _selectedStaffId) {
        continue;
      }
      
      // 注意：Payroll 的 month 可能是 1~12，Array Index 是 0~11
      if (p.month >= 1 && p.month <= 12) {
        monthlyTotals[p.month - 1] += p.totalAmount.toDouble();
      }
    }
    return monthlyTotals;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('薪資趨勢分析')),
      body: Column(
        children: [
          // 篩選器區域
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                // 年份選擇
                DropdownButton<int>(
                  value: _selectedYear,
                  items: [2024, 2025, 2026, 2027].map((y) => DropdownMenuItem(value: y, child: Text('$y年'))).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _selectedYear = val);
                      _loadChartData();
                    }
                  },
                ),
                const SizedBox(width: 16),
                // 員工選擇
                Expanded(
                  child: DropdownButton<String?>(
                    value: _selectedStaffId,
                    isExpanded: true,
                    hint: const Text('全體員工'),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('全體員工')),
                      ..._staffList.map((s) => DropdownMenuItem(
                        value: s['id'] as String,
                        child: Text(s['full_name'] ?? '未命名'),
                      )),
                    ],
                    onChanged: (val) {
                      setState(() => _selectedStaffId = val);
                      _loadChartData(); // 本地重算即可，其實不需要重抓 API，但為了簡單先重抓
                    },
                  ),
                ),
              ],
            ),
          ),
          
          const Divider(),

          // 圖表區域
          Expanded(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator())
              : Padding(
                  padding: const EdgeInsets.only(right: 24, left: 12, top: 24, bottom: 12),
                  child: LineChart(
                    LineChartData(
                      gridData: const FlGridData(show: true, drawVerticalLine: false),
                      titlesData: FlTitlesData(
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              // X軸顯示 1月~12月
                              int month = value.toInt() + 1;
                              if (month % 2 != 0) return Text('$month月', style: const TextStyle(fontSize: 10)); // 只顯示單數月避免擁擠
                              return const SizedBox();
                            },
                            interval: 1,
                          ),
                        ),
                        leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40)),
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      ),
                      borderData: FlBorderData(show: true, border: Border.all(color: Colors.grey.shade300)),
                      lineBarsData: [
                        // 去年數據 (灰色虛線)
                        LineChartBarData(
                          spots: _generateSpots(_lastYearData),
                          isCurved: true,
                          color: Colors.grey.shade400,
                          barWidth: 2,
                          isStrokeCapRound: true,
                          dotData: const FlDotData(show: false),
                          dashArray: [5, 5], // 虛線效果
                        ),
                        // 今年數據 (藍色實線)
                        LineChartBarData(
                          spots: _generateSpots(_thisYearData),
                          isCurved: true,
                          color: Colors.blue,
                          barWidth: 4,
                          isStrokeCapRound: true,
                          dotData: const FlDotData(show: true),
                          belowBarData: BarAreaData(show: true, color: Colors.blue.withValues(alpha: 0.1)),
                        ),
                      ],
                      // 互動 Tooltip
                      lineTouchData: LineTouchData(
                        touchTooltipData: LineTouchTooltipData(
                          getTooltipItems: (touchedSpots) {
                            return touchedSpots.map((spot) {
                              final yearLabel = spot.barIndex == 0 ? '去年' : '今年';
                              return LineTooltipItem(
                                '$yearLabel: \$${spot.y.toInt()}',
                                const TextStyle(color: Colors.white),
                              );
                            }).toList();
                          },
                        ),
                      ),
                    ),
                  ),
                ),
          ),
          
          // 圖例
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildLegend(Colors.blue, '今年 ($_selectedYear)'),
                const SizedBox(width: 24),
                _buildLegend(Colors.grey.shade400, '去年 (${_selectedYear - 1})', isDashed: true),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<FlSpot> _generateSpots(List<double> data) {
    return List.generate(data.length, (index) => FlSpot(index.toDouble(), data[index]));
  }

  Widget _buildLegend(Color color, String text, {bool isDashed = false}) {
    return Row(
      children: [
        Container(
          width: 16, height: 4,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(text, style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    );
  }
}