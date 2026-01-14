import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:ttmastiff/data/models/transaction_model.dart';
import 'package:ttmastiff/main.dart'; // 取得全域 creditRepository & authManager

// 引入拆分後的 Widgets
import 'widgets/transaction_dashboard.dart';
import 'widgets/transaction_desktop_table.dart';
import 'widgets/transaction_mobile_list.dart';

class AdminTransactionScreen extends StatefulWidget {
  const AdminTransactionScreen({super.key});

  @override
  State<AdminTransactionScreen> createState() => _AdminTransactionScreenState();
}

class _AdminTransactionScreenState extends State<AdminTransactionScreen> {
  // --- State: 資料 ---
  List<TransactionModel> _transactions = [];
  bool _isLoading = false;

  // --- State: 權限 ---
  bool get _isAdmin => authManager.isAdmin;

  // --- State: 篩選 ---
  // 預設初始化為「今天」
  DateTimeRange _dateRange = DateTimeRange(
    start: DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    ),
    end: DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    ),
  );

  bool? _filterIsReconciled; // null=全部, false=未對帳, true=已對帳

  // --- State: 勾選 (批量操作) ---
  final Set<String> _selectedIds = {};

  // --- State: 儀表板統計 ---
  int _totalPendingCash = 0;
  int _totalSettled = 0;
  Map<String, int> _operatorStats = {};

  @override
  void initState() {
    super.initState();
    // 進入頁面時自動載入 (預設是今天的資料)
    _loadData();
  }

  // --- Logic: 載入資料 ---
  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      // 呼叫 Repository，這裡會將 Local Time 轉為 UTC 發送給 Supabase
      final data = await transactionRepository.fetchAdminTransactions(
        startDate: _dateRange.start,
        endDate: _dateRange.end,
        isReconciled: _filterIsReconciled,
      );

      setState(() {
        _transactions = data;
        _selectedIds.clear(); // 重新載入時清空勾選
        _calculateStats(data);
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('載入失敗: $e')));
        setState(() => _isLoading = false);
      }
    }
  }

  // --- Logic: 計算統計數據 ---
  void _calculateStats(List<TransactionModel> data) {
    int pending = 0;
    int settled = 0;
    Map<String, int> opStats = {};

    for (var tx in data) {
      // 🔥 修正: 已退款 (refunded) 的交易不計入統計
      if (tx.status == 'refunded') continue;

      // 只計算正向金額 (收入)
      if (tx.amount > 0) {
        if (tx.isReconciled) {
          settled += tx.amount;
        } else {
          pending += tx.amount;

          // 累加該經手人的未繳金額
          final opName = tx.operatorFullName ?? '系統/未知';
          opStats[opName] = (opStats[opName] ?? 0) + tx.amount;
        }
      }
    }
    _totalPendingCash = pending;
    _totalSettled = settled;
    _operatorStats = opStats;
  }

  // --- Logic: 執行對帳 ---
  Future<void> _executeReconcile(List<String> ids) async {
    // 雙重保險：如果不是 Admin，前端直接擋下
    if (!_isAdmin || ids.isEmpty) return;
    try {
      await transactionRepository.reconcileTransactions(ids);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('對帳完成！')));
        _loadData(); // 重整
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('對帳失敗: $e')));
      }
    }
  }

  // --- Logic: 退款 Dialog ---
  void _showRefundDialog(TransactionModel tx) {
    // 只有 Admin 能看到並執行這個函數，但再次檢查較安全
    if (!_isAdmin) return;

    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('確認退款'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('即將退還 \$${tx.amount} 給 ${tx.userFullName ?? '用戶'}'),
            const SizedBox(height: 8),
            const Text(
              '⚠️ 注意：退款後此交易將標記為作廢，並產生一筆新的負向交易紀錄。',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: '退款原因',
                hintText: '例如: 輸入錯誤、家長要求退費',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context); // 關閉 Dialog
              try {
                await transactionRepository.refundGeneralTransaction(
                  originalTransactionId: tx.id,
                  reason: reasonController.text,
                );
                if (mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('已執行退款')));
                  _loadData(); // 重整
                }
              } catch (e) {
                if (mounted)
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('退款失敗: $e')));
              }
            },
            child: const Text('確認退款', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // --- Logic: 快速切換日期 ---
  void _setDateRange(int daysAgo) {
    final now = DateTime.now();
    // 確保只取日期部分 (00:00:00)
    final todayStart = DateTime(now.year, now.month, now.day);

    setState(() {
      if (daysAgo == 0) {
        // 今天
        _dateRange = DateTimeRange(start: todayStart, end: todayStart);
      } else if (daysAgo == 7) {
        // 本週 (簡易版：過去7天)
        final start = todayStart.subtract(const Duration(days: 6));
        _dateRange = DateTimeRange(start: start, end: todayStart);
      } else {
        // 本月 (本月1號 ~ 今天)
        final start = DateTime(now.year, now.month, 1);
        _dateRange = DateTimeRange(start: start, end: todayStart);
      }
    });
    _loadData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        title: const Text(
          '帳務管理',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
        ),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.black54),
            onPressed: _loadData,
          ),
        ],
      ),
      body: Column(
        children: [
          // 1. 頂部儀表板區塊 (白色背景)
          Container(
            color: Colors.white,
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // (A) 金額統計卡片
                TransactionDashboard(
                  pendingCash: _totalPendingCash,
                  settledCash: _totalSettled,
                ),

                const SizedBox(height: 8),

                // (B) 經手人欠款明細 (含滑動提示優化)
                if (_operatorStats.isNotEmpty)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                    padding: const EdgeInsets.fromLTRB(
                      12,
                      8,
                      4,
                      8,
                    ), // 右邊 padding 減少，給箭頭空間
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Row(
                      children: [
                        // 1. 固定標題頭
                        Icon(
                          Icons.assignment_late_outlined,
                          size: 16,
                          color: Colors.red.shade800,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '待收款:',
                          style: TextStyle(
                            color: Colors.red.shade900,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(width: 8),

                        // 2. 可滑動內容區 (加上漸層遮罩)
                        Expanded(
                          child: ShaderMask(
                            // 設定漸層遮罩：從左到右，最後 15% 漸漸變透明
                            shaderCallback: (Rect bounds) {
                              return const LinearGradient(
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                                colors: [
                                  Colors.purple,
                                  Colors.purple,
                                  Colors.transparent,
                                ], // 紫色不重要，重點是透明度
                                stops: [
                                  0.0,
                                  0.85,
                                  1.0,
                                ], // 0%~85% 清楚，85%~100% 變透明
                              ).createShader(bounds);
                            },
                            blendMode: BlendMode.dstIn, // 關鍵模式：只顯示重疊的部分
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              physics:
                                  const BouncingScrollPhysics(), // 加上回彈效果，手感更好
                              child: Row(
                                children: [
                                  ..._operatorStats.entries
                                      .toList()
                                      .asMap()
                                      .entries
                                      .map((entry) {
                                        final index = entry.key;
                                        final e = entry.value;
                                        final isLast =
                                            index == _operatorStats.length - 1;
                                        final amount = NumberFormat(
                                          "#,##0",
                                          "en_US",
                                        ).format(e.value);
                                        return Row(
                                          children: [
                                            RichText(
                                              text: TextSpan(
                                                style: const TextStyle(
                                                  fontSize: 13,
                                                  fontFamily: 'Roboto',
                                                ),
                                                children: [
                                                  TextSpan(
                                                    text: '${e.key} ',
                                                    style: TextStyle(
                                                      color:
                                                          Colors.red.shade800,
                                                      fontWeight:
                                                          FontWeight.normal,
                                                    ),
                                                  ),
                                                  TextSpan(
                                                    text: '\$$amount',
                                                    style: TextStyle(
                                                      color:
                                                          Colors.red.shade900,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            if (!isLast)
                                              Container(
                                                margin:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 12,
                                                    ), // 線左右的間距
                                                width: 1, // 線的寬度
                                                height:
                                                    12, // 線的高度 (比文字矮一點點比較優雅)
                                                color: Colors
                                                    .red
                                                    .shade200, // 淺紅色的線
                                              ),
                                          ],
                                        );
                                      }),
                                  // 為了讓最後一個字滑出來時不被漸層遮住，加一點空白尾巴
                                  const SizedBox(width: 20),
                                ],
                              ),
                            ),
                          ),
                        ),

                        // 3. 右側固定提示箭頭 (因為有漸層，箭頭可以不需要，但加上去更明確)
                        Icon(
                          Icons.chevron_right,
                          size: 18,
                          color: Colors.red.shade300,
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 8),
                // const Divider(height: 1, indent: 16, endIndent: 16),
                // const SizedBox(height: 8),

                // (C) 日期與篩選 (優化版：時間置頂，狀態在下，操作直觀)
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  decoration: const BoxDecoration(
                    border: Border(
                      top: BorderSide(color: Colors.black12),
                    ), // 加條細線區隔儀表板
                  ),
                  child: Column(
                    children: [
                      // 第一行：日期顯示 + 快速時間按鈕 (最重要，放在最順手的位置)
                      Row(
                        children: [
                          // 左側：日期文字 (點擊可自訂)
                          Expanded(
                            child: InkWell(
                              onTap: () async {
                                final picked = await showDateRangePicker(
                                  context: context,
                                  firstDate: DateTime(2023),
                                  lastDate: DateTime.now(),
                                  initialDateRange: _dateRange,
                                );
                                if (picked != null) {
                                  setState(() => _dateRange = picked);
                                  _loadData();
                                }
                              },
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.calendar_month,
                                    size: 18,
                                    color: Colors.blueGrey,
                                  ),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        '${DateFormat('yyyy/MM/dd').format(_dateRange.start)} - ${DateFormat('MM/dd').format(_dateRange.end)}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                          color: Colors.black87,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const Icon(
                                    Icons.arrow_drop_down,
                                    size: 20,
                                    color: Colors.grey,
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // 右側：固定顯示的快速按鈕 (絕對不隱藏)
                          Row(
                            children: [
                              _buildActionButton('今天', () => _setDateRange(0)),
                              Container(
                                width: 1,
                                height: 14,
                                color: Colors.grey.shade300,
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                ),
                              ),
                              _buildActionButton('本月', () => _setDateRange(30)),
                            ],
                          ),
                        ],
                      ),

                      const SizedBox(height: 10), // 行距
                      // 第二行：狀態篩選 (膠囊狀，視覺權重較輕)
                      SizedBox(
                        height: 32, // 固定高度讓介面更緊湊
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: [
                            _buildFilterChip('全部', null),
                            const SizedBox(width: 8),
                            _buildFilterChip(
                              '待收款',
                              false,
                              isAlert: true,
                            ), // 加個顏色強調
                            const SizedBox(width: 8),
                            _buildFilterChip('已入庫)', true),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 2. 列表區域
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : LayoutBuilder(
                    builder: (context, constraints) {
                      if (constraints.maxWidth > 800) {
                        return TransactionDesktopTable(
                          transactions: _transactions,
                          selectedIds: _selectedIds,
                          isAdmin: _isAdmin,
                          onSelectionChanged: (id, selected) {
                            setState(() {
                              if (selected) {
                                _selectedIds.add(id);
                              } else {
                                _selectedIds.remove(id);
                              }
                            });
                          },
                          onRefundTap: (tx) => _showRefundDialog(tx),
                        );
                      } else {
                        // 手機版列表
                        return TransactionMobileList(
                          transactions: _transactions,
                          isAdmin: _isAdmin,
                          onReconcileTap: (tx) => _executeReconcile([tx.id]),
                          onRefundTap: (tx) => _showRefundDialog(tx),
                        );
                      }
                    },
                  ),
          ),
        ],
      ),

      floatingActionButton: (_isAdmin && _selectedIds.isNotEmpty)
          ? FloatingActionButton.extended(
              onPressed: () => _executeReconcile(_selectedIds.toList()),
              label: Text('確認收款 (${_selectedIds.length})'),
              icon: const Icon(Icons.check),
              backgroundColor: Colors.green,
            )
          : null,
    );
  }

  // 輔助方法：純文字按鈕 (用於 今天/本月) - 樣式優化
  Widget _buildActionButton(String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(
          label,
          style: TextStyle(
            color: Colors.blue.shade700,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  // 輔助方法：狀態篩選 Chip - 樣式優化
  Widget _buildFilterChip(String label, bool? value, {bool isAlert = false}) {
    final isSelected = _filterIsReconciled == value;

    // 決定顏色
    Color bgColor = Colors.grey.shade100;
    Color textColor = Colors.black54;
    Color borderColor = Colors.transparent;

    if (isSelected) {
      if (isAlert) {
        bgColor = Colors.red.shade50;
        textColor = Colors.red.shade700;
        borderColor = Colors.red.shade200;
      } else {
        bgColor = Colors.blueGrey.shade800;
        textColor = Colors.white;
      }
    }

    return GestureDetector(
      onTap: () {
        setState(() => _filterIsReconciled = value);
        _loadData();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderColor),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: textColor,
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
