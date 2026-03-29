import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ttmastiff/data/models/payroll_model.dart';
import 'package:ttmastiff/data/models/staff_detail_model.dart';
import 'package:ttmastiff/data/models/work_shift_model.dart';
import 'package:ttmastiff/data/services/salary_repository.dart';

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
  late SalaryRepository repo;

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
    repo = SalaryRepository(supabase);
  });

  group('SalaryRepository（HTTP 由 mocktail 隔離）', () {
    test('getYearlyPayrolls：依 year 查詢並轉成 PayrollModel', () async {
      when(() => mockHttp.send(any())).thenAnswer((invocation) async {
        final req = invocation.positionalArguments.first as http.BaseRequest;
        expect(req.method, 'GET');
        expect(req.url.path, '/rest/v1/payrolls');
        expect(req.url.queryParameters['year'], 'eq.2026');
        final body = jsonEncode([
          {
            'id': 'p1',
            'staff_id': 'st1',
            'year': 2026,
            'month': 3,
            'total_coach_hours': 10.0,
            'coach_hourly_rate': 500,
            'total_desk_hours': 2.0,
            'desk_hourly_rate': 180,
            'total_amount': 5360,
            'status': 'settled',
          },
        ]);
        return _streamedJson(req, body, 200);
      });

      final list = await repo.getYearlyPayrolls(2026);

      expect(list, hasLength(1));
      expect(list.first.staffId, 'st1');
      expect(list.first.totalAmount, 5360);
      verify(() => mockHttp.send(any())).called(1);
    });

    test('getStaffDetail：有資料時回傳 StaffDetailModel', () async {
      when(() => mockHttp.send(any())).thenAnswer((invocation) async {
        final req = invocation.positionalArguments.first as http.BaseRequest;
        expect(req.url.path, '/rest/v1/staff_details');
        return _streamedJson(
          req,
          jsonEncode([
            {
              'id': 'st-1',
              'coach_hourly_rate': 400,
              'desk_hourly_rate': 190,
              'bank_account': '000',
              'status': 'active',
            },
          ]),
          200,
        );
      });

      final d = await repo.getStaffDetail('st-1');

      expect(d, isNotNull);
      expect(d!.coachHourlyRate, 400);
      expect(d.deskHourlyRate, 190);
    });

    test('getStaffDetail：無列時回傳 null', () async {
      when(() => mockHttp.send(any())).thenAnswer((invocation) async {
        final req = invocation.positionalArguments.first as http.BaseRequest;
        return _streamedJson(req, '[]', 200);
      });

      expect(await repo.getStaffDetail('none'), isNull);
    });

    test('getMonthlySalaryReport：並行查五表並組出報表（預覽未結算）', () async {
      when(() => mockHttp.send(any())).thenAnswer((invocation) async {
        final req = invocation.positionalArguments.first as http.BaseRequest;
        final path = req.url.path;
        if (path == '/rest/v1/profiles') {
          return _streamedJson(
            req,
            jsonEncode([
              {'id': 'staff-1', 'full_name': '教練甲'},
            ]),
            200,
          );
        }
        if (path == '/rest/v1/work_shifts') {
          return _streamedJson(req, '[]', 200);
        }
        if (path == '/rest/v1/sessions') {
          return _streamedJson(req, '[]', 200);
        }
        if (path == '/rest/v1/payrolls') {
          return _streamedJson(req, '[]', 200);
        }
        if (path == '/rest/v1/staff_details') {
          return _streamedJson(
            req,
            jsonEncode([
              {
                'id': 'staff-1',
                'coach_hourly_rate': 400,
                'desk_hourly_rate': 200,
                'bank_account': '111',
                'status': 'active',
              },
            ]),
            200,
          );
        }
        fail('未預期的 path: $path');
      });

      final report = await repo.getMonthlySalaryReport(2026, 6);

      expect(report, hasLength(1));
      expect(report.first['profile']?['id'], 'staff-1');
      expect(report.first['base_rate'], 400);
      final payroll = report.first['payroll'] as PayrollModel;
      expect(payroll.status, 'unsettled');
      expect(payroll.totalAmount, 0);
      verify(() => mockHttp.send(any())).called(5);
    });

    test('savePayroll：upsert payrolls', () async {
      when(() => mockHttp.send(any())).thenAnswer((invocation) async {
        final req = invocation.positionalArguments.first as http.BaseRequest;
        expect(req.method, 'POST');
        expect(req.url.path, '/rest/v1/payrolls');
        return _streamedEmpty(req, 200);
      });

      await repo.savePayroll(
        PayrollModel(
          id: '',
          staffId: 'st',
          year: 2026,
          month: 4,
          totalCoachHours: 1,
          coachHourlyRate: 500,
          totalDeskHours: 0,
          deskHourlyRate: 180,
          totalAmount: 500,
          status: 'settled',
        ),
      );

      verify(() => mockHttp.send(any())).called(1);
    });

    test('deleteWorkShift：DELETE 依 id', () async {
      when(() => mockHttp.send(any())).thenAnswer((invocation) async {
        final req = invocation.positionalArguments.first as http.BaseRequest;
        expect(req.method, 'DELETE');
        expect(req.url.queryParameters['id'], 'eq.shift-1');
        return _streamedEmpty(req, 204);
      });

      await repo.deleteWorkShift('shift-1');

      verify(() => mockHttp.send(any())).called(1);
    });

    test('getStaffShifts：依 staff 與月份區間查排班', () async {
      when(() => mockHttp.send(any())).thenAnswer((invocation) async {
        final req = invocation.positionalArguments.first as http.BaseRequest;
        expect(req.method, 'GET');
        expect(req.url.path, '/rest/v1/work_shifts');
        expect(req.url.queryParameters['staff_id'], 'eq.staff-x');
        expect(
          req.url.queryParameters['order'],
          startsWith('start_time.desc'),
        );
        return _streamedJson(
          req,
          jsonEncode([
            {
              'id': 'ws-1',
              'staff_id': 'staff-x',
              'start_time': '2026-05-01T02:00:00.000Z',
              'end_time': '2026-05-01T04:00:00.000Z',
              'note': null,
            },
          ]),
          200,
        );
      });

      final shifts = await repo.getStaffShifts(
        'staff-x',
        DateTime(2026, 5),
      );

      expect(shifts, hasLength(1));
      expect(shifts.first.id, 'ws-1');
      expect(shifts.first.hours, 2.0);
    });

    test('calculateEstimatedSalary：無 staff_details 時用預設費率估算', () async {
      var call = 0;
      when(() => mockHttp.send(any())).thenAnswer((invocation) async {
        call++;
        final req = invocation.positionalArguments.first as http.BaseRequest;
        final path = req.url.path;
        if (path == '/rest/v1/staff_details') {
          return _streamedJson(req, '[]', 200);
        }
        if (path == '/rest/v1/work_shifts') {
          return _streamedJson(req, '[]', 200);
        }
        if (path == '/rest/v1/sessions') {
          return _streamedJson(req, '[]', 200);
        }
        fail('call $call path $path');
      });

      final est = await repo.calculateEstimatedSalary(
        staffId: 'any',
        year: 2026,
        month: 8,
      );

      expect(est.coachHourlyRate, 350);
      expect(est.deskHourlyRate, 180);
      expect(est.totalAmount, 0);
      expect(call, 3);
    });

    test('updateStaffDetail：upsert staff_details', () async {
      when(() => mockHttp.send(any())).thenAnswer((invocation) async {
        final req = invocation.positionalArguments.first as http.BaseRequest;
        expect(req.method, 'POST');
        expect(req.url.path, '/rest/v1/staff_details');
        final r = req as http.Request;
        final m = jsonDecode(r.body) as Map<String, dynamic>;
        expect(m['id'], 'sid');
        expect(m['coach_hourly_rate'], 420);
        return _streamedEmpty(req, 200);
      });

      await repo.updateStaffDetail(
        StaffDetailModel(
          id: 'sid',
          coachHourlyRate: 420,
          deskHourlyRate: 200,
          bankAccount: 'x',
        ),
      );

      verify(() => mockHttp.send(any())).called(1);
    });

    test('upsertWorkShift：無 id 時 insert', () async {
      when(() => mockHttp.send(any())).thenAnswer((invocation) async {
        final req = invocation.positionalArguments.first as http.BaseRequest;
        expect(req.method, 'POST');
        expect(req.url.path, '/rest/v1/work_shifts');
        return _streamedEmpty(req, 201);
      });

      await repo.upsertWorkShift(
        WorkShiftModel(
          id: '',
          staffId: 's',
          startTime: DateTime.utc(2026, 1, 1, 10),
          endTime: DateTime.utc(2026, 1, 1, 12),
        ),
      );

      verify(() => mockHttp.send(any())).called(1);
    });

    test('upsertWorkShift：有 id 時 update', () async {
      when(() => mockHttp.send(any())).thenAnswer((invocation) async {
        final req = invocation.positionalArguments.first as http.BaseRequest;
        expect(req.method, 'PATCH');
        expect(req.url.queryParameters['id'], 'eq.ws-old');
        return _streamedEmpty(req, 204);
      });

      await repo.upsertWorkShift(
        WorkShiftModel(
          id: 'ws-old',
          staffId: 's',
          startTime: DateTime.utc(2026, 1, 2, 10),
          endTime: DateTime.utc(2026, 1, 2, 11),
        ),
      );

      verify(() => mockHttp.send(any())).called(1);
    });
  });
}
