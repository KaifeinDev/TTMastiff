import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ttmastiff/data/models/student_model.dart';
import 'package:ttmastiff/data/services/student_repository.dart';

class _MockHttpClient extends Mock implements http.Client {}

class _MockGoTrueClient extends Mock implements GoTrueClient {}

class _MockSupabaseClient extends Mock implements SupabaseClient {}

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

User buildUser(String id) => User(
      id: id,
      appMetadata: const {},
      userMetadata: const {},
      aud: 'authenticated',
      createdAt: DateTime.now().toIso8601String(),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockHttpClient mockHttp;
  late SupabaseClient realSupabase;
  late _MockSupabaseClient mockClient;
  late _MockGoTrueClient mockAuth;
  late StudentRepository repo;

  setUpAll(() {
    registerFallbackValue(Uri());
    registerFallbackValue('');
    registerFallbackValue(http.Request('GET', Uri.parse('http://localhost/')));
  });

  setUp(() {
    mockHttp = _MockHttpClient();
    realSupabase = SupabaseClient(
      'http://localhost:54321',
      'test_anon_key',
      httpClient: mockHttp,
    );
    mockClient = _MockSupabaseClient();
    mockAuth = _MockGoTrueClient();
    when(() => mockClient.from(any())).thenAnswer(
      (inv) => realSupabase.from(inv.positionalArguments[0] as String),
    );
    when(() => mockClient.auth).thenReturn(mockAuth);
    when(() => mockAuth.currentUser).thenReturn(null);
    repo = StudentRepository(mockClient);
  });

  group('StudentRepository（HTTP 由 mocktail 隔離）', () {
    test('getMyStudents：未登入會拋出', () async {
      await expectLater(repo.getMyStudents(), throwsA(isA<Exception>()));
      verifyNever(() => mockHttp.send(any()));
    });

    test('getMyStudents：GET students 並轉成 StudentModel 列表', () async {
      when(() => mockAuth.currentUser).thenReturn(buildUser('u1'));
      when(() => mockHttp.send(any())).thenAnswer((invocation) async {
        final req = invocation.positionalArguments.first as http.BaseRequest;
        expect(req.method, 'GET');
        expect(req.url.path, '/rest/v1/students');
        expect(req.url.queryParameters['parent_id'], 'eq.u1');
        return _streamedJson(
          req,
          jsonEncode([
            {
              'id': 's2',
              'parent_id': 'u1',
              'name': '小華',
              'is_primary': false,
              'birth_date': '2012-03-01',
              'points': 5,
            },
            {
              'id': 's1',
              'parent_id': 'u1',
              'name': '王小明',
              'is_primary': true,
              'birth_date': '2010-01-05',
              'points': 10,
            },
          ]),
          200,
        );
      });

      final list = await repo.getMyStudents();
      expect(list, hasLength(2));
      expect(list.first.name, '小華');
      expect(list[1].isPrimary, true);
      verify(() => mockHttp.send(any())).called(1);
    });

    test('addStudent：POST 帶入 parent_id、is_primary=false 與 avatar_url', () async {
      when(() => mockAuth.currentUser).thenReturn(buildUser('parent-1'));
      when(() => mockHttp.send(any())).thenAnswer((invocation) async {
        final req = invocation.positionalArguments.first as http.BaseRequest;
        expect(req.method, 'POST');
        expect(req.url.path, '/rest/v1/students');
        final r = req as http.Request;
        final row = jsonDecode(r.body) as Map<String, dynamic>;
        expect(row['parent_id'], 'parent-1');
        expect(row['name'], '王小明');
        expect(row['medical_note'], 'note');
        expect(row['is_primary'], false);
        expect((row['avatar_url'] as String).contains(Uri.encodeComponent('小明')), true);
        return _streamedEmpty(req, 201);
      });

      await repo.addStudent(
        name: '王小明',
        birthDate: DateTime(2010, 1, 5),
        medicalNote: 'note',
      );

      verify(() => mockHttp.send(any())).called(1);
    });

    test('updateStudent：PATCH name / avatar_url / medical_note', () async {
      when(() => mockHttp.send(any())).thenAnswer((invocation) async {
        final req = invocation.positionalArguments.first as http.BaseRequest;
        expect(req.method, 'PATCH');
        expect(req.url.queryParameters['id'], 'eq.sid-1');
        final r = req as http.Request;
        final row = jsonDecode(r.body) as Map<String, dynamic>;
        expect(row['name'], '王小明');
        expect((row['avatar_url'] as String).contains(Uri.encodeComponent('小明')), true);
        expect(row['medical_note'], 'new-note');
        return _streamedEmpty(req, 204);
      });

      await repo.updateStudent('sid-1', '王小明', 'new-note');
      verify(() => mockHttp.send(any())).called(1);
    });

    test('updateStudentPoints：PATCH points', () async {
      when(() => mockHttp.send(any())).thenAnswer((invocation) async {
        final req = invocation.positionalArguments.first as http.BaseRequest;
        expect(req.method, 'PATCH');
        expect(req.url.queryParameters['id'], 'eq.sid-2');
        final r = req as http.Request;
        expect(jsonDecode(r.body), {'points': 99});
        return _streamedEmpty(req, 204);
      });

      await repo.updateStudentPoints('sid-2', 99);
      verify(() => mockHttp.send(any())).called(1);
    });

    test('fetchStudentsByFilter：sessionId 分支', () async {
      var call = 0;
      when(() => mockHttp.send(any())).thenAnswer((invocation) async {
        call++;
        final req = invocation.positionalArguments.first as http.BaseRequest;
        if (call == 1) {
          expect(req.method, 'GET');
          expect(req.url.path, '/rest/v1/bookings');
          expect(req.url.queryParameters['session_id'], 'eq.sess-1');
          return _streamedJson(
            req,
            jsonEncode([
              {
                'students': {
                  'id': 's1',
                  'parent_id': 'p1',
                  'name': '小明',
                  'birth_date': '2010-01-05',
                  'is_primary': true,
                }
              },
              {
                'students': {
                  'id': 's2',
                  'parent_id': 'p2',
                  'name': '小華',
                  'birth_date': '2012-03-01',
                  'is_primary': false,
                }
              },
            ]),
            200,
          );
        }
        if (call == 2) {
          expect(req.method, 'GET');
          expect(req.url.path, '/rest/v1/profiles');
          return _streamedJson(
            req,
            jsonEncode([
              {'id': 'p1', 'phone': '0912', 'full_name': '爸爸甲'},
              {'id': 'p2', 'phone': '0922', 'full_name': '媽媽乙'},
            ]),
            200,
          );
        }
        fail('未預期的第 $call 次 HTTP');
      });

      final result = await repo.fetchStudentsByFilter(sessionId: 'sess-1');
      expect(result.length, 2);
      final r1 = result.first;
      expect((r1['student'] as StudentModel).id, 's1');
      expect(r1['parentPhone'], '0912');
      expect(r1['parentName'], '爸爸甲');
      expect(r1['bookings'], isNull);
      expect(call, 2);
    });

    test('fetchStudentsByFilter：無 course/session，套用 name 與 phone 篩選', () async {
      var call = 0;
      when(() => mockHttp.send(any())).thenAnswer((invocation) async {
        call++;
        final req = invocation.positionalArguments.first as http.BaseRequest;
        if (call == 1) {
          expect(req.url.path, '/rest/v1/profiles');
          expect(req.url.queryParameters['select'], 'id');
          return _streamedJson(req, jsonEncode([{'id': 'p1'}]), 200);
        }
        if (call == 2) {
          expect(req.url.path, '/rest/v1/students');
          return _streamedJson(
            req,
            jsonEncode([
              {
                'id': 's1',
                'parent_id': 'p1',
                'name': '王小明',
                'birth_date': '2010-01-05',
                'is_primary': true,
              },
              {
                'id': 's2',
                'parent_id': 'p2',
                'name': '小華',
                'birth_date': '2012-03-01',
                'is_primary': false,
              },
            ]),
            200,
          );
        }
        if (call == 3) {
          expect(req.url.path, '/rest/v1/profiles');
          return _streamedJson(
            req,
            jsonEncode([
              {'id': 'p1', 'phone': '0912', 'full_name': '爸爸甲'},
            ]),
            200,
          );
        }
        fail('未預期的第 $call 次 HTTP');
      });

      final result =
          await repo.fetchStudentsByFilter(name: '明', phone: '0912');
      expect(result.length, 1);
      final stu = result.first['student'] as StudentModel;
      expect(stu.name, '王小明');
      expect(result.first['parentPhone'], '0912');
      expect(result.first['parentName'], '爸爸甲');
      expect(call, 3);
    });

    test('fetchStudentAndParentProfile：單筆含 profiles 巢狀', () async {
      when(() => mockHttp.send(any())).thenAnswer((invocation) async {
        final req = invocation.positionalArguments.first as http.BaseRequest;
        expect(req.method, 'GET');
        expect(req.url.path, '/rest/v1/students');
        expect(req.url.queryParameters['id'], 'eq.s1');
        return _streamedJson(
          req,
          jsonEncode({
            'id': 's1',
            'parent_id': 'p1',
            'name': '王小明',
            'birth_date': '2010-01-05',
            'is_primary': true,
            'profiles': {'full_name': '爸爸甲', 'phone': '0912'},
          }),
          200,
        );
      });

      final res = await repo.fetchStudentAndParentProfile('s1');
      final stu = res['student'] as StudentModel;
      expect(stu.id, 's1');
      expect(res['parentName'], '爸爸甲');
      expect(res['parentPhone'], '0912');
      verify(() => mockHttp.send(any())).called(1);
    });
  });
}
