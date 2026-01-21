import 'package:flutter/material.dart';
import 'package:ttmastiff/data/models/payroll_model.dart';

class PayrollEditDialog extends StatefulWidget {
  final String staffName;
  final PayrollModel payroll;
  final Function(PayrollModel) onConfirm;

  const PayrollEditDialog({
    super.key,
    required this.staffName,
    required this.payroll,
    required this.onConfirm,
  });

  @override
  State<PayrollEditDialog> createState() => _PayrollEditDialogState();
}

class _PayrollEditDialogState extends State<PayrollEditDialog> {
  late TextEditingController _bonusCtrl;
  late TextEditingController _deductionCtrl;
  late TextEditingController _noteCtrl;

  @override
  void initState() {
    super.initState();
    _bonusCtrl = TextEditingController(text: widget.payroll.bonus.toString());
    _deductionCtrl = TextEditingController(text: widget.payroll.deduction.toString());
    _noteCtrl = TextEditingController(text: widget.payroll.note ?? '');
  }

  int get _baseAmount => (
    (widget.payroll.totalCoachHours * widget.payroll.coachHourlyRate) +
    (widget.payroll.totalDeskHours * widget.payroll.deskHourlyRate)
  ).round();

  int get _finalTotal {
    int bonus = int.tryParse(_bonusCtrl.text) ?? 0;
    int deduction = int.tryParse(_deductionCtrl.text) ?? 0;
    return _baseAmount + bonus - deduction;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('${widget.staffName} 薪資結算'),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('基本薪資: \$$_baseAmount'),
            const SizedBox(height: 16),
            TextField(
              controller: _bonusCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: '獎金 (+)'),
              onChanged: (_) => setState((){}),
            ),
            TextField(
              controller: _deductionCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: '扣款 (-)'),
              onChanged: (_) => setState((){}),
            ),
            TextField(
              controller: _noteCtrl,
              decoration: const InputDecoration(labelText: '備註'),
            ),
            const SizedBox(height: 16),
            Text(
              '實發總額: \$$_finalTotal',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blue),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
        ElevatedButton(
          onPressed: () {
            // 建立新的 Payroll 物件 (包含修改後的金額)
            final newPayroll = PayrollModel(
              id: widget.payroll.id, // 若為空字串，Repository 會視為新增
              staffId: widget.payroll.staffId,
              year: widget.payroll.year,
              month: widget.payroll.month,
              totalCoachHours: widget.payroll.totalCoachHours,
              coachHourlyRate: widget.payroll.coachHourlyRate,
              totalDeskHours: widget.payroll.totalDeskHours,
              deskHourlyRate: widget.payroll.deskHourlyRate,
              bonus: int.tryParse(_bonusCtrl.text) ?? 0,
              deduction: int.tryParse(_deductionCtrl.text) ?? 0,
              note: _noteCtrl.text,
              totalAmount: _finalTotal,
              status: widget.payroll.id.isEmpty ? 'pending' : widget.payroll.status,
            );
            widget.onConfirm(newPayroll);
            Navigator.pop(context);
          },
          child: const Text('確認儲存'),
        ),
      ],
    );
  }
}