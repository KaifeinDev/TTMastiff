import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/transaction_types.dart';

class CreditRepository {
  final SupabaseClient _client;

  CreditRepository(this._client);

  // 取得目前點數
  Future<int> getCurrentCredit(String userId) async {
    final response = await _client
        .from('profiles')
        .select('credits')
        .eq('id', userId)
        .single();

    return (response['credits'] as int?) ?? 0;
  }

  // 增加點數 (並回傳更新後的點數)
  Future<int> addCredit({
    required String userId,
    required int amount, // amount to add
    String? description,
  }) async {
    // 1. 先查舊的點數 (為了確保數據正確)
    final currentCredit = await getCurrentCredit(userId);

    // 2. 計算新點數
    final newCredit = currentCredit + amount;

    // 3. 更新資料庫
    await _client
        .from('profiles')
        .update({'credits': newCredit})
        .eq('id', userId);

    return newCredit;
  }

  // 報名課程扣款
  // [cost] 課程費用 (請傳入正整數，例如 300)
  // [bookingId] 關聯的預約 ID
  Future<int> payForBooking({
    required String userId,
    required int cost,
    required String bookingId,
    required String courseName, // 用於備註
  }) async {
    // 1. 檢查餘額是否足夠
    final currentCredit = await getCurrentCredit(userId);

    if (currentCredit < cost) {
      throw Exception('點數不足，無法報名 (目前: $currentCredit, 需要: $cost)');
    }

    final newCredit = currentCredit - cost;

    // 2. 更新 Profile (扣款)
    await _client
        .from('profiles')
        .update({'credits': newCredit})
        .eq('id', userId);

    // 3. 寫入 Transaction (扣款紀錄)
    // 注意：amount 存入負數，代表支出
    await _client.from('transactions').insert({
      'user_id': userId,
      'type': TransactionTypes.payment, // 使用常數
      'amount': -cost, // 轉為負數
      'description': '報名課程: $courseName',
      'related_booking_id': bookingId, // 重要！連結 Booking
      'created_at': DateTime.now().toIso8601String(),
    });

    return newCredit;
  }
}
