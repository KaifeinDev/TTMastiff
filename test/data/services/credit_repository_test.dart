import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ttmastiff/data/services/credit_repository.dart';

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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockHttpClient mockHttp;
  late SupabaseClient supabase;
  late CreditRepository repo;

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
    repo = CreditRepository(supabase);
  });

  group('CreditRepository（HTTP 由 mocktail 隔離）', () {
    test('getCurrentCredit：讀取 profiles.credits', () async {
      when(() => mockHttp.send(any())).thenAnswer((invocation) async {
        final req = invocation.positionalArguments.first as http.BaseRequest;
        expect(req.method, 'GET');
        expect(req.url.path, '/rest/v1/profiles');
        expect(req.url.queryParameters['id'], 'eq.user-1');
        expect(req.url.queryParameters['select'], 'credits');
        return _streamedJson(req, jsonEncode({'credits': 1200}), 200);
      });

      expect(await repo.getCurrentCredit('user-1'), 1200);
      verify(() => mockHttp.send(any())).called(1);
    });

    test('getCurrentCredit：credits 為 null 時回傳 0', () async {
      when(() => mockHttp.send(any())).thenAnswer((invocation) async {
        final req = invocation.positionalArguments.first as http.BaseRequest;
        return _streamedJson(req, jsonEncode({'credits': null}), 200);
      });

      expect(await repo.getCurrentCredit('u'), 0);
    });

    test('addCredit：RPC 成功回傳新餘額', () async {
      when(() => mockHttp.send(any())).thenAnswer((invocation) async {
        final req = invocation.positionalArguments.first as http.BaseRequest;
        expect(req.method, 'POST');
        expect(req.url.path, '/rest/v1/rpc/add_credits');
        final r = req as http.Request;
        final m = jsonDecode(r.body) as Map<String, dynamic>;
        expect(m['target_user_id'], 'parent-1');
        expect(m['amount_to_add'], 500);
        expect(m['input_pin'], '1234');
        return _streamedJson(req, '2500', 200);
      });

      expect(
        await repo.addCredit(
          userId: 'parent-1',
          amount: 500,
          pin: '1234',
        ),
        2500,
      );
    });

    test('addCredit：PIN 相關錯誤改為中文提示', () async {
      when(() => mockHttp.send(any())).thenAnswer((invocation) async {
        final req = invocation.positionalArguments.first as http.BaseRequest;
        return _streamedJson(
          req,
          jsonEncode({'message': 'Invalid PIN'}),
          400,
        );
      });

      await expectLater(
        repo.addCredit(userId: 'u', amount: 1, pin: 'x'),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'msg',
            contains('PIN'),
          ),
        ),
      );
    });

    test('payForBooking：RPC 成功回傳新餘額', () async {
      when(() => mockHttp.send(any())).thenAnswer((invocation) async {
        final req = invocation.positionalArguments.first as http.BaseRequest;
        expect(req.method, 'POST');
        expect(req.url.path, '/rest/v1/rpc/pay_for_booking');
        final r = req as http.Request;
        final m = jsonDecode(r.body) as Map<String, dynamic>;
        expect(m['cost_amount'], 300);
        expect(m['booking_uuid'], 'bk-1');
        return _streamedJson(req, '800', 200);
      });

      expect(
        await repo.payForBooking(
          userId: 'u',
          cost: 300,
          bookingId: 'bk-1',
          courseName: '課',
          sessionInfo: 's',
          studentName: 'n',
          studentId: 'st',
        ),
        800,
      );
    });

    test('payForBooking：餘額不足改為中文提示', () async {
      when(() => mockHttp.send(any())).thenAnswer((invocation) async {
        final req = invocation.positionalArguments.first as http.BaseRequest;
        return _streamedJson(
          req,
          jsonEncode({'message': 'Insufficient Funds'}),
          400,
        );
      });

      await expectLater(
        repo.payForBooking(
          userId: 'u',
          cost: 1,
          bookingId: 'b',
          courseName: 'c',
          sessionInfo: 's',
          studentName: 'n',
          studentId: 'st',
        ),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'msg',
            contains('餘額不足'),
          ),
        ),
      );
    });

    test('processRefund：RPC 成功', () async {
      when(() => mockHttp.send(any())).thenAnswer((invocation) async {
        final req = invocation.positionalArguments.first as http.BaseRequest;
        expect(req.url.path, '/rest/v1/rpc/process_refund');
        final r = req as http.Request;
        final m = jsonDecode(r.body) as Map<String, dynamic>;
        expect(m['refund_reason'], '預約取消');
        return _streamedEmpty(req, 204);
      });

      await repo.processRefund(
        userId: 'u',
        amount: 100,
        bookingId: 'b',
        courseName: 'c',
        sessionInfo: 's',
        studentName: 'n',
        studentId: 'st',
      );

      verify(() => mockHttp.send(any())).called(1);
    });

    test('processRefund：Postgrest 錯誤包裝為退款執行失敗', () async {
      when(() => mockHttp.send(any())).thenAnswer((invocation) async {
        final req = invocation.positionalArguments.first as http.BaseRequest;
        return _streamedJson(
          req,
          jsonEncode({'message': 'db error'}),
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
            'msg',
            contains('退款執行失敗'),
          ),
        ),
      );
    });
  });
}
