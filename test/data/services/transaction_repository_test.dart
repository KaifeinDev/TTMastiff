import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ttmastiff/data/services/transaction_repository.dart';

class _MockHttpClient extends Mock implements http.Client {}

http.StreamedResponse _streamedJson(
  http.BaseRequest req,
  String body,
  int statusCode, {
  Map<String, String> headers = const {
    'content-type': 'application/json; charset=utf-8',
  },
}) {
  return http.StreamedResponse(
    Stream.value(utf8.encode(body)),
    statusCode,
    request: req,
    headers: headers,
  );
}

http.StreamedResponse _streamedEmpty(http.BaseRequest req, int statusCode) {
  return http.StreamedResponse(
    Stream<List<int>>.value(Uint8List(0)),
    statusCode,
    request: req,
  );
}

Map<String, dynamic> _transactionRow({
  String id = 'tx-1',
  String userId = 'user-a',
  String type = 'topup',
  int amount = 300,
  String createdAt = '2026-03-10T08:00:00.000Z',
  Map<String, dynamic>? user,
  Map<String, dynamic>? operator,
  Map<String, dynamic>? reconciler,
}) {
  return {
    'id': id,
    'created_at': createdAt,
    'user_id': userId,
    'type': type,
    'amount': amount,
    'description': null,
    'related_booking_id': null,
    'performed_by': 'op-1',
    'metadata': <String, dynamic>{},
    'payment_method': 'cash',
    'is_reconciled': false,
    'reconciled_at': null,
    'reconciled_by': null,
    'status': 'valid',
    'updated_at': null,
    if (user != null) 'user': user,
    if (operator != null) 'operator': operator,
    if (reconciler != null) 'reconciler': reconciler,
  };
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockHttpClient mockHttp;
  late SupabaseClient supabase;
  late TransactionRepository repo;

  setUpAll(() {
    registerFallbackValue(Uri());
    registerFallbackValue(http.Request('GET', Uri.parse('http://localhost/')));
  });

  setUp(() {
    mockHttp = _MockHttpClient();
    supabase = SupabaseClient(
      'http://localhost:54321',
      'test_anon_key',
      httpClient: mockHttp,
    );
    repo = TransactionRepository(supabase);
  });

  group('TransactionRepository（HTTP 由 mocktail 隔離）', () {
    test('fetchTransactions：依 user_id 查詢並轉成 TransactionModel 列表', () async {
      when(() => mockHttp.send(any())).thenAnswer((invocation) async {
        final req = invocation.positionalArguments.first as http.BaseRequest;
        expect(req.method, 'GET');
        expect(req.url.path, '/rest/v1/transactions');
        expect(req.url.queryParameters['user_id'], 'eq.user-a');
        expect(
          req.url.queryParameters['order'],
          startsWith('created_at.desc'),
        );
        final body = jsonEncode([
          _transactionRow(id: 'tx-1', amount: 100),
          _transactionRow(id: 'tx-2', amount: 200, createdAt: '2026-03-09T08:00:00.000Z'),
        ]);
        return _streamedJson(req, body, 200);
      });

      final list = await repo.fetchTransactions('user-a');

      expect(list, hasLength(2));
      expect(list.first.id, 'tx-1');
      expect(list.first.amount, 100);
      expect(list.first.type, 'topup');
      verify(() => mockHttp.send(any())).called(1);
    });

    test('processRefund：POST /rpc/process_refund 並帶入參數', () async {
      when(() => mockHttp.send(any())).thenAnswer((invocation) async {
        final req = invocation.positionalArguments.first as http.BaseRequest;
        expect(req.method, 'POST');
        expect(req.url.path, '/rest/v1/rpc/process_refund');
        expect(req, isA<http.Request>());
        final r = req as http.Request;
        final map = jsonDecode(r.body) as Map<String, dynamic>;
        expect(map['target_user_id'], 'parent-1');
        expect(map['amount_to_refund'], 150);
        expect(map['booking_uuid'], 'book-99');
        expect(map['course_name'], '網球課');
        expect(map['session_info'], '03/15 10:00');
        expect(map['student_name'], '王小明');
        expect(map['student_id'], 'stu-1');
        return _streamedEmpty(req, 204);
      });

      await repo.processRefund(
        userId: 'parent-1',
        amount: 150,
        bookingId: 'book-99',
        courseName: '網球課',
        sessionInfo: '03/15 10:00',
        studentName: '王小明',
        studentId: 'stu-1',
      );

      verify(() => mockHttp.send(any())).called(1);
    });

    test('processRefund：RPC 失敗時包裝為「退款失敗」', () async {
      when(() => mockHttp.send(any())).thenAnswer((invocation) async {
        final req = invocation.positionalArguments.first as http.BaseRequest;
        return _streamedJson(
          req,
          jsonEncode({
            'message': '餘額不足',
            'code': 'P0001',
            'details': null,
            'hint': null,
          }),
          400,
        );
      });

      await expectLater(
        repo.processRefund(
          userId: 'u',
          amount: 1,
          bookingId: 'b',
          courseName: 'c',
          sessionInfo: 's',
          studentName: 'n',
          studentId: 'st',
        ),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('退款失敗'),
          ),
        ),
      );
    });

    test('fetchAdminTransactions：type=topup、含 join 時解析 user / operator 姓名', () async {
      when(() => mockHttp.send(any())).thenAnswer((invocation) async {
        final req = invocation.positionalArguments.first as http.BaseRequest;
        expect(req.method, 'GET');
        expect(req.url.path, '/rest/v1/transactions');
        expect(req.url.queryParameters['type'], 'eq.topup');
        expect(
          req.url.queryParameters['order'],
          startsWith('created_at.desc'),
        );
        final body = jsonEncode([
          _transactionRow(
            user: {'full_name': '客戶甲'},
            operator: {'full_name': '櫃台乙'},
          ),
        ]);
        return _streamedJson(req, body, 200);
      });

      final list = await repo.fetchAdminTransactions();

      expect(list, hasLength(1));
      expect(list.first.userFullName, '客戶甲');
      expect(list.first.operatorFullName, '櫃台乙');
      expect(list.first.type, 'topup');
      verify(() => mockHttp.send(any())).called(1);
    });

    test('fetchAdminTransactions：日期與 performed_by、is_reconciled 篩選', () async {
      final startDate = DateTime(2026, 3, 1);
      final endDate = DateTime(2026, 3, 31);
      final expectedGte = startDate.toUtc().toIso8601String();
      final endOfDay = DateTime(
        endDate.year,
        endDate.month,
        endDate.day,
        23,
        59,
        59,
        999,
      );
      final expectedLte = endOfDay.toUtc().toIso8601String();

      when(() => mockHttp.send(any())).thenAnswer((invocation) async {
        final req = invocation.positionalArguments.first as http.BaseRequest;
        final q = req.url.queryParametersAll;
        final createdAtFilters = q['created_at'] ?? [];
        expect(
          createdAtFilters,
          containsAll(['gte.$expectedGte', 'lte.$expectedLte']),
        );
        expect(req.url.queryParameters['performed_by'], 'eq.coach-1');
        expect(req.url.queryParameters['is_reconciled'], 'eq.true');
        expect(req.url.queryParameters['status'], 'eq.valid');
        return _streamedJson(req, '[]', 200);
      });

      final list = await repo.fetchAdminTransactions(
        startDate: startDate,
        endDate: endDate,
        performedById: 'coach-1',
        isReconciled: true,
      );

      expect(list, isEmpty);
      verify(() => mockHttp.send(any())).called(1);
    });

    test('reconcileTransactions：空列表不發送請求', () async {
      await repo.reconcileTransactions([]);

      verifyNever(() => mockHttp.send(any()));
    });

    test('reconcileTransactions：POST /rpc/reconcile_transactions', () async {
      when(() => mockHttp.send(any())).thenAnswer((invocation) async {
        final req = invocation.positionalArguments.first as http.BaseRequest;
        expect(req.method, 'POST');
        expect(req.url.path, '/rest/v1/rpc/reconcile_transactions');
        final r = req as http.Request;
        final map = jsonDecode(r.body) as Map<String, dynamic>;
        expect(map['transaction_ids'], ['a', 'b']);
        return _streamedEmpty(req, 204);
      });

      await repo.reconcileTransactions(const ['a', 'b']);

      verify(() => mockHttp.send(any())).called(1);
    });

    test('reconcileTransactions：Postgrest 錯誤時包裝為「對帳失敗」', () async {
      when(() => mockHttp.send(any())).thenAnswer((invocation) async {
        final req = invocation.positionalArguments.first as http.BaseRequest;
        return _streamedJson(
          req,
          jsonEncode({
            'message': '已對帳過',
            'code': '23505',
          }),
          409,
        );
      });

      await expectLater(
        repo.reconcileTransactions(const ['x']),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('對帳失敗'),
          ),
        ),
      );
    });

    test('refundCashTransaction：POST /rpc/refund_cash_transaction', () async {
      when(() => mockHttp.send(any())).thenAnswer((invocation) async {
        final req = invocation.positionalArguments.first as http.BaseRequest;
        expect(req.method, 'POST');
        expect(req.url.path, '/rest/v1/rpc/refund_cash_transaction');
        final r = req as http.Request;
        final map = jsonDecode(r.body) as Map<String, dynamic>;
        expect(map['target_transaction_id'], 'tx-88');
        expect(map['refund_reason'], '收銀誤刷');
        return _streamedEmpty(req, 200);
      });

      await repo.refundCashTransaction(
        transactionId: 'tx-88',
        reason: '收銀誤刷',
      );

      verify(() => mockHttp.send(any())).called(1);
    });

    test('refundCashTransaction：Postgrest 錯誤時包裝為「退款失敗」', () async {
      when(() => mockHttp.send(any())).thenAnswer((invocation) async {
        final req = invocation.positionalArguments.first as http.BaseRequest;
        return _streamedJson(
          req,
          jsonEncode({'message': '不可退款'}),
          400,
        );
      });

      await expectLater(
        repo.refundCashTransaction(transactionId: 't', reason: 'r'),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('退款失敗'),
          ),
        ),
      );
    });
  });
}
