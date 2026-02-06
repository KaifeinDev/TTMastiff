import 'package:flutter/material.dart';
import 'package:ttmastiff/core/utils/util.dart';
import 'package:intl/intl.dart';
import 'package:logger/logger.dart'; // 1. 引入 logger 套件

// ==========================================
// 🛠️ Logger Configuration (設定 Logger)
// ==========================================

// 2. 初始化全域 Logger 實例 (取代原本單調的 debugPrint)
final logger = Logger(
  printer: PrettyPrinter(
    methodCount: 0, // 一般 Log 不顯示堆疊
    errorMethodCount: 8, // 錯誤時顯示 8 層堆疊
    lineLength: 120,
    colors: true,
    printEmojis: true,
  ),
);

// ==========================================
// 🛠️ Error Handling & Logging (錯誤處理與記錄)
// ==========================================

/// 純粹記錄錯誤 (不顯示 UI)
/// 升級版：使用 Logger 套件輸出漂亮的紅字錯誤與堆疊
void logError(dynamic error, [StackTrace? stackTrace]) {
  // 3. 改用 logger.e 來印出錯誤，它會自動處理 stackTrace 的排版
  logger.e('發生錯誤', error: error, stackTrace: stackTrace);
}

// 一般資訊記錄 (新增這個好用的 helper)
void logInfo(String message) {
  logger.i(message);
}

// ==========================================
// 🛠️ UI Helper Functions (通用 UI 工具)
// ==========================================

/// 顯示標準錯誤彈窗
void showErrorDialog(
  BuildContext context,
  dynamic error, {
  StackTrace? stackTrace,
  String title = '發生錯誤',
}) {
  // 1. 先在 Console 印出錯誤 (這行會呼叫上面的升級版 logError)
  logError(error, stackTrace);

  // 2. 處理文字 (保留你原本的邏輯)
  final message = formatErrorMessage(error);

  // 3. 安全檢查：確保 Context 還活著 (解決 async gaps warning)
  if (!context.mounted) return;

  // 4. 顯示彈窗 (保留原本 UI)
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.red),
          const SizedBox(width: 8),
          Text(title, style: const TextStyle(color: Colors.red)),
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
String formatErrorMessage(dynamic error) {
  String message = error.toString();

  if (message.startsWith('Exception: ')) {
    message = message.replaceAll('Exception: ', '');
  }

  // 小建議：可以針對常見錯誤做更友善的翻譯
  if (message.contains('SocketException')) {
    return '無法連線到伺服器，請檢查網路';
  }

  return message;
}

// ==========================================
// 🧩 Extensions (擴充功能 - 完全保留)
// ==========================================

extension DateTimeExt on DateTime {
  int get age {
    final now = DateTime.now();
    int age = now.year - year;
    if (now.month < month || (now.month == month && now.day < day)) {
      age--;
    }
    return age;
  }

  String toDateWithAge() {
    final dateStr = DateFormat('yyyy/MM/dd').format(this);
    return '$dateStr ($age歲)';
  }
}
