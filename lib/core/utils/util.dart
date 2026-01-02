import 'package:intl/intl.dart';

extension DateTimeExt on DateTime {
  // 計算年齡的邏輯
  int get age {
    final now = DateTime.now();
    int age = now.year - year;
    // 如果還沒過生日，歲數減 1
    if (now.month < month || (now.month == month && now.day < day)) {
      age--;
    }
    return age;
  }
  
  // 取得格式化字串
  String toDateWithAge() {
    final dateStr = DateFormat('yyyy/MM/dd').format(this);
    return '$dateStr ($age歲)';
  }
}
