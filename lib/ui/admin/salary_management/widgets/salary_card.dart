import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class SalaryCard extends StatelessWidget {
  final String name;
  final int baseCoachRate;
  final double coachHours;
  final double deskHours;
  final double adjustmentHours;
  final int totalAmount;
  final String status;
  final VoidCallback onAction;

  const SalaryCard({
    super.key,
    required this.name,
    required this.baseCoachRate,
    required this.coachHours,
    required this.deskHours,
    required this.adjustmentHours,
    required this.totalAmount,
    required this.status,
    required this.onAction,
  });

  final double _maxScaleHours = 150.0;
  static final NumberFormat _fmt = NumberFormat.decimalPattern();

  double get thresholdHours => coachHours + deskHours + adjustmentHours;

  int get currentRate {
    if (thresholdHours > 135) return baseCoachRate + 100;
    if (thresholdHours > 120) return baseCoachRate + 50;
    return baseCoachRate;
  }

  double get progressRatio {
    double ratio = thresholdHours / _maxScaleHours;
    return ratio > 1.0 ? 1.0 : ratio;
  }

  String get nextGoalText {
    if (thresholdHours < 120) {
      return '差 ${(120 - thresholdHours).toStringAsFixed(1)} hr 升級';
    }
    if (thresholdHours < 135) {
      return '差 ${(135 - thresholdHours).toStringAsFixed(1)} hr 升級';
    }
    return '已達最高階';
  }

  @override
  Widget build(BuildContext context) {
    final isUnsettled = status == 'unsettled';

    // 定義狀態顏色
    Color statusColor;
    String statusText;
    switch (status) {
      case 'paid':
        statusColor = Colors.green;
        statusText = '已發放';
        break;
      case 'calculated':
        statusColor = Colors.orange;
        statusText = '已結算';
        break;
      default:
        statusColor = Colors.grey;
        statusText = '未結算';
    }

    return Card(
      elevation: 3,
      margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // ------------------------------------------------
            // 1. Header: 姓名 + 狀態 Badge
            // ------------------------------------------------
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                // 純顯示用的 Badge (平面風格)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // ------------------------------------------------
            // 2. Dashboard 數據區
            // ------------------------------------------------
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // 左側：目前時薪
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '目前時薪',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '\$${_fmt.format(currentRate)}',
                            style: const TextStyle(
                              fontSize: 30, // 字體加大
                              fontWeight: FontWeight.w800,
                              color: Colors.blueAccent,
                              height: 1.0,
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.only(bottom: 5, left: 4),
                            child: Text(
                              '/hr',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // 右側：預估總額
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '本月預估',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '\$${_fmt.format(totalAmount)}',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.blueGrey[800],
                        height: 1.0,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 24),

            // ------------------------------------------------
            // 3. 進度條區 (視覺優化版)
            // ------------------------------------------------
            // 使用 Center + FractionallySizedBox 限制寬度，避免網頁版太寬
            Center(
              child: FractionallySizedBox(
                widthFactor: 0.95, // 限制寬度為卡片的 95%
                child: Column(
                  children: [
                    // 提示文字 (靠右)
                    Align(
                      alignment: Alignment.centerRight,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text(
                          nextGoalText,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.orange[800],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),

                    // 進度條本體
                    _buildCustomProgressBar(),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),
            const Divider(height: 1, color: Colors.black12),
            const SizedBox(height: 16),

            // ------------------------------------------------
            // 4. 底部區域：左側時數堆疊 + 右側實體按鈕
            // ------------------------------------------------
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // 左下角：緊湊的時數資訊 (靠左堆疊)
                Row(
                  mainAxisSize: MainAxisSize.min, // 緊縮
                  children: [
                    _buildCompactStat('教課', coachHours),
                    const SizedBox(width: 16),
                    _buildCompactStat('櫃檯', deskHours),
                    if (adjustmentHours != 0) ...[
                      const SizedBox(width: 16),
                      _buildCompactStat(
                        '補正',
                        adjustmentHours,
                        isHighlight: true,
                      ),
                    ],
                  ],
                ),

                // 右下角：明顯的操作按鈕
                ElevatedButton.icon(
                  onPressed: onAction,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isUnsettled ? Colors.blue : Colors.orange,
                    foregroundColor: Colors.white,
                    elevation: 2, // 增加陰影，讓它看起來是浮起來的按鈕
                    shadowColor: (isUnsettled ? Colors.blue : Colors.orange)
                        .withOpacity(0.4),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: Icon(
                    isUnsettled ? Icons.calculate : Icons.edit_note,
                    size: 18,
                  ),
                  label: Text(
                    isUnsettled ? '結算' : '修改',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // 客製化進度條
  Widget _buildCustomProgressBar() {
    return SizedBox(
      height: 10,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final double maxWidth = constraints.maxWidth;
          final double pos120 = (120 / _maxScaleHours) * maxWidth;
          final double pos135 = (135 / _maxScaleHours) * maxWidth;

          return Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.centerLeft,
            children: [
              // 1. 底色軌道 (加深顏色，讓未達成部分更明顯)
              Container(
                width: double.infinity,
                height: 8,
                decoration: BoxDecoration(
                  color: Colors.grey[300], // 🔥 加深灰色
                  borderRadius: BorderRadius.circular(4),
                ),
              ),

              // 2. 實際進度 (漸層色)
              Container(
                width: maxWidth * progressRatio,
                height: 8,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: thresholdHours >= 135
                        ? [Colors.blueAccent, Colors.purpleAccent]
                        : [Colors.blue.shade400, Colors.blueAccent],
                  ),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),

              // 3. 刻度線 120
              Positioned(
                left: pos120,
                top: -1,
                child: _buildTick(isReached: thresholdHours >= 120),
              ),

              // 4. 刻度線 135
              Positioned(
                left: pos135,
                top: -1,
                child: _buildTick(isReached: thresholdHours >= 135),
              ),

              // 5. 刻度文字
              Positioned(
                left: pos120 - 10,
                top: 10,
                child: const Text(
                  '120',
                  style: TextStyle(
                    fontSize: 9,
                    color: Colors.grey,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Positioned(
                left: pos135 - 10,
                top: 10,
                child: const Text(
                  '135',
                  style: TextStyle(
                    fontSize: 9,
                    color: Colors.grey,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTick({required bool isReached}) {
    return Container(
      width: 2,
      height: 10,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(1),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 1)],
      ),
    );
  }

  // 極簡化的時數顯示 (無 Icon，純文字堆疊)
  Widget _buildCompactStat(
    String label,
    double value, {
    bool isHighlight = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: isHighlight ? Colors.orange[800] : Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          value == 0 ? '-' : value.toStringAsFixed(1),
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: isHighlight ? Colors.orange : Colors.black87,
          ),
        ),
      ],
    );
  }
}
