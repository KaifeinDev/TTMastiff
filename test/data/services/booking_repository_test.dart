import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ttmastiff/data/services/booking_repository.dart';
import 'package:ttmastiff/data/services/credit_repository.dart';
import 'package:ttmastiff/data/services/transaction_repository.dart';

class _MockHttpClient extends Mock implements http.Client {}

class _MockCreditRepository extends Mock implements CreditRepository {}

class _MockTransactionRepository extends Mock implements TransactionRepository {}

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

http.StreamedResponse _streamedEmpty(
  http.BaseRequest req,
  int statusCode, {
  Map<String, String> headers = const {},
}) {
  return http.StreamedResponse(
    Stream<List<int>>.value(Uint8List(0)),
    statusCode,
    request: req,
    headers: headers,
  );
}

/// PostgREST HEAD + `Prefer: count=exact`：由 [content-range] 最後一段解析人數。
http.StreamedResponse _streamedHeadCount(http.BaseRequest req, int total) {
  return http.StreamedResponse(
    Stream<List<int>>.value(Uint8List(0)),
    200,
    request: req,
    headers: {'content-range': '0-0/$total'},
  );
}

Map<String, dynamic> _courseJson() {
  return {
    'id': 'c-1',
    'title': '課程',
    'description': null,
    'price': 100,
    'default_start_time': '10:00:00',
    'default_end_time': '11:00:00',
    'image_url': null,
    'category': 'group',
    'is_published': true,
  };
}

Map<String, dynamic> _sessionJson() {
  return {
    'id': 'sess-1',
    'course_id': 'c-1',
    'start_time': '2026-06-01T10:00:00.000Z',
    'end_time': '2026-06-01T11:00:00.000Z',
    'max_capacity': 8,
    'coach_ids': <String>[],
    'table_ids': <String>[],
    'bookings': <Map<String, dynamic>>[
      {'count': 0},
    ],
    'courses': _courseJson(),
  };
}

Map<String, dynamic> _studentJson() {
  return {
    'id': 'stu-1',
    'parent_id': 'u-1',
    'name': '學員A',
    'birth_date': '2015-01-01',
    'is_primary': true,
  };
}

