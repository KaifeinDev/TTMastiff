import '../../../core/constants/membership_levels.dart';

/// 會員等級文字工具：只回傳中文名稱，不包含圖示或顏色
String getLevelText(String? level) {
  switch (level) {
    case MembershipLevels.beginner:
      return '初級';
    case MembershipLevels.intermediate:
      return '中級';
    case MembershipLevels.advanced:
      return '高級';
    default:
      return '初級';
  }
}

/// 根據會員等級計算折扣後的價格
int getDiscountedPrice(int price, String? level) {
  switch (level) {
    case MembershipLevels.intermediate:
      return (price * 0.9).round(); // 9 折
    case MembershipLevels.advanced:
      return (price * 0.8).round(); // 8 折
    default:
      return price; // beginner 或未知 -> 原價
  }
}

/// 根據會員等級回傳折扣標籤（例如「9折」、「8折」），沒有折扣則回傳 null
String? getDiscountLabel(String? level) {
  switch (level) {
    case MembershipLevels.intermediate:
      return '9折';
    case MembershipLevels.advanced:
      return '8折';
    default:
      return null;
  }
}
