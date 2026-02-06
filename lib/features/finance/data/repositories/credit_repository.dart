import 'package:supabase_flutter/supabase_flutter.dart';

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
    required String pin,
  }) async {
    try {
      // 呼叫我們剛剛在 Supabase 建立的 'add_credits' 函數
      final response = await _client.rpc(
        'add_credits',
        params: {
          'target_user_id': userId,
          'amount_to_add': amount,
          'description_text': description ?? '系統儲值',
          'input_pin': pin,
        },
      );

      // response 直接就是最新的餘額 (int)
      return response as int;
    } on PostgrestException catch (e) {
      // PIN 碼錯了
      if (e.message.contains('PIN')) {
        throw Exception('PIN 碼錯誤，請重新輸入');
      }

      // 如果不是管理員，SQL 會拋出錯誤，這裡可以捕獲
      if (e.message.contains('Access Denied')) {
        throw Exception('權限不足：您不是管理員，無法執行儲值。');
      }
      rethrow;
    }
  }

  // 報名課程扣款
  // [cost] 課程費用 (請傳入正整數，例如 300)
  // [bookingId] 關聯的預約 ID
  Future<int> payForBooking({
    required String userId,
    required int cost,
    required String bookingId,
    required String courseName,
    required String sessionInfo,
    required String studentName,
    required String studentId,
  }) async {
    try {
      // 呼叫 Supabase RPC
      final response = await _client.rpc(
        'pay_for_booking',
        params: {
          'target_user_id': userId,
          'cost_amount': cost,
          'booking_uuid': bookingId,
          'course_name': courseName,
          'session_info': sessionInfo,
          'student_name': studentName,
          'student_id': studentId,
        },
      );

      // 回傳最新餘額
      return response as int;
    } on PostgrestException catch (e) {
      // 處理 SQL 拋出的錯誤
      if (e.message.contains('Insufficient Funds')) {
        // 可以解析錯誤訊息，或是直接拋出更友善的中文
        throw Exception('餘額不足，請先儲值。');
      }
      if (e.message.contains('Access Denied')) {
        throw Exception('權限不足，無法執行扣款。');
      }
      // 其他錯誤
      rethrow;
    }
  }

  Future<void> processRefund({
    required String userId, // 對應 target_user_id
    required int amount, // 對應 amount_to_refund
    required String bookingId, // 對應 booking_uuid
    required String courseName, // 對應 course_name
    required String sessionInfo, // 對應 session_info
    required String studentName, // 對應 student_name
    required String studentId, // 對應 student_id
    String reason = '預約取消',
  }) async {
    try {
      await _client.rpc(
        'process_refund', // 呼叫資料庫中的函數名稱
        params: {
          'target_user_id': userId,
          'amount_to_refund': amount,
          'booking_uuid': bookingId,
          'course_name': courseName,
          'session_info': sessionInfo,
          'student_name': studentName,
          'student_id': studentId,
          'refund_reason': reason,
        },
      );
    } on PostgrestException catch (e) {
      // 捕捉 SQL 拋出的錯誤
      throw Exception('退款執行失敗: ${e.message}');
    } catch (e) {
      throw Exception('未預期的錯誤: $e');
    }
  }
}