Map<String, dynamic> _bookingRow({String id = 'book-1'}) {
  return {
    'id': id,
    'status': 'confirmed',
    'attendance_status': 'pending',
    'price_snapshot': 200,
    'student_id': 'stu-1',
    'session_id': 'sess-1',
    'created_at': '2026-05-01T08:00:00.000Z',
    'sessions': _sessionJson(),
    'students': _studentJson(),
  };
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockHttpClient mockHttp;
  late SupabaseClient supabase;
  late _MockCreditRepository mockCredit;
  late _MockTransactionRepository mockTx;
  late BookingRepository repo;

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
    mockCredit = _MockCreditRepository();
    mockTx = _MockTransactionRepository();
    repo = BookingRepository(supabase, mockCredit, mockTx);
  });

  group('BookingRepository（HTTP 由 mocktail 隔離）', () {
    test('fetchBookingsBySessionId 回傳 BookingModel 列表', () async {
      when(() => mockHttp.send(any())).thenAnswer((invocation) async {
        final req = invocation.positionalArguments.first as http.BaseRequest;
        expect(req.method, 'GET');
        expect(req.url.path, '/rest/v1/bookings');
        expect(req.url.queryParameters['session_id'], 'eq.sess-1');
        final body = jsonEncode([_bookingRow()]);
        return _streamedJson(req, body, 200);
      });

      final list = await repo.fetchBookingsBySessionId('sess-1');

      expect(list, hasLength(1));
      expect(list.first.id, 'book-1');
      expect(list.first.priceSnapshot, 200);
      expect(list.first.session.courseTitle, '課程');
      verify(() => mockHttp.send(any())).called(1);
    });

    test('requestLeave 發送 PATCH 更新 attendance_status', () async {
      when(() => mockHttp.send(any())).thenAnswer((invocation) async {
        final req = invocation.positionalArguments.first as http.BaseRequest;
        expect(req.method, 'PATCH');
        expect(req.url.path, '/rest/v1/bookings');
        return _streamedEmpty(req, 204);
      });

      await repo.requestLeave('booking-uuid');

      verify(() => mockHttp.send(any())).called(1);
    });

    test('updateBookingStatus 發送 PATCH 更新 status 與 attendance_status', () async {
      when(() => mockHttp.send(any())).thenAnswer((invocation) async {
        final req = invocation.positionalArguments.first as http.BaseRequest;
        expect(req.method, 'PATCH');
        expect(req.url.path, '/rest/v1/bookings');
        return _streamedEmpty(req, 204);
      });

      await repo.updateBookingStatus(
        bookingId: 'bid-1',
        status: 'confirmed',
        attendanceStatus: 'attended',
      );

      verify(() => mockHttp.send(any())).called(1);
    });

    test('cancelBooking：已為 cancelled 時不更新也不呼叫退款', () async {
      when(() => mockHttp.send(any())).thenAnswer((invocation) async {
        final req = invocation.positionalArguments.first as http.BaseRequest;
        expect(req.method, 'GET');
        expect(req.url.path, '/rest/v1/bookings');
        final body = jsonEncode({
          'user_id': 'u1',
          'student_id': 'st1',
          'price_snapshot': 500,
          'status': 'cancelled',
          'sessions': {
            'start_time': '2026-08-01T10:00:00.000Z',
            'courses': {'title': '課'},
          },
          'students': {'name': '某人'},
        });
        return _streamedJson(req, body, 200);
      });

      await repo.cancelBooking('bid-done');

      verify(() => mockHttp.send(any())).called(1);
      verifyNever(
        () => mockTx.processRefund(
          userId: any(named: 'userId'),
          amount: any(named: 'amount'),
          bookingId: any(named: 'bookingId'),
          courseName: any(named: 'courseName'),
          sessionInfo: any(named: 'sessionInfo'),
          studentName: any(named: 'studentName'),
          studentId: any(named: 'studentId'),
        ),
      );
    });

    test('cancelBooking：confirmed 且有金額時 PATCH 後呼叫 TransactionRepository.processRefund',
        () async {
      when(
        () => mockTx.processRefund(
          userId: any(named: 'userId'),
          amount: any(named: 'amount'),
          bookingId: any(named: 'bookingId'),
          courseName: any(named: 'courseName'),
          sessionInfo: any(named: 'sessionInfo'),
          studentName: any(named: 'studentName'),
          studentId: any(named: 'studentId'),
        ),
      ).thenAnswer((_) async {});

      var call = 0;
      when(() => mockHttp.send(any())).thenAnswer((invocation) async {
        call++;
        final req = invocation.positionalArguments.first as http.BaseRequest;
        if (call == 1) {
          expect(req.method, 'GET');
          expect(req.url.path, '/rest/v1/bookings');
          final body = jsonEncode({
            'user_id': 'parent-uuid',
            'student_id': 'stu-88',
            'price_snapshot': 400,
            'status': 'confirmed',
            'sessions': {
              'start_time': '2026-09-10T02:00:00.000Z',
              'courses': {'title': '團體班'},
            },
            'students': {'name': '張三'},
          });
          return _streamedJson(req, body, 200);
        }
        if (call == 2) {
          expect(req.method, 'PATCH');
          expect(req.url.path, '/rest/v1/bookings');
          return _streamedEmpty(req, 204);
        }
        fail('未預期的第 $call 次 HTTP');
      });

      await repo.cancelBooking('book-to-cancel');

      expect(call, 2);
      verify(
        () => mockTx.processRefund(
          userId: 'parent-uuid',
          amount: 400,
          bookingId: 'book-to-cancel',
          courseName: '團體班',
          sessionInfo: any(named: 'sessionInfo'),
          studentName: '張三',
          studentId: 'stu-88',
        ),
      ).called(1);
    });

    test('createBooking：人數已達上限時拋錯（不扣款）', () async {
      var call = 0;
      when(() => mockHttp.send(any())).thenAnswer((invocation) async {
        call++;
        final req = invocation.positionalArguments.first as http.BaseRequest;
        if (call == 1) {
          expect(req.method, 'GET');
          expect(req.url.path, '/rest/v1/sessions');
          return _streamedJson(
            req,
            jsonEncode({
              'id': 'sess-full',
              'max_capacity': 3,
              'start_time': '2026-12-01T10:00:00.000Z',
              'courses': {'title': '滿班課'},
            }),
            200,
          );
        }
        if (call == 2) {
          expect(req.method, 'GET');
          expect(req.url.path, '/rest/v1/students');
          return _streamedJson(req, jsonEncode({'name': '學生'}), 200);
        }
        if (call == 3) {
          expect(req.method, 'HEAD');
          expect(req.url.path, '/rest/v1/bookings');
          return _streamedHeadCount(req, 3);
        }
        fail('未預期的第 $call 次 HTTP');
      });

      await expectLater(
        repo.createBooking(
          sessionId: 'sess-full',
          studentId: 'stu-1',
          userId: 'user-1',
          priceSnapshot: 100,
        ),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('額滿'),
          ),
        ),
      );

      expect(call, 3);
      verifyNever(
        () => mockCredit.payForBooking(
          userId: any(named: 'userId'),
          cost: any(named: 'cost'),
          bookingId: any(named: 'bookingId'),
          courseName: any(named: 'courseName'),
          sessionInfo: any(named: 'sessionInfo'),
          studentName: any(named: 'studentName'),
          studentId: any(named: 'studentId'),
        ),
      );
    });

    test('createBooking：該生已 confirmed 時拋錯', () async {
      var call = 0;
      when(() => mockHttp.send(any())).thenAnswer((invocation) async {
        call++;
        final req = invocation.positionalArguments.first as http.BaseRequest;
        if (call == 1) {
          return _streamedJson(
            req,
            jsonEncode({
              'id': 'sess-1',
              'max_capacity': 10,
              'start_time': '2026-12-01T10:00:00.000Z',
              'courses': {'title': '課'},
            }),
            200,
          );
        }
        if (call == 2) {
          return _streamedJson(req, jsonEncode({'name': '小明'}), 200);
        }
        if (call == 3) {
          expect(req.method, 'HEAD');
          return _streamedHeadCount(req, 1);
        }
        if (call == 4) {
          expect(req.method, 'GET');
          return _streamedJson(
            req,
            jsonEncode([
              {'id': 'old-b', 'status': 'confirmed'},
            ]),
            200,
          );
        }
        fail('未預期的第 $call 次 HTTP');
      });

      await expectLater(
        repo.createBooking(
          sessionId: 'sess-1',
          studentId: 'stu-dup',
          userId: 'user-1',
          priceSnapshot: 200,
        ),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('已經報名過'),
          ),
        ),
      );

      expect(call, 4);
      verifyNever(
        () => mockCredit.payForBooking(
          userId: any(named: 'userId'),
          cost: any(named: 'cost'),
          bookingId: any(named: 'bookingId'),
          courseName: any(named: 'courseName'),
          sessionInfo: any(named: 'sessionInfo'),
          studentName: any(named: 'studentName'),
          studentId: any(named: 'studentId'),
        ),
      );
    });

    test('createBooking：全新報名成功時 insert 並呼叫 CreditRepository.payForBooking',
        () async {
      when(
        () => mockCredit.payForBooking(
          userId: any(named: 'userId'),
          cost: any(named: 'cost'),
          bookingId: any(named: 'bookingId'),
          courseName: any(named: 'courseName'),
          sessionInfo: any(named: 'sessionInfo'),
          studentName: any(named: 'studentName'),
          studentId: any(named: 'studentId'),
        ),
      ).thenAnswer((_) async => 500);

      var call = 0;
      when(() => mockHttp.send(any())).thenAnswer((invocation) async {
        call++;
        final req = invocation.positionalArguments.first as http.BaseRequest;
        if (call == 1) {
          return _streamedJson(
            req,
            jsonEncode({
              'id': 'sess-new',
              'max_capacity': 5,
              'start_time': '2026-11-15T03:30:00.000Z',
              'courses': {'title': '新課程'},
            }),
            200,
          );
        }
        if (call == 2) {
          return _streamedJson(req, jsonEncode({'name': '報名生'}), 200);
        }
        if (call == 3) {
          expect(req.method, 'HEAD');
          return _streamedHeadCount(req, 2);
        }
        if (call == 4) {
          expect(req.method, 'GET');
          return _streamedJson(req, '[]', 200);
        }
        if (call == 5) {
          expect(req.method, 'POST');
          expect(req.url.path, '/rest/v1/bookings');
          return _streamedJson(
            req,
            jsonEncode({
              'id': 'booking-new-id',
              'session_id': 'sess-new',
              'student_id': 'stu-new',
            }),
            201,
          );
        }
        fail('未預期的第 $call 次 HTTP');
      });

      await repo.createBooking(
        sessionId: 'sess-new',
        studentId: 'stu-new',
        userId: 'parent-z',
        priceSnapshot: 450,
      );

      expect(call, 5);
      verify(
        () => mockCredit.payForBooking(
          userId: 'parent-z',
          cost: 450,
          bookingId: 'booking-new-id',
          courseName: '新課程',
          sessionInfo: any(named: 'sessionInfo'),
          studentName: '報名生',
          studentId: 'stu-new',
        ),
      ).called(1);
    });

    test('createBooking：cancelled 舊單復活時 PATCH 後呼叫 payForBooking', () async {
      when(
        () => mockCredit.payForBooking(
          userId: any(named: 'userId'),
          cost: any(named: 'cost'),
          bookingId: any(named: 'bookingId'),
          courseName: any(named: 'courseName'),
          sessionInfo: any(named: 'sessionInfo'),
          studentName: any(named: 'studentName'),
          studentId: any(named: 'studentId'),
        ),
      ).thenAnswer((_) async => 100);

      var call = 0;
      when(() => mockHttp.send(any())).thenAnswer((invocation) async {
        call++;
        final req = invocation.positionalArguments.first as http.BaseRequest;
        if (call == 1) {
          return _streamedJson(
            req,
            jsonEncode({
              'id': 'sess-rev',
              'max_capacity': 10,
              'start_time': '2026-12-01T10:00:00.000Z',
              'courses': {'title': '復活課'},
            }),
            200,
          );
        }
        if (call == 2) {
          return _streamedJson(req, jsonEncode({'name': '復活生'}), 200);
        }
        if (call == 3) {
          expect(req.method, 'HEAD');
          return _streamedHeadCount(req, 2);
        }
        if (call == 4) {
          return _streamedJson(
            req,
            jsonEncode([
              {'id': 'bk-rev', 'status': 'cancelled'},
            ]),
            200,
          );
        }
        if (call == 5) {
          expect(req.method, 'PATCH');
          expect(req.url.path, '/rest/v1/bookings');
          return _streamedEmpty(req, 204);
        }
        fail('未預期的第 $call 次 HTTP');
      });

      await repo.createBooking(
        sessionId: 'sess-rev',
        studentId: 'stu-rev',
        userId: 'user-rev',
        priceSnapshot: 220,
      );

      expect(call, 5);
      verify(
        () => mockCredit.payForBooking(
          userId: 'user-rev',
          cost: 220,
          bookingId: 'bk-rev',
          courseName: '復活課',
          sessionInfo: any(named: 'sessionInfo'),
          studentName: '復活生',
          studentId: 'stu-rev',
        ),
      ).called(1);
    });

    test(
        'createBatchBooking：單一場次與學員、全新 insert 成功並回傳統計（authUserIdOverride）',
        () async {
      when(
        () => mockCredit.payForBooking(
          userId: any(named: 'userId'),
          cost: any(named: 'cost'),
          bookingId: any(named: 'bookingId'),
          courseName: any(named: 'courseName'),
          sessionInfo: any(named: 'sessionInfo'),
          studentName: any(named: 'studentName'),
          studentId: any(named: 'studentId'),
        ),
      ).thenAnswer((_) async => 999);

      var call = 0;
      when(() => mockHttp.send(any())).thenAnswer((invocation) async {
        call++;
        final req = invocation.positionalArguments.first as http.BaseRequest;
        if (call == 1) {
          expect(req.method, 'GET');
          expect(req.url.path, '/rest/v1/sessions');
          return _streamedJson(
            req,
            jsonEncode([
              {
                'id': 'sess-batch',
                'max_capacity': 8,
                'start_time': '2026-12-20T14:00:00.000Z',
                'courses': {'title': '批次課'},
              },
            ]),
            200,
          );
        }
        if (call == 2) {
          expect(req.method, 'GET');
          expect(req.url.path, '/rest/v1/students');
          return _streamedJson(
            req,
            jsonEncode([
              {
                'id': 'stu-batch',
                'name': '批次生',
                'parent_id': 'par-batch',
              },
            ]),
            200,
          );
        }
        if (call == 3) {
          expect(req.method, 'HEAD');
          expect(req.url.path, '/rest/v1/bookings');
          return _streamedHeadCount(req, 0);
        }
        if (call == 4) {
          expect(req.method, 'GET');
          return _streamedJson(req, '[]', 200);
        }
        if (call == 5) {
          expect(req.method, 'POST');
          expect(req.url.path, '/rest/v1/bookings');
          return _streamedJson(
            req,
            jsonEncode({
              'id': 'batch-bid',
              'session_id': 'sess-batch',
              'student_id': 'stu-batch',
            }),
            201,
          );
        }
        fail('未預期的第 $call 次 HTTP');
      });

      final result = await repo.createBatchBooking(
        sessionIds: const ['sess-batch'],
        studentIds: const ['stu-batch'],
        priceSnapshot: 180,
        authUserIdOverride: 'admin-test-id',
      );

      expect(result['success'], 1);
      expect(result['skipped'], 0);
      expect(result['totalCost'], 180);
      expect(call, 5);

      verify(
        () => mockCredit.payForBooking(
          userId: 'par-batch',
          cost: 180,
          bookingId: 'batch-bid',
          courseName: '批次課',
          sessionInfo: any(named: 'sessionInfo'),
          studentName: '批次生',
          studentId: 'stu-batch',
        ),
      ).called(1);
    });
  });
}
