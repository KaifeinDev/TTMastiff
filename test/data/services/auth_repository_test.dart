import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ttmastiff/data/services/auth_repository.dart';

// Mocks
class MockSupabaseClient extends Mock implements SupabaseClient {}
class MockGoTrueClient extends Mock implements GoTrueClient {}

// 測試用：可覆寫 insert 行為與捕捉 payload
class TestableAuthRepository extends AuthRepository {
  TestableAuthRepository(SupabaseClient client, {this.onInsertProfile, this.onInsertStudent})
      : super(client);
  final Future<void> Function(Map<String, dynamic> row)? onInsertProfile;
  final Future<void> Function(Map<String, dynamic> row)? onInsertStudent;
  @override
  Future<void> insertProfile(Map<String, dynamic> row) async {
    if (onInsertProfile != null) return onInsertProfile!(row);
    return super.insertProfile(row);
  }
  @override
  Future<void> insertStudent(Map<String, dynamic> row) async {
    if (onInsertStudent != null) return onInsertStudent!(row);
    return super.insertStudent(row);
  }
}

void main() {
  group('AuthRepository', () {
    late MockSupabaseClient client;
    late MockGoTrueClient auth;
    late AuthRepository repo;

    setUp(() {
      client = MockSupabaseClient();
      auth = MockGoTrueClient();
      repo = AuthRepository(client);
    });

    test('signIn 失敗時會包成 Exception 並帶前綴訊息', () async {
      when(() => client.auth).thenReturn(auth);
      when(() => auth.signInWithPassword(email: any(named: 'email'), password: any(named: 'password')))
          .thenThrow(Exception('invalid'));
      expect(
        () => repo.signIn(email: 'a', password: 'b'),
        throwsA(isA<Exception>().having((e) => e.toString(), 'message', contains('登入失敗'))),
      );
    });

    test('signOut 會呼叫 Supabase auth.signOut', () async {
      when(() => client.auth).thenReturn(auth);
      when(() => auth.signOut()).thenAnswer((_) async {});
      await repo.signOut();
      verify(() => auth.signOut()).called(1);
    });

    test('fetchUserRole 發生錯誤時回傳 user', () async {
      // 直接讓 from(...) 丟錯，驗證 fallback 'user'
      when(() => client.from('profiles')).thenThrow(Exception('db error'));
      expect(await repo.fetchUserRole('uid'), 'user');
    });

    group('signUp', () {
      test('成功流程：建立 auth、寫入 profiles 與 students，欄位正確', () async {
        when(() => client.auth).thenReturn(auth);
        final user = User(
          id: 'uid-123',
          appMetadata: const {},
          userMetadata: const {},
          aud: 'authenticated',
          createdAt: DateTime.now().toIso8601String(),
        );
        when(() => auth.signUp(
          email: any(named: 'email'),
          password: any(named: 'password'),
          data: any(named: 'data'),
        )).thenAnswer((_) async => AuthResponse(user: user, session: null));

        Map<String, dynamic>? profilePayload;
        Map<String, dynamic>? studentPayload;
        final repo2 = TestableAuthRepository(
          client,
          onInsertProfile: (row) async {
            profilePayload = Map<String, dynamic>.from(row);
          },
          onInsertStudent: (row) async {
            studentPayload = Map<String, dynamic>.from(row);
          },
        );

        final birth = DateTime(2000, 2, 9, 15, 20);
        await repo2.signUp(
          email: 'mock_e@e.com',
          password: 'mock_pw',
          fullName: '王小明',
          phone: '0912345678',
          birthDate: birth,
          gender: 'male',
          medicalNote: 'note',
        );

        // 驗證 auth.signUp 參數
        verify(() => auth.signUp(
          email: 'mock_e@e.com',
          password: 'mock_pw',
          data: {'full_name': '王小明', 'phone': '0912345678'},
        )).called(1);

        // 驗證 profiles 寫入內容
        expect(profilePayload, isNotNull);
        expect(profilePayload!['id'], 'uid-123');
        expect(profilePayload!['full_name'], '王小明');
        expect(profilePayload!['phone'], '0912345678');
        expect(profilePayload!['referral_source'], 'app_signup');
        expect(profilePayload!['credits'], 0);
        expect(profilePayload!['role'], 'user');
        expect(profilePayload!['membership'], 'beginner');

        // 驗證 students 寫入內容
        expect(studentPayload, isNotNull);
        expect(studentPayload!['parent_id'], 'uid-123');
        expect(studentPayload!['name'], '王小明');
        expect(studentPayload!['birth_date'], '2000-02-09');
        expect(studentPayload!['gender'], 'male');
        expect(studentPayload!['medical_note'], 'note');
        expect(studentPayload!['is_primary'], true);
        final avatar = studentPayload!['avatar_url'] as String;
        expect(avatar.contains('ui-avatars.com'), true);
        expect(avatar.contains(Uri.encodeComponent('小明')), true);
      });

      test('signUp 回傳 user 為 null 時丟出註冊失敗錯誤', () async {
        when(() => client.auth).thenReturn(auth);
        when(() => auth.signUp(
              email: any(named: 'email'),
              password: any(named: 'password'),
              data: any(named: 'data'),
            )).thenAnswer((_) async => AuthResponse(user: null, session: null));

        expect(
          () => repo.signUp(
            email: 'mock_a@a.com',
            password: 'mock_pw',
            fullName: '測試',
            phone: '09',
            birthDate: DateTime(2000, 1, 1),
          ),
          throwsA(isA<Exception>().having((e) => e.toString(), 'message', contains('註冊失敗'))),
        );
      });

      test('任一 DB insert 失敗會拋出「註冊流程失敗」錯誤', () async {
        when(() => client.auth).thenReturn(auth);
        final user = User(
          id: 'uid-err',
          appMetadata: const {},
          userMetadata: const {},
          aud: 'authenticated',
          createdAt: DateTime.now().toIso8601String(),
        );
        when(() => auth.signUp(
          email: any(named: 'email'),
          password: any(named: 'password'),
          data: any(named: 'data'),
        )).thenAnswer((_) async => AuthResponse(user: user, session: null));

        final repo2 = TestableAuthRepository(
          client,
          onInsertProfile: (row) async {
            throw Exception('insert error');
          },
        );

        expect(
          () => repo2.signUp(
            email: 'mock_a@a.com',
            password: 'mock_pw',
            fullName: '測試',
            phone: '09',
            birthDate: DateTime(2000, 1, 1),
          ),
          throwsA(isA<Exception>().having((e) => e.toString(), 'message', contains('註冊流程失敗'))),
        );
      });
    });
  });
}

