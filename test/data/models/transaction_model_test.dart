import 'package:flutter_test/flutter_test.dart';
import 'package:ttmastiff/data/models/transaction_model.dart';

void main() {
  group('TransactionModel.fromJson', () {
    test('扁平列與巢狀 profiles 別名時正確對應', () {
      final json = <String, dynamic>{
        'id': 'tx-1',
        'created_at': '2026-04-01T06:30:00.000Z',
        'user_id': 'u-1',
        'type': 'topup',
        'amount': 500,
        'description': '儲值',
        'related_booking_id': null,
        'performed_by': 'p-1',
        'metadata': <String, dynamic>{'student_name': '元資料生'},
        'payment_method': 'cash',
        'is_reconciled': true,
        'reconciled_at': '2026-04-02T01:00:00.000Z',
        'reconciled_by': 'admin-1',
        'status': 'valid',
        'updated_at': '2026-04-02T02:00:00.000Z',
        'user': {'full_name': '家長張'},
        'operator': {'full_name': '櫃台李'},
        'reconciler': {'full_name': '對帳王'},
      };

      final m = TransactionModel.fromJson(json);

      expect(m.id, 'tx-1');
      expect(m.userId, 'u-1');
      expect(m.type, 'topup');
      expect(m.amount, 500);
      expect(m.description, '儲值');
      expect(m.paymentMethod, 'cash');
      expect(m.isReconciled, true);
      expect(m.status, 'valid');
      expect(m.userFullName, '家長張');
      expect(m.operatorFullName, '櫃台李');
      expect(m.reconcilerFullName, '對帳王');
      expect(m.metadata['student_name'], '元資料生');
    });

    test('缺省欄位時 payment_method、status、metadata 的預設', () {
      final json = <String, dynamic>{
        'id': 'tx-2',
        'created_at': '2026-01-01T00:00:00.000Z',
        'user_id': 'u-2',
        'type': 'payment',
        'amount': -100,
      };

      final m = TransactionModel.fromJson(json);

      expect(m.paymentMethod, 'credit');
      expect(m.status, 'valid');
      expect(m.metadata, isEmpty);
      expect(m.isExpense, true);
      expect(m.isIncome, false);
    });

    test('displayStudentName 優先 metadata，其次 userFullName', () {
      final withMeta = TransactionModel.fromJson({
        'id': 'a',
        'created_at': '2026-01-01T00:00:00.000Z',
        'user_id': 'u',
        'type': 'topup',
        'amount': 1,
        'metadata': {'student_name': '學生A'},
        'payment_method': 'credit',
        'status': 'valid',
        'user': {'full_name': '家長B'},
      });
      expect(withMeta.displayStudentName, '學生A');

      final noMeta = TransactionModel.fromJson({
        'id': 'b',
        'created_at': '2026-01-01T00:00:00.000Z',
        'user_id': 'u',
        'type': 'topup',
        'amount': 1,
        'metadata': {},
        'payment_method': 'credit',
        'status': 'valid',
        'user': {'full_name': '家長C'},
      });
      expect(noMeta.displayStudentName, '家長C');
    });

    test('courseName 與 sessionInfo 從 metadata 讀取', () {
      final m = TransactionModel.fromJson({
        'id': 'c',
        'created_at': '2026-01-01T00:00:00.000Z',
        'user_id': 'u',
        'type': 'refund_general',
        'amount': -50,
        'metadata': {
          'course_name': '瑜珈',
          'session_info': '06/01 09:00',
        },
        'payment_method': 'credit',
        'status': 'valid',
      });
      expect(m.courseName, '瑜珈');
      expect(m.sessionInfo, '06/01 09:00');
    });
  });
}
