import 'package:flutter/material.dart';
import 'package:ttmastiff/core/utils/util.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../data/models/transaction_model.dart';

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

  // 🔥 載入資料
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

      // 篩選邏輯：
      // Income: 金額 > 0 (包含儲值 topup 和 取消退還 refund_credit)
      // Expense: 金額 < 0 (報名 payment)
      if (_currentFilter == TransactionFilter.income) {
        query = query.gt('amount', 0);
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
  logError(e);

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
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
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

  // --- Widgets ---

  Widget _buildFilterSection() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: Row(
        children: [
          _buildFilterChip('全部', TransactionFilter.all),
          const SizedBox(width: 8),
          _buildFilterChip('獲得點數', TransactionFilter.income),
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
      selectedColor: Theme.of(context).primaryColor.withValues(alpha: 0.2),
      backgroundColor: Colors.grey.shade100,
      labelStyle: TextStyle(
        color: isSelected
            ? Theme.of(context).primaryColor
            : Colors.grey.shade700,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        fontSize: 13,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      onSelected: (selected) {
        if (selected) _onFilterChanged(filter);
      },
    );
  }

  Widget _buildMonthHeader(DateTime date) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
      child: Text(
        DateFormat('yyyy年 M月').format(date),
        style: TextStyle(
          color: Colors.grey.shade600,
          fontWeight: FontWeight.bold,
          fontSize: 15,
        ),
      ),
    );
  }

  // 🔥 核心修改：根據新的 schema 與 metadata 渲染
  Widget _buildTransactionItem(TransactionModel item) {
    // 1. 解析 Metadata
    final meta = item.metadata;
    final courseName = meta['course_name'] as String?;
    final studentName = meta['student_name'] as String?;
    final sessionInfo = meta['session_info'] as String?;
    final reason = meta['refund_reason'] as String?;

    // 2. 判斷類型與狀態
    final type = item.type; // topup, payment, refund_credit
    final isRefunded = item.status == 'refunded'; // 是否已被管理員作廢
    final isPositive = item.amount >= 0;

    // 3. 決定顯示標題
    String displayTitle;
    if (type == 'payment') {
      displayTitle = courseName ?? '課程報名';
    } else if (type == 'refund_credit') {
      displayTitle = '$reason 退款';
    } else if (type == 'topup') {
      displayTitle = '點數儲值';
    } else {
      displayTitle = item.description ?? '交易紀錄';
    }

    // 4. 決定顏色與圖示
    Color iconBgColor;
    Color iconColor;
    IconData iconData;

    if (isRefunded) {
      // 被作廢 (灰色)
      iconBgColor = Colors.grey.shade200;
      iconColor = Colors.grey;
      iconData = Icons.block;
    } else if (type == 'topup') {
      // 儲值 (綠色)
      iconBgColor = Colors.green.shade50;
      iconColor = Colors.green.shade700;
      iconData = Icons.account_balance_wallet;
    } else if (type == 'refund_credit') {
      // 退還 (藍色)
      iconBgColor = Colors.blue.shade50;
      iconColor = Colors.blue.shade700;
      iconData = Icons.undo;
    } else {
      // 消費 (橘色)
      iconBgColor = Colors.orange.shade50;
      iconColor = Colors.orange.shade800;
      iconData = Icons.confirmation_number_outlined;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        // 如果是已作廢，邊框淡一點
        border: Border.all(
          color: isRefunded ? Colors.grey.shade200 : Colors.transparent,
        ),
        boxShadow: isRefunded
            ? []
            : [
                BoxShadow(
                  color: Colors.grey.shade100,
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        // Icon
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: iconBgColor, shape: BoxShape.circle),
          child: Icon(iconData, color: iconColor, size: 24),
        ),

        // 標題
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    displayTitle,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      // 作廢則加上刪除線
                      decoration: isRefunded
                          ? TextDecoration.lineThrough
                          : null,
                      color: isRefunded ? Colors.grey : Colors.black87,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
          ],
        ),

        // 副標題 (詳細資訊)
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 學生姓名
            if (studentName != null) _buildInfoRow(Icons.person, studentName),
            // 上課時間 (如果是課程相關)
            if (sessionInfo != null)
              _buildInfoRow(Icons.access_time, sessionInfo),
            // 如果是取消退還，顯示原課程名稱
            if (type == 'refund_credit' && courseName != null)
              _buildInfoRow(Icons.class_outlined, courseName),

            // 不在消費者端顯示退款理由
            // 如果被作廢，顯示理由
            // if (isRefunded && refundReason != '')
            //   _buildInfoRow(
            //     Icons.info_outline,
            //     '原因: $refundReason',
            //     color: Colors.red.shade300,
            //   ),
            const SizedBox(height: 4),
            // 交易時間
            Text(
              DateFormat('MM/dd HH:mm').format(item.createdAt.toLocal()),
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
          ],
        ),

        // 金額
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min, // 重要！防止 Column 撐開高度
          children: [
            Text(
              '${isPositive ? "+" : ""}${NumberFormat("#,##0", "en_US").format(item.amount)}',
              style: TextStyle(
                color: isRefunded
                    ? Colors
                          .grey // 作廢變灰
                    : isPositive
                    ? Colors.green.shade700
                    : Colors.orange.shade800,
                fontWeight: FontWeight.bold,
                fontSize: 18,
                decoration: isRefunded ? TextDecoration.lineThrough : null,
              ),
            ),
            if (isRefunded) ...[
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  '已作廢',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // 輔助小元件：顯示帶 icon 的資訊行
  Widget _buildInfoRow(IconData icon, String text, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color ?? Colors.grey.shade500),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: color ?? Colors.grey.shade600,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.receipt_long_outlined,
              size: 64,
              color: Colors.grey.shade300,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '目前沒有紀錄',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }
}
