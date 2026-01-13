import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ttmastiff/data/models/session_model.dart';
import '../models/transaction_model.dart';
import 'package:intl/intl.dart';

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
}
