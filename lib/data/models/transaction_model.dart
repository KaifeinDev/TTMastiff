class TransactionModel {
  // --- 資料庫實體欄位 (對應 transactions 表) ---
  final String id;
  final DateTime createdAt;
  final String userId;
  final String type; // 'topup', 'payment', 'refund_general', etc.
  final int amount;
  final String? description;
  final String? relatedBookingId;
  final String? performedBy; // 經手人 ID
  final Map<String, dynamic> metadata;

  // 對帳相關
  final bool isReconciled;
  final DateTime? reconciledAt;
  final String? reconciledBy; // 對帳人 ID

  // 退款關聯
  final String? originalTransactionId;

  // --- 擴充顯示欄位 (透過 Join 查詢取得，不寫入 DB) ---
  // 注意：根據你的 ER 圖，profiles 表的欄位是 'full_name'
  final String? userFullName; // 客戶姓名 (user_id -> profiles.full_name)
  final String? operatorFullName; // 經手人姓名 (performed_by -> profiles.full_name)
  final String?
  reconcilerFullName; // 對帳人姓名 (reconciled_by -> profiles.full_name)
  final String status;

  TransactionModel({
    required this.id,
    required this.createdAt,
    required this.userId,
    required this.type,
    required this.amount,
    this.description,
    this.relatedBookingId,
    this.performedBy,
    this.metadata = const {},
    this.isReconciled = false,
    this.reconciledAt,
    this.reconciledBy,
    this.originalTransactionId,
    this.userFullName,
    this.operatorFullName,
    this.reconcilerFullName,
    required this.status
  });

  /// 從 Supabase JSON 轉為 Dart 物件
  /// 支援關聯查詢的巢狀結構
  factory TransactionModel.fromJson(Map<String, dynamic> json) {
    // 輔助函式：從巢狀 JSON 提取 full_name
    // 例如查詢語法：select('*, user:profiles!user_id(full_name)')
    String? extractName(dynamic data) {
      if (data != null && data is Map) {
        return data['full_name'] as String?; // 🔥 修正：對應 ER 圖的 full_name
      }
      return null;
    }

    return TransactionModel(
      // 基本欄位
      id: json['id'] as String,
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
      userId: json['user_id'] as String,
      type: json['type'] as String,
      amount: json['amount'] as int,
      description: json['description'] as String?,

      // 外鍵與關聯
      relatedBookingId: json['related_booking_id'] as String?,
      performedBy: json['performed_by'] as String?,
      originalTransactionId: json['original_transaction_id'] as String?,

      // JSONB
      metadata: json['metadata'] != null
          ? Map<String, dynamic>.from(json['metadata'])
          : {},

      // 對帳欄位 (處理 null 安全)
      isReconciled: json['is_reconciled'] ?? false,
      reconciledAt: json['reconciled_at'] != null
          ? DateTime.parse(json['reconciled_at']).toLocal()
          : null,
      reconciledBy: json['reconciled_by'] as String?,

      // 🔥 處理關聯資料 (對應 Repository 的 select 語法)
      // 假設 Repository 使用 alias: user, operator, reconciler
      userFullName: extractName(json['user']),
      operatorFullName: extractName(json['operator']),
      reconcilerFullName: extractName(json['reconciler']),
      status: json['status'] ?? 'valid',
    );
  }

  /// 轉為 JSON (用於寫入資料庫)
  /// 注意：不包含 userFullName 等顯示用欄位
  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'type': type,
      'amount': amount,
      'description': description,
      'related_booking_id': relatedBookingId,
      'performed_by': performedBy,
      'metadata': metadata,
      'is_reconciled': isReconciled,
      'reconciled_at': reconciledAt?.toIso8601String(),
      'reconciled_by': reconciledBy,
      'original_transaction_id': originalTransactionId,
      'status': status,
    };
  }

  // --- Helper Getters (從 metadata 快速取值) ---

  // 為了相容性，如果 metadata 沒資料，嘗試回傳 userFullName
  String get displayStudentName =>
      metadata['student_name'] ?? userFullName ?? '未知用戶';

  String? get sessionInfo => metadata['session_info'];
  String? get courseName => metadata['course_name'];

  // 判斷是否為負向交易 (支出/扣款)
  bool get isExpense => amount < 0;

  // 判斷是否為收入
  bool get isIncome => amount > 0;
}
