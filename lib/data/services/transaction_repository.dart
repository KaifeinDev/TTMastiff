import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/transaction_model.dart';

class TransactionRepository {
  final SupabaseClient _client;

  TransactionRepository(this._client);

  // 查詢某個使用者的交易紀錄
  Future<List<TransactionModel>> fetchTransactions(String userId) async {
    final response = await _client
        .from('transactions')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false); // 最新在最上面

    return (response as List).map((e) => TransactionModel.fromJson(e)).toList();
  }

  // 系統退款專用 (不需要 PIN 碼)
  Future<void> processRefund({
    required String userId,
    required int amount,
    required String bookingId,
    // 新增詳細資訊參數
    required String courseName,
    required String sessionInfo,
    required String studentName,
    required String studentId,
  }) async {
    try {
      await _client.rpc(
        'process_refund',
        params: {
          'target_user_id': userId,
          'amount_to_refund': amount,
          'booking_uuid': bookingId,
          // 傳入新參數
          'course_name': courseName,
          'session_info': sessionInfo,
          'student_name': studentName,
          'student_id': studentId,
        },
      );
    } catch (e) {
      // 錯誤處理保持原樣，或視需求優化
      throw Exception('退款失敗: $e');
    }
  }

  /// 1. 查詢管理員交易列表 (含篩選與關聯資料)
  ///
  /// [startDate], [endDate]: 日期範圍
  /// [performedById]: 篩選特定經手人 (教練/櫃檯)
  /// [isReconciled]: 篩選對帳狀態 (true=已入庫, false=未入庫, null=全部)
  Future<List<TransactionModel>> fetchAdminTransactions({
    DateTime? startDate,
    DateTime? endDate,
    String? performedById,
    bool? isReconciled,
  }) async {
    // 構建查詢語法：
    // user:profiles!user_id(full_name)
    //   -> 透過 user_id 關聯 profiles 表，別名取為 user，只抓 full_name
    // operator:profiles!performed_by(full_name)
    //   -> 透過 performed_by 關聯 profiles 表，別名取為 operator，只抓 full_name
    // reconciler:profiles!reconciled_by(full_name)
    //   -> 透過 reconciled_by 關聯 profiles 表，別名取為 reconciler (選用，若想顯示誰對帳的)

    var query = _client.from('transactions').select('''
      *,
      user:profiles!user_id(full_name),
      operator:profiles!performed_by(full_name),
      reconciler:profiles!reconciled_by(full_name)
    ''');

    // --- 篩選條件 ---

    // 日期區間
    if (startDate != null) {
      query = query.gte('created_at', startDate.toUtc().toIso8601String());
    }
    if (endDate != null) {
      // 確保包含結束日期的最後一秒 (23:59:59)
      final endOfDay = DateTime(
        endDate.year,
        endDate.month,
        endDate.day,
        23,
        59,
        59,
        999,
      );
      query = query.lte('created_at', endOfDay.toUtc().toIso8601String());
    }

    // 經手人篩選
    if (performedById != null) {
      query = query.eq('performed_by', performedById);
    }

    // 對帳狀態篩選
    if (isReconciled != null) {
      query = query.eq('is_reconciled', isReconciled);
    }

    // 排序：最新的在最上面
    final List<dynamic> response = await query.order(
      'created_at',
      ascending: false,
    );

    // 轉換為 Model
    return response.map((e) => TransactionModel.fromJson(e)).toList();
  }

  /// 2. 執行批次對帳 (確認收款)
  /// 呼叫 SQL 函數 `reconcile_transactions`
  Future<void> reconcileTransactions(List<String> transactionIds) async {
    if (transactionIds.isEmpty) return;

    try {
      await _client.rpc(
        'reconcile_transactions',
        params: {'transaction_ids': transactionIds},
      );
    } on PostgrestException catch (e) {
      throw Exception('對帳失敗: ${e.message}');
    }
  }

  /// 3. 通用退款 (針對儲值錯誤或商品退款)
  /// 呼叫 SQL 函數 `refund_general_transaction`
  Future<void> refundGeneralTransaction({
    required String originalTransactionId,
    required String reason,
  }) async {
    try {
      await _client.rpc(
        'refund_general_transaction',
        params: {
          'original_txn_id': originalTransactionId,
          'refund_reason': reason,
        },
      );
    } on PostgrestException catch (e) {
      // 捕捉 SQL 中拋出的錯誤 (例如餘額不足)
      throw Exception('退款失敗: ${e.message}');
    }
  }
}
