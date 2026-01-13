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
  
}
