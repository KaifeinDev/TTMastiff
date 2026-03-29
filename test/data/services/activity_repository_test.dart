import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ttmastiff/data/models/activity_model.dart';
import 'package:ttmastiff/data/services/activity_repository.dart';

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

Map<String, dynamic> _activityRow({
  String id = 'act-1',
  String title = '活動',
  String type = 'recent',
  int order = 0,
  String status = 'active',
}) {
  return {
    'id': id,
    'title': title,
    'description': '內文',
    'start_time': '2026-07-01T10:00:00.000Z',
    'end_time': '2026-07-01T12:00:00.000Z',
    'image': null,
    'type': type,
    'order': order,
    'status': status,
    'notification_status': 'unread',
    'created_at': '2026-06-01T00:00:00.000Z',
    'updated_at': null,
  };
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockHttpClient mockHttp;
  late SupabaseClient supabase;
  late ActivityRepository repo;

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
    repo = ActivityRepository(supabase);
  });

  group('ActivityRepository（HTTP 由 mocktail 隔離）', () {
    test('getActivities：查列表並依 order 排序', () async {
      when(() => mockHttp.send(any())).thenAnswer((invocation) async {
        final req = invocation.positionalArguments.first as http.BaseRequest;
        expect(req.method, 'GET');
        expect(req.url.path, '/rest/v1/activities');
        expect(
          req.url.queryParameters['order'],
          startsWith('order.asc'),
        );
        return _streamedJson(
          req,
          jsonEncode([
            _activityRow(id: 'a', order: 1),
            _activityRow(id: 'b', order: 2),
          ]),
          200,
        );
      });

      final list = await repo.getActivities();

      expect(list, hasLength(2));
      expect(list.first.id, 'a');
      verify(() => mockHttp.send(any())).called(1);
    });

    test('getActivityById：單筆 JSON 轉成 ActivityModel', () async {
      when(() => mockHttp.send(any())).thenAnswer((invocation) async {
        final req = invocation.positionalArguments.first as http.BaseRequest;
        expect(req.method, 'GET');
        expect(req.url.queryParameters['id'], 'eq.act-x');
        return _streamedJson(req, jsonEncode(_activityRow(id: 'act-x')), 200);
      });

      final one = await repo.getActivityById('act-x');

      expect(one.id, 'act-x');
      expect(one.title, '活動');
      verify(() => mockHttp.send(any())).called(1);
    });

    test('getUnreadCount：GET + count=exact 由 content-range 取得人數', () async {
      when(() => mockHttp.send(any())).thenAnswer((invocation) async {
        final req = invocation.positionalArguments.first as http.BaseRequest;
        expect(req.method, 'GET');
        expect(req.url.path, '/rest/v1/activities');
        expect(req.url.queryParameters['status'], 'eq.active');
        expect(req.url.queryParameters['notification_status'], 'eq.unread');
        expect(req.url.queryParameters['select'], 'id');
        final r = req as http.Request;
        expect(r.headers['Prefer'], contains('count=exact'));
        return http.StreamedResponse(
          Stream.value(utf8.encode('[]')),
          200,
          request: req,
          headers: {
            'content-type': 'application/json; charset=utf-8',
            'content-range': '0-0/3',
          },
        );
      });

      final n = await repo.getUnreadCount();

      expect(n, 3);
      verify(() => mockHttp.send(any())).called(1);
    });

    test('createActivity：無既有 order 時 insert 並回傳 id', () async {
      var call = 0;
      when(() => mockHttp.send(any())).thenAnswer((invocation) async {
        call++;
        final req = invocation.positionalArguments.first as http.BaseRequest;
        if (call == 1) {
          expect(req.method, 'GET');
          expect(req.url.queryParameters['type'], 'eq.carousel');
          expect(req.url.queryParameters['status'], 'eq.active');
          return _streamedJson(req, '[]', 200);
        }
        if (call == 2) {
          expect(req.method, 'POST');
          expect(req.url.path, '/rest/v1/activities');
          return _streamedJson(req, jsonEncode({'id': 'new-id'}), 201);
        }
        fail('未預期的第 $call 次 HTTP');
      });

      final id = await repo.createActivity(
        title: '新活動',
        description: '描述',
        startTime: DateTime.utc(2026, 8, 1, 10),
        endTime: DateTime.utc(2026, 8, 1, 18),
        type: 'carousel',
        status: 'active',
      );

      expect(id, 'new-id');
      expect(call, 2);
    });

    test('markActivityAsRead：PATCH notification_status', () async {
      when(() => mockHttp.send(any())).thenAnswer((invocation) async {
        final req = invocation.positionalArguments.first as http.BaseRequest;
        expect(req.method, 'PATCH');
        expect(req.url.path, '/rest/v1/activities');
        expect(req.url.queryParameters['id'], 'eq.act-99');
        return _streamedEmpty(req, 204);
      });

      await repo.markActivityAsRead('act-99');

      verify(() => mockHttp.send(any())).called(1);
    });

    test('updateActivity：PATCH 帶入 activity.toJson()', () async {
      when(() => mockHttp.send(any())).thenAnswer((invocation) async {
        final req = invocation.positionalArguments.first as http.BaseRequest;
        expect(req.method, 'PATCH');
        expect(req.url.queryParameters['id'], 'eq.act-up');
        final r = req as http.Request;
        final body = jsonDecode(r.body) as Map<String, dynamic>;
        expect(body['title'], '改標題');
        expect(body['type'], 'recent');
        expect(body['order'], 1);
        expect(body['status'], 'active');
        expect(body['notification_status'], 'unread');
        return _streamedEmpty(req, 204);
      });

      final m = ActivityModel.fromJson(_activityRow(id: 'act-up')).copyWith(
        title: '改標題',
        order: 1,
      );
      await repo.updateActivity(m);

      verify(() => mockHttp.send(any())).called(1);
    });

    test('deleteActivity：DELETE 依 id', () async {
      when(() => mockHttp.send(any())).thenAnswer((invocation) async {
        final req = invocation.positionalArguments.first as http.BaseRequest;
        expect(req.method, 'DELETE');
        expect(req.url.path, '/rest/v1/activities');
        expect(req.url.queryParameters['id'], 'eq.act-del');
        return _streamedEmpty(req, 204);
      });

      await repo.deleteActivity('act-del');

      verify(() => mockHttp.send(any())).called(1);
    });

    test('getActivityNotifications：僅 active，依 start_time 新到舊', () async {
      when(() => mockHttp.send(any())).thenAnswer((invocation) async {
        final req = invocation.positionalArguments.first as http.BaseRequest;
        expect(req.method, 'GET');
        expect(req.url.queryParameters['status'], 'eq.active');
        expect(
          req.url.queryParameters['order'],
          startsWith('start_time.desc'),
        );
        return _streamedJson(
          req,
          jsonEncode([_activityRow(id: 'n1')]),
          200,
        );
      });

      final list = await repo.getActivityNotifications();

      expect(list, hasLength(1));
      expect(list.first.id, 'n1');
      verify(() => mockHttp.send(any())).called(1);
    });

    test('updateActivityType：查最大 order 後 PATCH type 與 order（無既有列時 order=0）',
        () async {
      var call = 0;
      when(() => mockHttp.send(any())).thenAnswer((invocation) async {
        call++;
        final req = invocation.positionalArguments.first as http.BaseRequest;
        if (call == 1) {
          expect(req.method, 'GET');
          expect(req.url.queryParameters['type'], 'eq.carousel');
          expect(req.url.queryParameters['status'], 'eq.active');
          return _streamedJson(req, '[]', 200);
        }
        if (call == 2) {
          expect(req.method, 'PATCH');
          expect(req.url.queryParameters['id'], 'eq.act-t');
          final r = req as http.Request;
          final body = jsonDecode(r.body) as Map<String, dynamic>;
          expect(body['type'], 'carousel');
          expect(body['order'], 0);
          return _streamedEmpty(req, 204);
        }
        fail('未預期的第 $call 次 HTTP');
      });

      await repo.updateActivityType('act-t', 'carousel');

      expect(call, 2);
    });

    test('updateActivityType：已有最大 order 時新 order 為 max+1', () async {
      var call = 0;
      when(() => mockHttp.send(any())).thenAnswer((invocation) async {
        call++;
        final req = invocation.positionalArguments.first as http.BaseRequest;
        if (call == 1) {
          return _streamedJson(
            req,
            jsonEncode([
              {'order': 7},
            ]),
            200,
          );
        }
        if (call == 2) {
          final r = req as http.Request;
          final body = jsonDecode(r.body) as Map<String, dynamic>;
          expect(body['type'], 'recent');
          expect(body['order'], 8);
          return _streamedEmpty(req, 204);
        }
        fail('未預期的第 $call 次 HTTP');
      });

      await repo.updateActivityType('act-next', 'recent');

      expect(call, 2);
    });
  });
}
