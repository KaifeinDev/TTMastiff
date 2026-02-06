// lib/core/utils/time_extensions.dart
import 'package:intl/intl.dart'; // 記得 import intl
import 'package:ttmastiff/core/utils/util.dart';

extension PostgresTimeParsing on String {
  /// 將 PostgreSQL 的 TIME 格式 (e.g. "10:00:00")
  /// 轉換為今天的 DateTime (e.g. 2023-10-25 10:00:00)
  DateTime toDateTimeFromTime() {
    try {
      final now = DateTime.now();
      // 拆解字串 "10:00:00" -> ["10", "00", "00"]
      final parts = split(':');
      if (parts.length < 2) {
        throw FormatException("Invalid time format: $this");
      }

      final hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);
      final second = parts.length > 2 ? int.parse(parts[2]) : 0;

      return DateTime(now.year, now.month, now.day, hour, minute, second);
    } catch (e) {
      // 萬一解析失敗，回傳現在時間或是拋出錯誤，看您的需求
      logError(e);
      return DateTime.now();
    }
  }
}

extension DateTimeToPostgres on DateTime {
  /// 將 DateTime 轉換為 PostgreSQL 的 TIME 格式字串 (e.g. "15:30:00")
  /// 用於寫入資料庫的 default_start_time / default_end_time
  String toPostgresTimeString() {
    // 使用 intl 套件格式化，確保補零 (例如 09:05:00)
    return DateFormat('HH:mm:ss').format(this);
  }
}
