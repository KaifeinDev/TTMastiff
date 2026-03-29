import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ttmastiff/data/services/course_repository.dart';

class _MockHttpClient extends Mock implements http.Client {}

/// PostgREST 解析回應時需要 [http.Response.request] 非 null（見 `PostgrestBuilder._parseResponse`）。
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

/// 以 mocktail 隔離真實網路：攔截 [http.Client.send]，回傳 PostgREST 相容的 [http.StreamedResponse]。
void main() {
  late _MockHttpClient mockHttp;
  late SupabaseClient supabase;
  late CourseRepository repo;

  final fixedNow = DateTime(2026, 3, 29, 10, 0, 0);

  /// 共用的課程 JSON（巢狀於 session 的 courses）
  Map<String, dynamic> courseJson({
    String id = 'course-1',
    String title = '團體課 A',
  }) {
    return {
      'id': id,
      'title': title,
      'description': null,
      'price': 100,
      'default_start_time': '10:00:00',
      'default_end_time': '11:00:00',
      'image_url': null,
      'category': 'group',
      'is_published': true,
    };
  }

  Map<String, dynamic> sessionRow({
    required String id,
    required String startIso,
    required String endIso,
    Map<String, dynamic>? course,
  }) {
    return {
      'id': id,
      'course_id': (course ?? courseJson())['id'],
      'start_time': startIso,
      'end_time': endIso,
      'max_capacity': 8,
      'coach_ids': <String>[],
      'table_ids': <String>[],
      'bookings': [
        {'count': 0},
      ],
      'courses': course ?? courseJson(),
    };
  }

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
    repo = CourseRepository(
      supabase,
      clock: () => fixedNow,
    );
  });

  group('CourseRepository（HTTP 由 mocktail Mock 隔離）', () {
    test('getCourses 回傳依 created_at 排序轉成的 CourseModel 列表', () async {
      when(() => mockHttp.send(any())).thenAnswer((invocation) async {
        final req = invocation.positionalArguments.first as http.BaseRequest;
        expect(req.method, 'GET');
        expect(req.url.path, '/rest/v1/courses');
        final body = jsonEncode([
          courseJson(id: 'a', title: '先'),
          courseJson(id: 'b', title: '後'),
        ]);
        return _streamedJson(req, body, 200);
      });

      final list = await repo.getCourses();

      expect(list, hasLength(2));
      expect(list.map((e) => e.id).toList(), ['a', 'b']);
      verify(() => mockHttp.send(any())).called(1);
    });

    test('getPublishedCourses 只會收到 is_published 為 true 的查詢結果', () async {
      when(() => mockHttp.send(any())).thenAnswer((invocation) async {
        final req = invocation.positionalArguments.first as http.BaseRequest;
        expect(req.url.queryParameters['is_published'], 'eq.true');
        final body = jsonEncode([courseJson()]);
        return _streamedJson(req, body, 200);
      });

      final list = await repo.getPublishedCourses();
      expect(list, hasLength(1));
      expect(list.first.isPublished, true);
    });

    test('getCourseById 取得單筆課程', () async {
      when(() => mockHttp.send(any())).thenAnswer((invocation) async {
        final req = invocation.positionalArguments.first as http.BaseRequest;
        expect(req.url.path, '/rest/v1/courses');
        final body = jsonEncode(courseJson(id: 'x', title: '單筆'));
        return _streamedJson(req, body, 200);
      });

      final c = await repo.getCourseById('x');
      expect(c.id, 'x');
      expect(c.title, '單筆');
    });

    test('fetchCourseById 失敗時包裝為「找不到課程資訊」', () async {
      when(() => mockHttp.send(any())).thenAnswer((invocation) async {
        final req = invocation.positionalArguments.first as http.BaseRequest;
        return _streamedJson(
          req,
          jsonEncode({'message': 'not found'}),
          404,
          headers: {'content-type': 'application/json'},
        );
      });

      await expectLater(
        repo.fetchCourseById('missing'),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('找不到課程資訊'),
          ),
        ),
      );
    });

    test('fetchCoursesByWeekday 依星期過濾並依課程 id 去重', () async {
      // fixedNow = 2026-03-29；區間內放兩筆：同課程、同一天（週四 weekday=4）
      final s1 = sessionRow(
        id: 's1',
        startIso: '2026-04-02T10:00:00.000',
        endIso: '2026-04-02T11:00:00.000',
      );
      final s2 = sessionRow(
        id: 's2',
        startIso: '2026-04-02T14:00:00.000',
        endIso: '2026-04-02T15:00:00.000',
      );

      when(() => mockHttp.send(any())).thenAnswer((invocation) async {
        final req = invocation.positionalArguments.first as http.BaseRequest;
        final body = jsonEncode([s1, s2]);
        return _streamedJson(req, body, 200);
      });

      final courses = await repo.fetchCoursesByWeekday(4);
      expect(courses, hasLength(1));
      expect(courses.first.id, 'course-1');
    });

    test('deleteCourse：場次數 > 0 時拋出業務例外（禁止刪除）', () async {
      var call = 0;
      when(() => mockHttp.send(any())).thenAnswer((invocation) async {
        call++;
        final req = invocation.positionalArguments.first as http.BaseRequest;
        if (call == 1) {
          expect(req.method, 'HEAD');
          expect(req.url.path, '/rest/v1/sessions');
          return _streamedEmpty(
            req,
            200,
            headers: {
              'content-range': '0-0/3',
              'content-type': 'application/json',
            },
          );
        }
        fail('不應呼叫 delete');
      });

      await expectLater(
        repo.deleteCourse('c1'),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            allOf(
              contains('無法刪除'),
              contains('3'),
              contains('場次'),
            ),
          ),
        ),
      );
    });

    test('deleteCourse：場次數為 0 時執行 DELETE 並成功', () async {
      var call = 0;
      when(() => mockHttp.send(any())).thenAnswer((invocation) async {
        call++;
        final req = invocation.positionalArguments.first as http.BaseRequest;
        if (call == 1) {
          expect(req.method, 'HEAD');
          return _streamedEmpty(
            req,
            200,
            headers: {
              'content-range': '0-0/0',
              'content-type': 'application/json',
            },
          );
        }
        if (call == 2) {
          expect(req.method, 'DELETE');
          expect(req.url.path, '/rest/v1/courses');
          return _streamedEmpty(req, 204);
        }
        fail('未預期的第 $call 次請求');
      });

      await repo.deleteCourse('clean-id');
      expect(call, 2);
    });

    test('toggleCoursePublishStatus：PATCH 成功不拋錯', () async {
      when(() => mockHttp.send(any())).thenAnswer((invocation) async {
        final req = invocation.positionalArguments.first as http.BaseRequest;
        expect(req.method, 'PATCH');
        expect(req.url.path, '/rest/v1/courses');
        return _streamedEmpty(req, 204);
      });

      await expectLater(
        repo.toggleCoursePublishStatus('cid', true),
        completes,
      );
    });

    test('createCourse：insert 後 select 回傳 id', () async {
      when(() => mockHttp.send(any())).thenAnswer((invocation) async {
        final req = invocation.positionalArguments.first as http.BaseRequest;
        expect(req.method, 'POST');
        final body = jsonEncode({'id': 'new-id'});
        return _streamedJson(req, body, 201);
      });

      final id = await repo.createCourse(
        title: '新課',
        category: 'group',
        price: 200,
        description: null,
        defaultStartTime: DateTime(2026, 1, 1, 9, 0),
        defaultEndTime: DateTime(2026, 1, 1, 10, 0),
      );
      expect(id, 'new-id');
    });

    test('updateCourse：PATCH 成功不拋錯', () async {
      when(() => mockHttp.send(any())).thenAnswer((invocation) async {
        final req = invocation.positionalArguments.first as http.BaseRequest;
        expect(req.method, 'PATCH');
        expect(req.url.path, '/rest/v1/courses');
        return _streamedEmpty(req, 204);
      });

      await expectLater(
        repo.updateCourse(
          courseId: 'cid',
          title: '改標題',
          category: 'group',
          price: 300,
          description: null,
          defaultStartTime: DateTime(2026, 1, 1, 9, 0),
          defaultEndTime: DateTime(2026, 1, 1, 10, 0),
        ),
        completes,
      );
    });
  });
}
