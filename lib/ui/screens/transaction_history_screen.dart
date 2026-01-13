import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/models/transaction_model.dart'; // 請確認路徑正確

// 定義篩選類型枚舉
enum TransactionFilter { all, income, expense }

class TransactionHistoryScreen extends StatefulWidget {
  const TransactionHistoryScreen({super.key});

  @override
  State<TransactionHistoryScreen> createState() =>
      _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState extends State<TransactionHistoryScreen> {
  // 狀態變數
  final List<TransactionModel> _transactions = [];
  bool _isLoading = false;
  bool _hasMore = true;
  int _page = 0;
  final int _pageSize = 20;
  TransactionFilter _currentFilter = TransactionFilter.all;
  late ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
              _scrollController.position.maxScrollExtent - 200 &&
          !_isLoading &&
          _hasMore) {
        _loadData();
      }
    });

    _loadData(isRefresh: true);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  // 🔥 載入資料 (這部分邏輯不變)
  Future<void> _loadData({bool isRefresh = false}) async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      if (isRefresh) {
        _transactions.clear();
        _page = 0;
        _hasMore = true;
      }
    });

    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) throw '未登入';

      final start = _page * _pageSize;
      final end = start + _pageSize - 1;

      var query = Supabase.instance.client
          .from('transactions')
          .select()
          .eq('user_id', userId);

      if (_currentFilter == TransactionFilter.income) {
        query = query.gte('amount', 0);
      } else if (_currentFilter == TransactionFilter.expense) {
        query = query.lt('amount', 0);
      }

      final List<dynamic> response = await query
          .order('created_at', ascending: false)
          .range(start, end);

      final newItems = response
          .map((e) => TransactionModel.fromJson(e))
          .toList();

      if (mounted) {
        setState(() {
          _transactions.addAll(newItems);
          _page++;
          if (newItems.length < _pageSize) {
            _hasMore = false;
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('載入失敗: $e')));
        setState(() => _isLoading = false);
      }
    }
  }

  void _onFilterChanged(TransactionFilter filter) {
    if (_currentFilter == filter) return;
    setState(() {
      _currentFilter = filter;
    });
    _loadData(isRefresh: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          '點數紀錄',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: Column(
        children: [
          _buildFilterSection(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async => _loadData(isRefresh: true),
              child: _transactions.isEmpty && !_isLoading
                  ? _buildEmptyView()
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.only(bottom: 20),
                      itemCount: _transactions.length + (_hasMore ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == _transactions.length) {
                          return const Padding(
                            padding: EdgeInsets.all(16.0),
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }

                        final item = _transactions[index];
                        bool showHeader = false;
                        if (index == 0) {
                          showHeader = true;
                        } else {
                          final prevItem = _transactions[index - 1];
                          final currentMonth = DateFormat(
                            'yyyy/MM',
                          ).format(item.createdAt);
                          final prevMonth = DateFormat(
                            'yyyy/MM',
                          ).format(prevItem.createdAt);
                          if (currentMonth != prevMonth) showHeader = true;
                        }

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (showHeader) _buildMonthHeader(item.createdAt),
                            _buildTransactionItem(item),
                          ],
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterSection() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: Row(
        children: [
          _buildFilterChip('全部', TransactionFilter.all),
          const SizedBox(width: 8),
          _buildFilterChip('儲值/退還', TransactionFilter.income),
          const SizedBox(width: 8),
          _buildFilterChip('使用紀錄', TransactionFilter.expense),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, TransactionFilter filter) {
    final isSelected = _currentFilter == filter;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: Colors.blue.shade100,
      labelStyle: TextStyle(
        color: isSelected ? Colors.blue.shade900 : Colors.grey.shade700,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      onSelected: (selected) {
        if (selected) _onFilterChanged(filter);
      },
    );
  }

  Widget _buildMonthHeader(DateTime date) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
      child: Text(
        DateFormat('yyyy年 M月', 'zh_TW').format(date),
        style: TextStyle(
          color: Colors.grey.shade600,
          fontWeight: FontWeight.bold,
          fontSize: 15,
        ),
      ),
    );
  }

  // 🔥 核心修改：使用 Metadata 渲染 UI
  Widget _buildTransactionItem(TransactionModel item) {
    // 1. 直接從 Metadata 拿資料 (優雅！)
    final String? courseName = item.metadata['course_name'];
    final String? sessionInfo = item.metadata['session_info'];
    final String? studentName = item.metadata['student_name'];

    // 2. 判斷交易類型 (優先看 type 欄位，或者 metadata 裡的 type)
    final bool isRefund =
        item.type == 'refund' || item.metadata['type'] == 'refund';

    // 3. Fallback: 如果是舊資料沒有 metadata，只好顯示 description
    // 但還是簡單做個字串清理，去掉 "報名課程: " 這種贅字
    final String displayTitle =
        courseName ??
        item.description?.replaceAll(RegExp(r'^(報名課程: |取消退還: )'), '') ??
        '交易紀錄';

    final bool isPositive = item.amount >= 0;

    // 設定顏色與圖示
    Color iconBgColor;
    Color iconColor;
    IconData iconData;

    if (isPositive) {
      if (isRefund) {
        // 退款
        iconBgColor = Colors.blue.shade50;
        iconColor = Colors.blue;
        iconData = Icons.undo;
      } else {
        // 儲值
        iconBgColor = Colors.green.shade50;
        iconColor = Colors.green.shade700;
        iconData = Icons.account_balance_wallet;
      }
    } else {
      // 消費 (扣點)
      iconBgColor = Colors.orange.shade50;
      iconColor = Colors.orange.shade800;
      iconData = Icons.confirmation_number_outlined;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: iconBgColor, shape: BoxShape.circle),
          child: Icon(iconData, color: iconColor, size: 24),
        ),

        // 標題：課程名稱
        title: Padding(
          padding: const EdgeInsets.only(bottom: 6.0),
          child: Text(
            displayTitle,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),

        // 副標題：顯示詳細資訊 (學生、時間、建立日期)
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 👤 顯示學生姓名 (如果有的話)
            if (studentName != null) ...[
              Row(
                children: [
                  Icon(Icons.person, size: 14, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Text(
                    studentName,
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.w500,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
            ],

            // 📅 顯示上課時間 (如果有的話)
            if (sessionInfo != null) ...[
              Row(
                children: [
                  Icon(
                    Icons.event_available,
                    size: 14,
                    color: Colors.blue.shade700,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    sessionInfo,
                    style: TextStyle(
                      color: Colors.blue.shade700,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
            ],

            // 🕒 交易建立時間 (永遠顯示)
            Text(
              '交易時間: ${DateFormat('MM/dd HH:mm').format(item.createdAt.toLocal())}',
              style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
            ),
          ],
        ),

        trailing: Text(
          '${isPositive ? "+" : ""}${item.amount}',
          style: TextStyle(
            color: isPositive
                ? (isRefund ? Colors.blue : Colors.green.shade700)
                : Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.filter_list_off, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text('沒有符合條件的紀錄', style: TextStyle(color: Colors.grey.shade500)),
        ],
      ),
    );
  }
}
