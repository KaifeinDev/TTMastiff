import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/transaction_model.dart';

class TransactionRepository {
  final SupabaseClient _client;

  TransactionRepository(this._client);

  // 新增一筆交易紀錄
  Future<void> createTransaction({
    required String userId,
    required String type,
    required int amount,
    String? description,
    String? relatedBookingId,
  }) async {
    await _client.from('transactions').insert({
      'user_id': userId,
      'type': type,
      'amount': amount,
      'description': description,
      'related_booking_id': relatedBookingId,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  // (選用) 查詢某個使用者的交易紀錄
  Future<List<TransactionModel>> getTransactions(String userId) async {
    final response = await _client
        .from('transactions')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false); // 最新在最上面

    return (response as List)
        .map((e) => TransactionModel.fromJson(e))
        .toList();
  }
}