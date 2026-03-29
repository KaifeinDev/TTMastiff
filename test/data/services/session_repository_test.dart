import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ttmastiff/data/services/credit_repository.dart';
import 'package:ttmastiff/data/services/session_repository.dart';

class _MockHttpClient extends Mock implements http.Client {}

class _MockCreditRepository extends Mock implements CreditRepository {}

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

Map<String, dynamic> _courseJson({String id = 'course-1'}) {
  return {
    'id': id,
    'title': '團體課',
    'description': null,
    'price': 100,
    'default_start_time': '10:00:00',
    'default_end_time': '11:00:00',
    'image_url': null,
    'category': 'group',
    'is_published': true,
  };
}

Map<String, dynamic> _sessionRow({
  required String id,
  required String startIso,
  required String endIso,
  List<String>? tableIds,
  Map<String, dynamic>? course,
}) {
  return {
    'id': id,
    'course_id': (course ?? _courseJson())['id'],
    'start_time': startIso,
    'end_time': endIso,
    'max_capacity': 8,
    'coach_ids': <String>[],
    'table_ids': tableIds ?? <String>[],
    'bookings': [
      {'count': 0},
    ],
    'courses': course ?? _courseJson(),
  };
}

void main() {
  late _MockHttpClient mockHttp;
  late SupabaseClient supabase;
  late _MockCreditRepository mockCredit;
  late SessionRepository repo;

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
    repo = SessionRepository(supabase, mockCredit);
  });

  group('SessionRepository（HTTP 由 mocktail 隔離）', () {
    test('getSessionsByCourse：依 course_id 查詢並轉成 SessionModel 列表', () async {
      final row = _sessionRow(
        id: 's1',
        startIso: '2026-05-01T10:00:00.000Z',
        endIso: '2026-05-01T11:00:00.000Z',
      );

      when(() => mockHttp.send(any())).thenAnswer((invocation) async {
        final req = invocation.positionalArguments.first as http.BaseRequest;
        expect(req.method, 'GET');
        expect(req.url.path, '/rest/v1/sessions');
        expect(req.url.queryParameters['course_id'], 'eq.course-1');
        final body = jsonEncode([row]);
        return _streamedJson(req, body, 200);
      });

      final list = await repo.getSessionsByCourse('course-1');

      expect(list, hasLength(1));
      expect(list.first.id, 's1');
      expect(list.first.course?.title, '團體課');
      verify(() => mockHttp.send(any())).called(1);
    });

    test('getSessionsByCourse：有 table_ids 時會再查詢 tables 並填入 tables', () async {
      var call = 0;
      final row = _sessionRow(
        id: 's2',
        startIso: '2026-05-02T10:00:00.000Z',
        endIso: '2026-05-02T11:00:00.000Z',
        tableIds: ['tbl-a'],
      );

      when(() => mockHttp.send(any())).thenAnswer((invocation) async {
        call++;
        final req = invocation.positionalArguments.first as http.BaseRequest;
        if (call == 1) {
          expect(req.url.path, '/rest/v1/sessions');
          final body = jsonEncode([row]);
          return _streamedJson(req, body, 200);
        }
        if (call == 2) {
          expect(req.url.path, '/rest/v1/tables');
          expect(req.url.queryParameters['id'], 'in.("tbl-a")');
          final body = jsonEncode([
            {
              'id': 'tbl-a',
              'name': '第1桌',
              'capacity': 4,
              'is_active': true,
              'sort_order': 0,
            },
          ]);
          return _streamedJson(req, body, 200);
        }
        fail('未預期的第 $call 次請求');
      });

      final list = await repo.getSessionsByCourse('course-1');

      expect(list, hasLength(1));
      expect(list.first.tables, hasLength(1));
      expect(list.first.tables.first.name, '第1桌');
      expect(call, 2);
    });

    test('deleteSession：歷史場次（已結束）禁止刪除', () async {
      when(() => mockHttp.send(any())).thenAnswer((invocation) async {
        final req = invocation.positionalArguments.first as http.BaseRequest;
        expect(req.method, 'GET');
        expect(req.url.path, '/rest/v1/sessions');
        final body = jsonEncode({
          'id': 's-old',
          'start_time': '2026-05-01T10:00:00.000Z',
          'end_time': '2026-05-01T11:00:00.000Z',
          'courses': {'title': '舊課'},
        });
        return _streamedJson(req, body, 200);
      });

      final repoWithClock = SessionRepository(
        supabase,
        mockCredit,
        clock: () => DateTime(2026, 6, 15, 12, 0, 0),
      );

      await expectLater(
        repoWithClock.deleteSession('s-old'),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('無法刪除歷史場次'),
          ),
        ),
      );
      verify(() => mockHttp.send(any())).called(1);
    });

    test('deleteSession：未來場次且無 confirmed 預約時刪除 session', () async {
      var call = 0;
      when(() => mockHttp.send(any())).thenAnswer((invocation) async {
        call++;
        final req = invocation.positionalArguments.first as http.BaseRequest;
        if (call == 1) {
          expect(req.method, 'GET');
          expect(req.url.path, '/rest/v1/sessions');
          final body = jsonEncode({
            'id': 's-new',
            'start_time': '2026-12-01T10:00:00.000Z',
            'end_time': '2026-12-01T11:00:00.000Z',
            'courses': {'title': '未來課'},
          });
          return _streamedJson(req, body, 200);
        }
        if (call == 2) {
          expect(req.method, 'GET');
          expect(req.url.path, '/rest/v1/bookings');
          return _streamedJson(req, '[]', 200);
        }
        if (call == 3) {
          expect(req.method, 'DELETE');
          expect(req.url.path, '/rest/v1/sessions');
          return _streamedEmpty(req, 204);
        }
        fail('未預期的第 $call 次請求');
      });

      final repoWithClock = SessionRepository(
        supabase,
        mockCredit,
        clock: () => DateTime(2026, 6, 1, 12, 0, 0),
      );

      await repoWithClock.deleteSession('s-new');
      expect(call, 3);
      verifyNever(() => mockCredit.processRefund(
            userId: any(named: 'userId'),
            amount: any(named: 'amount'),
            bookingId: any(named: 'bookingId'),
            courseName: any(named: 'courseName'),
            sessionInfo: any(named: 'sessionInfo'),
            studentName: any(named: 'studentName'),
            studentId: any(named: 'studentId'),
            reason: any(named: 'reason'),
          ));
    });

    test(
        'deleteSession：未來場次且有 confirmed 預約時先 processRefund 再刪除 session',
        () async {
      when(
        () => mockCredit.processRefund(
          userId: any(named: 'userId'),
          amount: any(named: 'amount'),
          bookingId: any(named: 'bookingId'),
          courseName: any(named: 'courseName'),
          sessionInfo: any(named: 'sessionInfo'),
          studentName: any(named: 'studentName'),
          studentId: any(named: 'studentId'),
          reason: any(named: 'reason'),
        ),
      ).thenAnswer((_) async {});

      var call = 0;
      when(() => mockHttp.send(any())).thenAnswer((invocation) async {
        call++;
        final req = invocation.positionalArguments.first as http.BaseRequest;
        if (call == 1) {
          expect(req.method, 'GET');
          expect(req.url.path, '/rest/v1/sessions');
          final body = jsonEncode({
            'id': 's-refund',
            'start_time': '2026-12-01T10:00:00.000Z',
            'end_time': '2026-12-01T11:00:00.000Z',
            'courses': {'title': '退款課程'},
          });
          return _streamedJson(req, body, 200);
        }
        if (call == 2) {
          expect(req.method, 'GET');
          expect(req.url.path, '/rest/v1/bookings');
          final bookingsBody = jsonEncode([
            {
              'id': 'bk-1',
              'user_id': 'parent-uuid',
              'price_snapshot': 350,
              'students': {'id': 'stu-x', 'name': '學員甲'},
            },
          ]);
          return _streamedJson(req, bookingsBody, 200);
        }
        if (call == 3) {
          expect(req.method, 'DELETE');
          expect(req.url.path, '/rest/v1/sessions');
          return _streamedEmpty(req, 204);
        }
        fail('未預期的第 $call 次請求');
      });

      final repoWithClock = SessionRepository(
        supabase,
        mockCredit,
        clock: () => DateTime(2026, 6, 1, 12, 0, 0),
      );

      await repoWithClock.deleteSession('s-refund');

      expect(call, 3);
      verify(
        () => mockCredit.processRefund(
          userId: 'parent-uuid',
          amount: 350,
          bookingId: 'bk-1',
          courseName: '退款課程',
          sessionInfo: any(named: 'sessionInfo'),
          studentName: '學員甲',
          studentId: 'stu-x',
          reason: '課程取消',
        ),
      ).called(1);
    });
  });
}
