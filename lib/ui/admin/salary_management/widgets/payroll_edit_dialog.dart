import 'package:flutter/material.dart';
import 'package:ttmastiff/data/models/payroll_model.dart';

class PayrollEditDialog extends StatefulWidget {
  final String staffName;
  final PayrollModel payroll;
  final int baseCoachRate;
  final Function(PayrollModel) onConfirm;

  const PayrollEditDialog({
    super.key,
    required this.staffName,
    required this.payroll,
    required this.baseCoachRate,
    required this.onConfirm,
  });

  @override
  State<PayrollEditDialog> createState() => _PayrollEditDialogState();
}

class _PayrollEditDialogState extends State<PayrollEditDialog> {
  // 控制器
  late TextEditingController _bonusCtrl;
  late TextEditingController _deductionCtrl;
  late TextEditingController _noteCtrl;

  // 補正時數 (用於調整門檻)
  late double _adjustmentHours;

  // 結算狀態
  late String _status;

  @override
  void initState() {
    super.initState();
    _bonusCtrl = TextEditingController(text: widget.payroll.bonus.toString());
    _deductionCtrl = TextEditingController(
      text: widget.payroll.deduction.toString(),
    );
    _noteCtrl = TextEditingController(text: widget.payroll.note ?? '');

    // 初始化補正時數
    _adjustmentHours = widget.payroll.adjustmentHours ?? 0.0;

    // 初始化狀態
    if (widget.payroll.status == 'unsettled' || widget.payroll.id.isEmpty) {
      _status = 'calculated';
    } else {
      _status = widget.payroll.status;
    }
  }

  // 🔥 [核心修正] 依照你的新邏輯計算
  // 🔥 核心計算邏輯：底薪 + 門檻增量
  Map<String, dynamic> _calculate() {
    final double coachHours = widget.payroll.totalCoachHours;
    final double deskHours = widget.payroll.totalDeskHours;

    // 1. 計算門檻總時數 (教課 + 櫃檯 + 手動補正)
    final double threshold = coachHours + deskHours + _adjustmentHours;

    // 2. 決定教課時薪 (相對增量邏輯)
    // Level 1: < 120hr -> 領底薪
    // Level 2: > 120hr -> 底薪 + 50
    // Level 3: > 135hr -> 底薪 + 100
    int calculatedRate = widget.baseCoachRate; // 從 widget 取得該員工底薪

    if (threshold > 135) {
      calculatedRate = widget.baseCoachRate + 100;
    } else if (threshold > 120) {
      calculatedRate = widget.baseCoachRate + 50;
    }

    // 計算各項薪資
    // 注意：補正時數(_adjustmentHours) 僅用於「堆高門檻」，
    // 實際計算薪水時，通常還是乘上「實際教課時數」(coachHours)。
    final double coachPay = coachHours * calculatedRate;
    final double deskPay = deskHours * widget.payroll.deskHourlyRate;

    final int bonus = int.tryParse(_bonusCtrl.text) ?? 0;
    final int deduction = int.tryParse(_deductionCtrl.text) ?? 0;

    // 4. 總金額
    final double total = coachPay + deskPay + bonus - deduction;

    return {
      'threshold': threshold, // 回傳門檻 (給 UI 顯示用)
      'rate': calculatedRate, // 回傳計算後的時薪
      'coachPay': coachPay, // 教課薪資總額
      'deskPay': deskPay, // 櫃檯薪資總額
      'total': total.round(), // 實發總額 (取整數)
    };
  }

