import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

// ==========================================
// 🛠️ Error Handling & Logging (錯誤處理與記錄)
// ==========================================

/// 純粹記錄錯誤 (不顯示 UI)
/// 適用於 Repository 或背景執行時
void logError(dynamic error, [StackTrace? stackTrace]) {
  debugPrint('🔴 [發生錯誤]: $error');
  if (stackTrace != null) {
    debugPrint('📜 [錯誤堆疊]: $stackTrace');
  }
}

// ==========================================
// 🛠️ UI Helper Functions (通用 UI 工具)
// ==========================================

/// 顯示標準錯誤彈窗
/// 自動去除 "Exception:" 前綴，並以紅字標題顯示
/// context: UI 上下文
/// error: 錯誤物件
/// stackTrace: (選填) 錯誤堆疊，建議傳入以利除錯
void showErrorDialog(
  BuildContext context,
  dynamic error, {
  StackTrace? stackTrace,
  String title = '發生錯誤',
}) {
  // 1. 先在 Console 印出錯誤 (給開發者看)
  logError(error, stackTrace);

  // 2. 處理文字 (給使用者看)
  final message = formatErrorMessage(error);

  // 3. 顯示彈窗
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red),
          SizedBox(width: 8),
          Text(title, style: TextStyle(color: Colors.red)),
        ],
      ),
      content: Text(message, style: const TextStyle(fontSize: 16)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('確定'),
        ),
      ],
    ),
  );
}

/// 格式化錯誤訊息字串
/// 移除 "Exception: " 以及可能的雜訊
String formatErrorMessage(dynamic error) {
  String message = error.toString();

  // 移除常見的 Exception 前綴
  if (message.startsWith('Exception: ')) {
    message = message.replaceAll('Exception: ', '');
  }

  // 你也可以在這裡加入針對 Supabase PostgrestException 的處理
  // if (message.contains('PostgrestException')) { ... }

  return message;
}

// ==========================================
// 🧩 Extensions (擴充功能)
// ==========================================

extension DateTimeExt on DateTime {
  /// 計算年齡
  int get age {
    final now = DateTime.now();
    int age = now.year - year;
    // 如果還沒過生日，歲數減 1
    if (now.month < month || (now.month == month && now.day < day)) {
      age--;
    }
    return age;
  }

  /// 取得格式化字串 (包含年齡)
  /// e.g. "2023/10/25 (10歲)"
  String toDateWithAge() {
    final dateStr = DateFormat('yyyy/MM/dd').format(this);
    return '$dateStr ($age歲)';
  }
}
