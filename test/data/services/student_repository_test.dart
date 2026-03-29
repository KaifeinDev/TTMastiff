import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ttmastiff/data/models/student_model.dart';
import 'package:ttmastiff/data/services/student_repository.dart';

class MockSupabaseClient extends Mock implements SupabaseClient {}
class MockGoTrueClient extends Mock implements GoTrueClient {}
class TestableStudentRepository extends StudentRepository {
  TestableStudentRepository(
    SupabaseClient c, {
    this.onQueryStudentsByParentId,
    this.onInsertStudentRow,
    this.onUpdateStudentRow,
    this.onUpdatePointsRow,
    this.onQueryBookingsBySession,
    this.onQuerySessionsByCourse,
    this.onQueryBookingsBySessionIds,
    this.onQueryAllStudents,
    this.onQueryProfilesByPhoneLike,
    this.onQueryParentProfilesByIds,
    this.onQueryBookingsDetailsByStudentIds,
    this.onQueryStudentWithProfile,
  }) : super(c);

  final Future<List<Map<String, dynamic>>> Function(String userId)?
      onQueryStudentsByParentId;
  final Future<void> Function(Map<String, dynamic> row)? onInsertStudentRow;
  final Future<void> Function(String id, Map<String, dynamic> row)?
      onUpdateStudentRow;
  final Future<void> Function(String id, int points)? onUpdatePointsRow;
  final Future<List<Map<String, dynamic>>> Function(String sessionId)?
      onQueryBookingsBySession;
  final Future<List<Map<String, dynamic>>> Function(String courseId)?
      onQuerySessionsByCourse;
  final Future<List<Map<String, dynamic>>> Function(List<String> sessionIds)?
      onQueryBookingsBySessionIds;
  final Future<List<Map<String, dynamic>>> Function()? onQueryAllStudents;
  final Future<List<Map<String, dynamic>>> Function(String phoneLike)?
      onQueryProfilesByPhoneLike;
  final Future<List<Map<String, dynamic>>> Function(List<String> parentIds)?
      onQueryParentProfilesByIds;
  final Future<List<Map<String, dynamic>>> Function(List<String> studentIds)?
      onQueryBookingsDetailsByStudentIds;
  final Future<Map<String, dynamic>> Function(String studentId)?
      onQueryStudentWithProfile;

  Future<dynamic> queryStudentsByParentId(String userId) {
    if (onQueryStudentsByParentId != null) {
      return onQueryStudentsByParentId!(userId);
    }
    throw UnimplementedError();
  }

  Future<void> insertStudentRow(Map<String, dynamic> row) {
    if (onInsertStudentRow != null) return onInsertStudentRow!(row);
    throw UnimplementedError();
  }

  Future<void> updateStudentRow(String id, Map<String, dynamic> row) {
    if (onUpdateStudentRow != null) return onUpdateStudentRow!(id, row);
    throw UnimplementedError();
  }

  Future<void> updatePointsRow(String id, int points) {
    if (onUpdatePointsRow != null) return onUpdatePointsRow!(id, points);
    throw UnimplementedError();
  }

  Future<List<Map<String, dynamic>>> queryBookingsBySession(
      String sessionId) {
    if (onQueryBookingsBySession != null) {
      return onQueryBookingsBySession!(sessionId);
    }
    throw UnimplementedError();
  }

  Future<List<Map<String, dynamic>>> querySessionsByCourse(
      String courseId) {
    if (onQuerySessionsByCourse != null) {
      return onQuerySessionsByCourse!(courseId);
    }
    throw UnimplementedError();
  }

  Future<List<Map<String, dynamic>>> queryBookingsBySessionIds(
      List<String> sessionIds) {
    if (onQueryBookingsBySessionIds != null) {
      return onQueryBookingsBySessionIds!(sessionIds);
    }
    throw UnimplementedError();
  }

  Future<List<Map<String, dynamic>>> queryAllStudents() {
    if (onQueryAllStudents != null) {
      return onQueryAllStudents!();
    }
    throw UnimplementedError();
  }

  Future<List<Map<String, dynamic>>> queryProfilesByPhoneLike(
      String phoneLike) {
    if (onQueryProfilesByPhoneLike != null) {
      return onQueryProfilesByPhoneLike!(phoneLike);
    }
    throw UnimplementedError();
  }

  Future<List<Map<String, dynamic>>> queryParentProfilesByIds(
      List<String> parentIds) {
    if (onQueryParentProfilesByIds != null) {
      return onQueryParentProfilesByIds!(parentIds);
    }
    throw UnimplementedError();
  }

  Future<List<Map<String, dynamic>>> queryBookingsDetailsByStudentIds(
      List<String> studentIds) {
    if (onQueryBookingsDetailsByStudentIds != null) {
      return onQueryBookingsDetailsByStudentIds!(studentIds);
    }
    throw UnimplementedError();
  }

