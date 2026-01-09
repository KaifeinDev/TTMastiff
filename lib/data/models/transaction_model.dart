class TransactionModel {
  final String id;
  final DateTime createdAt;
  final String userId;
  final String type; // 'topup', 'payment', etc. see '/core/constants/transaction_type.dart'
  final int amount;
  final String? description;
  final String? relatedBookingId;

  TransactionModel({
    required this.id,
    required this.createdAt,
    required this.userId,
    required this.type,
    required this.amount,
    this.description,
    this.relatedBookingId,
  });

  // 從 Supabase JSON 轉為 Dart 物件
  factory TransactionModel.fromJson(Map<String, dynamic> json) {
    return TransactionModel(
      id: json['id'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      userId: json['user_id'] as String,
      type: json['type'] as String,
      amount: json['amount'] as int,
      description: json['description'] as String?,
      relatedBookingId: json['related_booking_id'] as String?,
    );
  }

  // 從 Dart 物件轉為 JSON (用於寫入資料庫)
  Map<String, dynamic> toJson() {
    return {
      // id 通常由資料庫自動產生，寫入時可以不傳
      'user_id': userId,
      'type': type,
      'amount': amount,
      'description': description,
      'related_booking_id': relatedBookingId,
      // created_at 通常由資料庫自動產生
    };
  }
}
