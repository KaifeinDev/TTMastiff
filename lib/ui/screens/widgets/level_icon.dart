/// 會員等級文字工具：只回傳中文名稱，不包含圖示或顏色
String getLevelText(String? level) {
  switch (level) {
    case 'beginner':
      return '初級';
    case 'intermediate':
      return '中級';
    case 'advanced':
      return '高級';
    default:
      return '初級';
  }
}