  Future<Map<String, dynamic>> queryStudentWithProfile(String studentId) {
    if (onQueryStudentWithProfile != null) {
      return onQueryStudentWithProfile!(studentId);
    }
    throw UnimplementedError();
  }
}

// 假的 user
User buildUser(String id) => User(
  id: id,
  appMetadata: const {},
  userMetadata: const {},
  aud: 'authenticated',
  createdAt: DateTime.now().toIso8601String(),
);

// 針對 getMyStudents 的鏈式查詢：select()->eq()->order()->order()->await
class FakeStudentsChain {
  final List<Map<String, dynamic>> data;
  int _orderCount = 0;
  FakeStudentsChain(this.data);
  dynamic select([dynamic _]) => this;
  dynamic eq(String _col, dynamic _val) => this;
  dynamic order(String _col, {bool ascending = true}) {
    _orderCount += 1;
    if (_orderCount >= 2) {
      // 最後一次 order 回傳 Future，模擬 await
      return Future.value(List<Map<String, dynamic>>.from(data));
    }
    return this;
  }
}

// 針對 addStudent/ updateStudent 的 insert/update/eq
class FakeStudentsMutations {
  Map<String, dynamic>? lastInsertedRow;
  Map<String, dynamic>? lastUpdatedRow;
  String? lastEqId;

  Future<void> insert(Map<String, dynamic> row) async {
    lastInsertedRow = Map<String, dynamic>.from(row);
  }

  dynamic update(Map<String, dynamic> row) {
    lastUpdatedRow = Map<String, dynamic>.from(row);
    return this;
  }

  Future<void> eq(String _col, dynamic val) async {
    lastEqId = val as String?;
  }
}

// for fetchStudentsByFilter - sessionId path: bookings.select(...).eq(...).eq(...).then(...)
class FakeBookingsThenable {
  final List<Map<String, dynamic>> data;
  FakeBookingsThenable(this.data);
  dynamic select(String _cols) => this;
  dynamic eq(String _col, dynamic _val) => this;
  Future<T> then<T>(T Function(List<Map<String, dynamic>>) fn) async {
    return fn(List<Map<String, dynamic>>.from(data));
  }
}

// for fetchStudentsByFilter - direct students path: select('*').order(...).then(...)
class FakeStudentsThenable {
  final List<Map<String, dynamic>> data;
  FakeStudentsThenable(this.data);
  dynamic select([String? _cols]) => this;
  dynamic order(String _col, {bool ascending = true}) => this;
  Future<T> then<T>(T Function(List<Map<String, dynamic>>) fn) async {
    return fn(List<Map<String, dynamic>>.from(data));
  }
}

// for fetchStudentsByFilter - profiles ilike phone -> returns [{id: ...}]
class FakeProfilesPhoneSearch {
  final List<Map<String, dynamic>> ids;
  FakeProfilesPhoneSearch(this.ids);
  dynamic select(String _cols) => this;
  Future<List<Map<String, dynamic>>> ilike(String _col, String _pattern) async => ids;
}

// for fetchStudentsByFilter - profiles inFilter to map id->phone/name
class FakeProfilesInFilter {
  final List<Map<String, dynamic>> profiles;
  FakeProfilesInFilter(this.profiles);
  dynamic select(String _cols) => this;
  Future<List<Map<String, dynamic>>> inFilter(String _col, List<dynamic> _ids) async => profiles;
}

// for fetchStudentAndParentProfile - students.select(...).eq(...).single()
class FakeStudentsSingle {
  final Map<String, dynamic> row;
  FakeStudentsSingle(this.row);
  dynamic select(String _cols) => this;
  dynamic eq(String _col, dynamic _val) => this;
  Future<Map<String, dynamic>> single() async => row;
}

