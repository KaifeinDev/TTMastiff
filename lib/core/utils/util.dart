import 'package:flutter/material.dart';
import 'package:gotrue/gotrue.dart' show AuthException;
import 'package:intl/intl.dart';
import 'package:postgrest/postgrest.dart' show PostgrestException;

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

/// 格式化錯誤訊息字串（給使用者看的簡潔說明）
/// 會處理 [PostgrestException]、[AuthException]，並移除一般 Exception 前綴雜訊。
String formatErrorMessage(dynamic error) {
  if (error is PostgrestException) {
    final buf = StringBuffer(error.message);
    if (error.hint != null && error.hint!.trim().isNotEmpty) {
      buf.write('\n');
      buf.write(error.hint);
    }
    return buf.toString();
  }
  if (error is AuthException) {
    return error.message;
  }

  String message = error.toString();

  if (message.startsWith('Exception: ')) {
    message = message.replaceAll('Exception: ', '');
  }

  return message;
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
  logError(error, stackTrace);

  final message = formatErrorMessage(error);

  showDialog<void>(
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

/// 以 SnackBar 顯示錯誤（適合非阻斷式操作：載入失敗、表單送出失敗等）
/// 會先 [logError]，再將 [formatErrorMessage] 後的文字顯示給使用者。
void showErrorSnackBar(
  BuildContext context,
  dynamic error, {
  String? prefix,
  Color? backgroundColor,
  Duration duration = const Duration(seconds: 4),
}) {
  logError(error);
  if (!context.mounted) return;
  final formatted = formatErrorMessage(error);
  final text = (prefix != null && prefix.isNotEmpty)
      ? '$prefix$formatted'
      : formatted;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(text),
      backgroundColor: backgroundColor ?? Colors.red.shade700,
      duration: duration,
    ),
  );
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