  @override
  Widget build(BuildContext context) {
    final calc = _calculate();

    return AlertDialog(
      title: Text('結算：${widget.staffName}'),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // --- 區塊 1: 門檻與費率 ---
            _buildSectionHeader('費率判定 (門檻 = 教課+櫃檯+補正)'),
            _buildInfoRow('原始教課', '${widget.payroll.totalCoachHours} hr'),
            _buildInfoRow('原始櫃檯', '${widget.payroll.totalDeskHours} hr'),

            const SizedBox(height: 8),
            // 時數補正輸入框
            TextFormField(
              initialValue: _adjustmentHours == 0
                  ? ''
                  : _adjustmentHours.toString(),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
                signed: true,
              ),
              decoration: const InputDecoration(
                labelText: '門檻補正時數',
                hintText: '用於調整費率門檻',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.exposure, size: 20),
                isDense: true,
                contentPadding: EdgeInsets.all(12),
              ),
              onChanged: (val) {
                setState(() {
                  _adjustmentHours = double.tryParse(val) ?? 0.0;
                });
              },
            ),

            const SizedBox(height: 8),
            // 計算結果預覽
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  _buildResultRow(
                    '目前門檻時數',
                    '${(calc['threshold'] as double).toStringAsFixed(1)} hr',
                  ),
                  const Divider(height: 12),
                  _buildResultRow(
                    '教課時薪',
                    '\$${calc['rate']}/hr',
                    isHighlight: true,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // --- 區塊 2: 薪資試算 ---
            _buildSectionHeader('薪資試算'),
            // 顯示算式細節：教課薪資 + 櫃檯薪資
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Text(
                '• 教課: ${widget.payroll.totalCoachHours}hr x \$${calc['rate']} = \$${(calc['coachPay'] as double).toStringAsFixed(0)}\n'
                '• 櫃檯: ${widget.payroll.totalDeskHours}hr x \$${widget.payroll.deskHourlyRate} = \$${(calc['deskPay'] as double).toStringAsFixed(0)}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[700],
                  height: 1.5,
                ),
              ),
            ),

            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _bonusCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: '獎金補整 (+)',
                      isDense: true,
                      prefixText: '\$',
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _deductionCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: '扣款 (-)',
                      isDense: true,
                      prefixText: '\$',
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _noteCtrl,
              decoration: const InputDecoration(labelText: '備註', isDense: true),
            ),

            const SizedBox(height: 24),

            // --- 區塊 3: 總結 ---
            const Divider(thickness: 1.5),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '實發總額',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Text(
                  '\$${calc['total']}',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),
            // 狀態選擇
            DropdownButtonFormField<String>(
              value: _status,
              decoration: const InputDecoration(
                labelText: '結算狀態',
                isDense: true,
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'unsettled', child: Text('未結算')),
                DropdownMenuItem(value: 'calculated', child: Text('待發放')),
                DropdownMenuItem(value: 'paid', child: Text('已發放')),
              ],
              onChanged: (val) => setState(() => _status = val!),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
          ),
          onPressed: () {
            final calc = _calculate();

            final newPayroll = PayrollModel(
              id: widget.payroll.id,
              staffId: widget.payroll.staffId,
              year: widget.payroll.year,
              month: widget.payroll.month,

              // 這些基礎數據不變
              totalCoachHours: widget.payroll.totalCoachHours,
              totalDeskHours: widget.payroll.totalDeskHours,
              deskHourlyRate: widget.payroll.deskHourlyRate,

              // 🔥 儲存計算結果
              adjustmentHours: _adjustmentHours, // 儲存門檻補正時數
              coachHourlyRate: calc['rate'], // 儲存最後決定的時薪
              totalAmount: calc['total'], // 儲存總金額
              status: _status,

              bonus: int.tryParse(_bonusCtrl.text) ?? 0,
              deduction: int.tryParse(_deductionCtrl.text) ?? 0,
              note: _noteCtrl.text,
            );

            widget.onConfirm(newPayroll);
            Navigator.pop(context);
          },
          child: const Text('確認儲存'),
        ),
      ],
    );
  }

  // --- 輔助 Widget 方法 ---

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.grey[600],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.black87)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _buildResultRow(
    String label,
    String value, {
    bool isHighlight = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: isHighlight ? Colors.blue[800] : Colors.black87,
            fontWeight: isHighlight ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: isHighlight ? Colors.blue[800] : Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