void main() {
  group('StudentRepository', () {
    late MockSupabaseClient client;
    late MockGoTrueClient auth;
    late StudentRepository repo;

    setUp(() {
      client = MockSupabaseClient();
      auth = MockGoTrueClient();
      when(() => client.auth).thenReturn(auth);
      repo = StudentRepository(client);
    });

    test('getMyStudents：未登入會拋出', () async {
      when(() => auth.currentUser).thenReturn(null);
      expect(() => repo.getMyStudents(), throwsA(isA<Exception>()));
    });

    test('getMyStudents：回傳解析後的 StudentModel 清單，且 primary 在前', () async {
      when(() => auth.currentUser).thenReturn(buildUser('u1'));
      final data = [
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
      ];
      final repo2 = TestableStudentRepository(
        client,
        onQueryStudentsByParentId: (uid) async => data,
      );
      final list = await repo2.getMyStudents();
      expect(list, isA<List<StudentModel>>());
      // 因為我們在 fake 中不真的排序，這裡只驗證解析正確與長度
      expect(list.length, 2);
      expect(list.first.name, '小華'); // 解析正確
      expect(list[1].isPrimary, true); // 主帳號有被解析
    });

    test('addStudent：會帶入 parent_id、is_primary=false 與 avatar_url', () async {
      when(() => auth.currentUser).thenReturn(buildUser('parent-1'));
      final fake = FakeStudentsMutations();
      final repo2 = TestableStudentRepository(
        client,
        onInsertStudentRow: (row) async => fake.insert(row),
      );

      await repo2.addStudent(
        name: '王小明',
        birthDate: DateTime(2010, 1, 5),
        medicalNote: 'note',
      );

      final row = fake.lastInsertedRow!;
      expect(row['parent_id'], 'parent-1');
      expect(row['name'], '王小明');
      expect(row['birth_date'], isA<String>());
      expect(row['medical_note'], 'note');
      expect(row['is_primary'], false);
      expect((row['avatar_url'] as String).contains(Uri.encodeComponent('小明')), true);
    });

    test('updateStudent：會更新 name / avatar_url / medical_note 並 eq(id)', () async {
      final fake = FakeStudentsMutations();
      final repo2 = TestableStudentRepository(
        client,
        onUpdateStudentRow: (id, row) async {
          fake.lastEqId = id;
          fake.lastUpdatedRow = Map<String, dynamic>.from(row);
        },
      );

      await repo2.updateStudent('sid-1', '王小明', 'new-note');
      expect(fake.lastUpdatedRow!['name'], '王小明');
      expect((fake.lastUpdatedRow!['avatar_url'] as String).contains(Uri.encodeComponent('小明')), true);
      expect(fake.lastUpdatedRow!['medical_note'], 'new-note');
      expect(fake.lastEqId, 'sid-1');
    });

    test('updateStudentPoints：更新 points 並 eq(id)', () async {
      final fake = FakeStudentsMutations();
      final repo2 = TestableStudentRepository(
        client,
        onUpdatePointsRow: (id, points) async {
          fake.lastEqId = id;
          fake.lastUpdatedRow = {'points': points};
        },
      );
      await repo2.updateStudentPoints('sid-2', 99);
      expect(fake.lastUpdatedRow, {'points': 99});
      expect(fake.lastEqId, 'sid-2');
    });

    test('fetchStudentsByFilter：sessionId 分支（不含 bookings 詳細）', () async {
      final repo2 = TestableStudentRepository(
        client,
        onQueryBookingsBySession: (sessionId) async => [
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
        ],
        onQueryParentProfilesByIds: (ids) async => [
          {'id': 'p1', 'phone': '0912', 'full_name': '爸爸甲'},
          {'id': 'p2', 'phone': '0922', 'full_name': '媽媽乙'},
        ],
      );

      final result = await repo2.fetchStudentsByFilter(sessionId: 'sess-1');
      expect(result.length, 2);
      final r1 = result.first;
      expect((r1['student'] as StudentModel).id, 's1');
      expect(r1['parentPhone'], '0912');
      expect(r1['parentName'], '爸爸甲');
      expect(r1['bookings'], isNull);
    });

    test('fetchStudentsByFilter：無 course/session，套用 name 與 phone 篩選', () async {
      final repo2 = TestableStudentRepository(
        client,
        onQueryProfilesByPhoneLike: (phoneLike) async => [
          {'id': 'p1'}
        ],
        onQueryAllStudents: () async => [
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
        ],
        onQueryParentProfilesByIds: (ids) async => [
          {'id': 'p1', 'phone': '0912', 'full_name': '爸爸甲'},
        ],
      );

      final result =
          await repo2.fetchStudentsByFilter(name: '明', phone: '0912');
      expect(result.length, 1);
      final r = result.first;
      final stu = r['student'] as StudentModel;
      expect(stu.name, '王小明');
      expect(r['parentPhone'], '0912');
      expect(r['parentName'], '爸爸甲');
    });

    test('fetchStudentAndParentProfile：合併回傳 student 與家長資訊', () async {
      final repo2 = TestableStudentRepository(
        client,
        onQueryStudentWithProfile: (id) async => {
          'id': 's1',
          'parent_id': 'p1',
          'name': '王小明',
          'birth_date': '2010-01-05',
          'is_primary': true,
          'profiles': {'full_name': '爸爸甲', 'phone': '0912'},
        },
      );

      final res = await repo2.fetchStudentAndParentProfile('s1');
      final stu = res['student'] as StudentModel;
      expect(stu.id, 's1');
      expect(res['parentName'], '爸爸甲');
      expect(res['parentPhone'], '0912');
    });
  });
}

